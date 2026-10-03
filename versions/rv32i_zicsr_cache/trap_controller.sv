/**
 * @file trap_controller.sv
 * @brief RISC-V Trap and Exception Controller
 * @details This module manages traps (exceptions and interrupts) and MRET instructions for a RISC-V core. 
 *          It monitors exception signals from the execution stage (like ecall, ebreak, and illegal instructions) 
 *          as well as hardware timer interrupts. It prioritizes exceptions, handles context saving by updating 
 *          CSRs (mepc, mcause, mstatus), calculates target trap vectors, and controls pipeline flushing.
 */

 import rv32_types_pkg::*;

module trap_controller (
    input  logic                clk,
    input  logic                rst_n,
    
    // Exception signals from execution stage
    input  logic                ex_ecall,
    input  logic                ex_ebreak,
    input  logic                ex_illegal,
    input  logic                ex_mret,
    
    // Interrupt signals
    input  logic                timer_interrupt,      // Timer interrupt request
    
    // CSR values
    input  logic [31:0]         mstatus_value,        // Current mstatus
    input  logic [31:0]         mie_value,            // Machine Interrupt Enable
    input  logic [31:0]         mip_value,            // Machine Interrupt Pending
    input  logic [31:0]         trap_vector,          // mtvec value
    input  logic [31:0]         mepc_value,           // mepc value
    
    // Pipeline control
    input  logic [31:0]         inst_pc,              // Current instruction PC
    
    // CSR write back signals
    output logic                csr_mepc_write,       // Write new mepc
    output logic [31:0]         csr_mepc_next,        // New mepc value
    output logic                csr_mcause_write,     // Write new mcause
    output logic [31:0]         csr_mcause_next,      // New mcause value
    output logic                csr_mstatus_write,    // Write new mstatus
    output logic [31:0]         csr_mstatus_next,     // New mstatus value
    
    // Trap control signals
    output logic                trap_taken,
    output logic                mret_taken,
    output logic                trap_jump,
    output logic                mret_jump,
    output logic [31:0]         trap_pc,
    output logic [31:0]         trap_cause,
    output logic [31:0]         trap_next_pc,
    
    // Pipeline flush signals
    output logic                if_id_flush,
    output logic                id_ex_flush,
    output logic                ex_mem_flush
);

    // ============================================
    // Trap cause values (RISC-V standard)
    // ============================================
    localparam logic [31:0] CAUSE_ILLEGAL_INSTRUCTION = 32'd2;
    localparam logic [31:0] CAUSE_BREAKPOINT          = 32'd3;
    localparam logic [31:0] CAUSE_ECALL_MMODE         = 32'd11;
    
    // Interrupt causes (with interrupt bit set)
    localparam logic [31:0] CAUSE_TIMER_INTERRUPT     = {1'b1, 31'd7};   // MTI
    
    // mstatus bit positions
    localparam int MSTATUS_MIE_BIT  = 3;   // Machine Interrupt Enable
    localparam int MSTATUS_MPIE_BIT = 7;   // Machine Previous Interrupt Enable
    
    // mie/mip bit positions
    localparam int MTI_BIT = 7;   // Machine Timer Interrupt
    
    // ============================================
    // Internal signals
    // ============================================
    logic exception_taken;
    logic interrupt_taken;
    logic interrupt_enabled;
    logic interrupt_pending;
    
    logic [31:0] exception_cause;
    logic [31:0] interrupt_cause;
    
    // ============================================
    // Interrupt detection logic
    // ============================================
    
    // Check if interrupts are globally enabled
    assign interrupt_enabled = mstatus_value[MSTATUS_MIE_BIT];
    
    // Check for pending interrupts (with individual enables)
    always_comb begin
        interrupt_pending = 1'b0;
        interrupt_cause  = 32'b0;
        
        if (timer_interrupt && mie_value[MTI_BIT]) begin
            interrupt_pending = 1'b1;
            interrupt_cause  = CAUSE_TIMER_INTERRUPT;
        end
    end
    
    // ============================================
    // Main trap control logic
    // ============================================
    always_comb begin
        // Default values
        exception_taken   = 1'b0;
        interrupt_taken   = 1'b0;
        trap_taken        = 1'b0;
        mret_taken        = 1'b0;
        trap_jump         = 1'b0;
        mret_jump         = 1'b0;
        
        trap_pc           = inst_pc;
        trap_cause        = 32'b0;
        trap_next_pc      = inst_pc + 32'd4;
        
        csr_mepc_write    = 1'b0;
        csr_mepc_next     = 32'b0;
        csr_mcause_write  = 1'b0;
        csr_mcause_next   = 32'b0;
        csr_mstatus_write = 1'b0;
        csr_mstatus_next  = mstatus_value;
        
        if_id_flush       = 1'b0;
        id_ex_flush       = 1'b0;
        ex_mem_flush      = 1'b0;
        
        // ============================================
        // Exception detection
        // ============================================
        if (ex_ecall) begin
            exception_taken = 1'b1;
            exception_cause = CAUSE_ECALL_MMODE;
        end
        else if (ex_ebreak) begin
            exception_taken = 1'b1;
            exception_cause = CAUSE_BREAKPOINT;
        end
        else if (ex_illegal) begin
            exception_taken = 1'b1;
            exception_cause = CAUSE_ILLEGAL_INSTRUCTION;
        end
        
        // ============================================
        // Priority: Exception > MRET > Interrupt
        // ============================================
        if (exception_taken) begin
            // Handle exception
            trap_taken = 1'b1;
            trap_pc    = inst_pc;
            trap_cause = exception_cause;
            trap_next_pc = trap_vector;
            trap_jump  = 1'b1;
            
            // Save current PC to mepc
            csr_mepc_write = 1'b1;
            csr_mepc_next  = inst_pc;
            
            // Save cause to mcause
            csr_mcause_write = 1'b1;
            csr_mcause_next  = exception_cause;
            
            // Update mstatus: MPIE = MIE, MIE = 0
            csr_mstatus_write = 1'b1;
            csr_mstatus_next = mstatus_value;
            csr_mstatus_next[MSTATUS_MPIE_BIT] = mstatus_value[MSTATUS_MIE_BIT];
            csr_mstatus_next[MSTATUS_MIE_BIT]  = 1'b0;
            
            // Flush pipeline
            if_id_flush  = 1'b1;
            id_ex_flush  = 1'b1;
            ex_mem_flush = 1'b1;
        end
        else if (ex_mret) begin
            // Handle MRET
            mret_taken    = 1'b1;
            trap_next_pc  = mepc_value;
            mret_jump     = 1'b1;
            
            // Update mstatus: MIE = MPIE, MPIE = 1
            csr_mstatus_write = 1'b1;
            csr_mstatus_next = mstatus_value;
            csr_mstatus_next[MSTATUS_MIE_BIT]  = mstatus_value[MSTATUS_MPIE_BIT];
            csr_mstatus_next[MSTATUS_MPIE_BIT] = 1'b1;
            
            // Flush pipeline
            if_id_flush  = 1'b1;
            id_ex_flush  = 1'b1;
            ex_mem_flush = 1'b1;
        end
        else if (interrupt_pending && interrupt_enabled) begin
            // Handle interrupt
            interrupt_taken = 1'b1;
            trap_taken      = 1'b1;
            trap_pc         = inst_pc;
            trap_cause      = interrupt_cause;
            trap_next_pc    = trap_vector;
            trap_jump       = 1'b1;
            
            // Save current PC to mepc
            csr_mepc_write = 1'b1;
            csr_mepc_next  = inst_pc;
            
            // Save cause to mcause
            csr_mcause_write = 1'b1;
            csr_mcause_next  = interrupt_cause;
            
            // Update mstatus: MPIE = MIE, MIE = 0
            csr_mstatus_write = 1'b1;
            csr_mstatus_next = mstatus_value;
            csr_mstatus_next[MSTATUS_MPIE_BIT] = mstatus_value[MSTATUS_MIE_BIT];
            csr_mstatus_next[MSTATUS_MIE_BIT]  = 1'b0;
            
            // Flush pipeline
            if_id_flush  = 1'b1;
            id_ex_flush  = 1'b1;
            ex_mem_flush = 1'b1;
        end
    end
 
endmodule
