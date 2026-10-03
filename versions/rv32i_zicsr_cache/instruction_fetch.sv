/**
 * @file instruction_fetch.sv
 * @brief Instruction Fetch (IF) Stage Wrapper
 * @details Integrates the Program Counter unit (pc_unit) and the Instruction 
 *          Memory (instruction_memory) to fetch instructions sequentially or via control flow changes.
 */

import rv32_types_pkg::*;

module instruction_fetch (

    input  logic        clk,
    input  logic        rst_n,
    
    // Control & Hazard Signals 
    input  logic        take_branch,
    input  logic        JumpImm,
    input  logic        JumpReg,
    input  logic        pc_stall,            // Stall PC signal from Hazard Unit

    input logic         trap_jump,
    input logic         mret_jump,
    
    // Target Addresses & Operands
    input  logic [31:0] trap_next_pc,        // Address from Trap Controller
    input  logic [31:0] instruction_address, // Base address for branch/jump
    input  logic [31:0] JumpReg_addr,        // Register source for JALR
    input  logic [31:0] imm,                 // Immediate offset
    
    // Stage Outputs
    output logic [31:0] instruction,         // Fetched instruction
    output logic [31:0] pc_plus_4,           // PC + 4
    output logic [31:0] pc_current,          // Current PC value
    output logic        icache_miss          // Explicit Miss signal to Hazard Unit
);

    // -------------------------------------------------------------
    // Internal Signals
    // -------------------------------------------------------------
    logic         mem_valid;
    logic         mem_resp_valid;
    logic [31:0]  mem_addr;
    logic [127:0] mem_data;
    logic         cpu_req;
    logic         hit;

    // CPU request is active during normal operation (not in reset)
    assign cpu_req     = rst_n;
    assign icache_miss = !hit; 

    // -------------------------------------------------------------
    // 1. Program Counter (PC) Generation Unit
    // -------------------------------------------------------------
    pc_unit u_pc_unit (
        .clk                 (clk),
        .rst_n               (rst_n),
        .pc_stall            (pc_stall),          
        .trap_jump           (trap_jump),
        .mret_jump           (mret_jump),
        .trap_next_pc        (trap_next_pc),   
        .take_branch         (take_branch),
        .JumpImm             (JumpImm),
        .JumpReg             (JumpReg),
        .instruction_address (instruction_address),
        .JumpReg_addr        (JumpReg_addr),
        .imm                 (imm),
        .pc_current          (pc_current),
        .pc_plus_4           (pc_plus_4) 
    );

    // -------------------------------------------------------------
    // 2. Instruction Cache (I-Cache)
    // -------------------------------------------------------------
    icache u_icache (
        .clk            (clk),
        .rst_n          (rst_n),
        .address        (pc_current),
        .data_out       (instruction),
        .cpu_req        (cpu_req),             
        .hit            (hit),                 
        
        // Memory Interface
        .mem_addr       (mem_addr),
        .mem_valid      (mem_valid),
        .mem_data       (mem_data),
        .mem_resp_valid (mem_resp_valid)
    );

    // -------------------------------------------------------------
    // 3. Instruction Main Memory
    // -------------------------------------------------------------
    instruction_memory u_instruction_memory (
        .clk            (clk),
        .mem_addr       (mem_addr),
        .mem_valid      (mem_valid),
        .mem_data       (mem_data),
        .mem_resp_valid (mem_resp_valid)
    );

endmodule
