/**
 * @file cs_registers.sv
 * @brief RISC-V control and status registers
 * @details This module implements the Control and Status Registers (CSRs) for a RISC-V core 
 *          (such as MSTATUS, MIE, MIP, MTVEC, MEPC, MCAUSE, MTVAL, and MSCRATCH). It handles 
 *          regular pipeline read/write/set/clear instructions, trap controller updates with 
 *          higher priority, and hardware-driven interrupt pending inputs (like timer interrupts).
 */

import rv32_types_pkg::*;

module cs_registers (
    input  logic        clk,
    input  logic        rst_n,
    
    // Regular CSR access from pipeline
    input  logic        csr_write_en,
    input  logic        csr_set_en,
    input  logic        csr_clear_en,
    input  logic [11:0] csr_addr,
    input  logic [31:0] csr_wdata,
    output logic [31:0] csr_rdata,
    
    // Trap controller interface
    input  logic        trap_mepc_write,
    input  logic [31:0] trap_mepc_next,
    input  logic        trap_mcause_write,
    input  logic [31:0] trap_mcause_next,
    input  logic        trap_mstatus_write,
    input  logic [31:0] trap_mstatus_next,
    
    // Interrupt pending inputs
    input  logic        timer_interrupt_pending,
    
    // CSR outputs
    output logic [31:0] mstatus_value,
    output logic [31:0] mie_value,
    output logic [31:0] mip_value,
    output logic [31:0] mtvec_value,
    output logic [31:0] mepc_value,
    output logic [31:0] mcause_value,
    output logic [31:0] mtval_value,
    output logic [31:0] mscratch_value
);

    // ============================================
    // CSR addresses
    // ============================================
    localparam [11:0] CSR_MSTATUS   = 12'h300;
    localparam [11:0] CSR_MIE       = 12'h304;
    localparam [11:0] CSR_MTVEC     = 12'h305;
    localparam [11:0] CSR_MSCRATCH  = 12'h340;
    localparam [11:0] CSR_MEPC      = 12'h341;
    localparam [11:0] CSR_MCAUSE    = 12'h342;
    localparam [11:0] CSR_MTVAL     = 12'h343;
    localparam [11:0] CSR_MIP       = 12'h344;
    
    // ============================================
    // CSR registers
    // ============================================
    logic [31:0] mstatus_reg;
    logic [31:0] mie_reg;
    logic [31:0] mtvec_reg;
    logic [31:0] mscratch_reg;
    logic [31:0] mepc_reg;
    logic [31:0] mcause_reg;
    logic [31:0] mtval_reg;
    
    // MIP is read-only (hardware updated)
    logic [31:0] mip_reg;
    
    // ============================================
    // Read logic
    // ============================================
    always_comb begin
        csr_rdata = 32'b0;
        case (csr_addr)
            CSR_MSTATUS:  csr_rdata = mstatus_reg;
            CSR_MIE:      csr_rdata = mie_reg;
            CSR_MTVEC:    csr_rdata = mtvec_reg;
            CSR_MSCRATCH: csr_rdata = mscratch_reg;
            CSR_MEPC:     csr_rdata = mepc_reg;
            CSR_MCAUSE:   csr_rdata = mcause_reg;
            CSR_MTVAL:    csr_rdata = mtval_reg;
            CSR_MIP:      csr_rdata = mip_reg;
            default:      csr_rdata = 32'b0;
        endcase
    end
    
    // ============================================
    // Write logic (sequential)
    // ============================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus_reg  <= 32'h0;
            mie_reg      <= 32'h0;
            mtvec_reg    <= 32'h0;
            mscratch_reg <= 32'h0;
            mepc_reg     <= 32'h0;
            mcause_reg   <= 32'h0;
            mtval_reg    <= 32'h0;
        end
        else begin
            // Trap controller writes have priority
            if (trap_mepc_write) begin
                mepc_reg <= trap_mepc_next;
            end
            
            if (trap_mcause_write) begin
                mcause_reg <= trap_mcause_next;
            end
            
            if (trap_mstatus_write) begin
                mstatus_reg <= trap_mstatus_next;
            end
            
            // Regular CSR writes (lower priority)
            if (csr_write_en && !trap_mepc_write && !trap_mcause_write && !trap_mstatus_write) begin
                case (csr_addr)
                    CSR_MSTATUS:  mstatus_reg  <= csr_wdata;
                    CSR_MIE:      mie_reg      <= csr_wdata;
                    CSR_MTVEC:    mtvec_reg    <= csr_wdata;
                    CSR_MSCRATCH: mscratch_reg <= csr_wdata;
                    CSR_MEPC:     mepc_reg     <= csr_wdata;
                    CSR_MCAUSE:   mcause_reg   <= csr_wdata;
                    CSR_MTVAL:    mtval_reg    <= csr_wdata;
                    default: ; // Read-only or unsupported
                endcase
            end
            else if (csr_set_en && !trap_mepc_write && !trap_mcause_write && !trap_mstatus_write) begin
                case (csr_addr)
                    CSR_MSTATUS:  mstatus_reg  <= mstatus_reg | csr_wdata;
                    CSR_MIE:      mie_reg      <= mie_reg | csr_wdata;
                    CSR_MSCRATCH: mscratch_reg <= mscratch_reg | csr_wdata;
                    default: ;
                endcase
            end
            else if (csr_clear_en && !trap_mepc_write && !trap_mcause_write && !trap_mstatus_write) begin
                case (csr_addr)
                    CSR_MSTATUS:  mstatus_reg  <= mstatus_reg & ~csr_wdata;
                    CSR_MIE:      mie_reg      <= mie_reg & ~csr_wdata;
                    CSR_MSCRATCH: mscratch_reg <= mscratch_reg & ~csr_wdata;
                    default: ;
                endcase
            end
        end
    end
    
    // ============================================
    // MIP register (read-only, updated by hardware)
    // ============================================
    always_comb begin
        mip_reg = 32'b0;
        mip_reg[7]  = timer_interrupt_pending;      // MTIP
    end
    
    // ============================================
    // Output assignments
    // ============================================
    assign mstatus_value  = mstatus_reg;
    assign mie_value      = mie_reg;
    assign mip_value      = mip_reg;
    assign mtvec_value    = mtvec_reg;
    assign mepc_value     = mepc_reg;
    assign mcause_value   = mcause_reg;
    assign mtval_value    = mtval_reg;
    assign mscratch_value = mscratch_reg;

endmodule


import rv32_types_pkg::*;

module cs_registers (
    input  logic        clk,
    input  logic        rst_n,
    
    // Regular CSR access from pipeline
    input  logic        csr_write_en,
    input  logic        csr_set_en,
    input  logic        csr_clear_en,
    input  logic [11:0] csr_addr,
    input  logic [31:0] csr_wdata,
    output logic [31:0] csr_rdata,
    
    // Trap controller interface
    input  logic        trap_mepc_write,
    input  logic [31:0] trap_mepc_next,
    input  logic        trap_mcause_write,
    input  logic [31:0] trap_mcause_next,
    input  logic        trap_mstatus_write,
    input  logic [31:0] trap_mstatus_next,
    
    // Interrupt pending inputs
    input  logic        timer_interrupt_pending,
    
    // CSR outputs
    output logic [31:0] mstatus_value,
    output logic [31:0] mie_value,
    output logic [31:0] mip_value,
    output logic [31:0] mtvec_value,
    output logic [31:0] mepc_value,
    output logic [31:0] mcause_value,
    output logic [31:0] mtval_value,
    output logic [31:0] mscratch_value
);

    // ============================================
    // CSR addresses
    // ============================================
    localparam [11:0] CSR_MSTATUS   = 12'h300;
    localparam [11:0] CSR_MIE       = 12'h304;
    localparam [11:0] CSR_MTVEC     = 12'h305;
    localparam [11:0] CSR_MSCRATCH  = 12'h340;
    localparam [11:0] CSR_MEPC      = 12'h341;
    localparam [11:0] CSR_MCAUSE    = 12'h342;
    localparam [11:0] CSR_MTVAL     = 12'h343;
    localparam [11:0] CSR_MIP       = 12'h344;
    
    // ============================================
    // CSR registers
    // ============================================
    logic [31:0] mstatus_reg;
    logic [31:0] mie_reg;
    logic [31:0] mtvec_reg;
    logic [31:0] mscratch_reg;
    logic [31:0] mepc_reg;
    logic [31:0] mcause_reg;
    logic [31:0] mtval_reg;
    
    // MIP is read-only (hardware updated)
    logic [31:0] mip_reg;
    
    // ============================================
    // Read logic
    // ============================================
    always_comb begin
        csr_rdata = 32'b0;
        case (csr_addr)
            CSR_MSTATUS:  csr_rdata = mstatus_reg;
            CSR_MIE:      csr_rdata = mie_reg;
            CSR_MTVEC:    csr_rdata = mtvec_reg;
            CSR_MSCRATCH: csr_rdata = mscratch_reg;
            CSR_MEPC:     csr_rdata = mepc_reg;
            CSR_MCAUSE:   csr_rdata = mcause_reg;
            CSR_MTVAL:    csr_rdata = mtval_reg;
            CSR_MIP:      csr_rdata = mip_reg;
            default:      csr_rdata = 32'b0;
        endcase
    end
    
    // ============================================
    // Write logic (sequential)
    // ============================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus_reg  <= 32'h0;
            mie_reg      <= 32'h0;
            mtvec_reg    <= 32'h0;
            mscratch_reg <= 32'h0;
            mepc_reg     <= 32'h0;
            mcause_reg   <= 32'h0;
            mtval_reg    <= 32'h0;
        end
        else begin
            // Trap controller writes have priority
            if (trap_mepc_write) begin
                mepc_reg <= trap_mepc_next;
            end
            
            if (trap_mcause_write) begin
                mcause_reg <= trap_mcause_next;
            end
            
            if (trap_mstatus_write) begin
                mstatus_reg <= trap_mstatus_next;
            end
            
            // Regular CSR writes (lower priority)
            if (csr_write_en && !trap_mepc_write && !trap_mcause_write && !trap_mstatus_write) begin
                case (csr_addr)
                    CSR_MSTATUS:  mstatus_reg  <= csr_wdata;
                    CSR_MIE:      mie_reg      <= csr_wdata;
                    CSR_MTVEC:    mtvec_reg    <= csr_wdata;
                    CSR_MSCRATCH: mscratch_reg <= csr_wdata;
                    CSR_MEPC:     mepc_reg     <= csr_wdata;
                    CSR_MCAUSE:   mcause_reg   <= csr_wdata;
                    CSR_MTVAL:    mtval_reg    <= csr_wdata;
                    default: ; // Read-only or unsupported
                endcase
            end
            else if (csr_set_en && !trap_mepc_write && !trap_mcause_write && !trap_mstatus_write) begin
                case (csr_addr)
                    CSR_MSTATUS:  mstatus_reg  <= mstatus_reg | csr_wdata;
                    CSR_MIE:      mie_reg      <= mie_reg | csr_wdata;
                    CSR_MSCRATCH: mscratch_reg <= mscratch_reg | csr_wdata;
                    default: ;
                endcase
            end
            else if (csr_clear_en && !trap_mepc_write && !trap_mcause_write && !trap_mstatus_write) begin
                case (csr_addr)
                    CSR_MSTATUS:  mstatus_reg  <= mstatus_reg & ~csr_wdata;
                    CSR_MIE:      mie_reg      <= mie_reg & ~csr_wdata;
                    CSR_MSCRATCH: mscratch_reg <= mscratch_reg & ~csr_wdata;
                    default: ;
                endcase
            end
        end
    end
    
    // ============================================
    // MIP register (read-only, updated by hardware)
    // ============================================
    always_comb begin
        mip_reg = 32'b0;
        mip_reg[7]  = timer_interrupt_pending;      // MTIP
    end
    
    // ============================================
    // Output assignments
    // ============================================
    assign mstatus_value  = mstatus_reg;
    assign mie_value      = mie_reg;
    assign mip_value      = mip_reg;
    assign mtvec_value    = mtvec_reg;
    assign mepc_value     = mepc_reg;
    assign mcause_value   = mcause_reg;
    assign mtval_value    = mtval_reg;
    assign mscratch_value = mscratch_reg;

endmodule
