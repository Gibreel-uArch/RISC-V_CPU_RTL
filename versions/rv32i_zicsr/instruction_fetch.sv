/**
 * @file instruction_fetch.sv
 * @brief Instruction Fetch (IF) Stage Wrapper
 * @details Integrates the Program Counter unit (pc_unit) and the Instruction 
 *          Memory (instruction_memory) to fetch instructions sequentially or via control flow changes.
 */

import rv32_types_pkg::*;

module instruction_fetch (
    // Clock and Reset
    input  logic        clk, 
    input  logic        rst_n,
    
    // Control & Hazard Signals
    input  logic        take_branch,
    input  logic        JumpImm,
    input  logic        JumpReg,
    input  logic        stall_pc,
    input logic        trap_jump,
    input logic        mret_jump,
    
    // Target Addresses & Operands
    input  logic [31:0] trap_next_pc,        // next pc from trap controller
    input  logic [31:0] instruction_address, // Base address for branch/jump calculations
    input  logic [31:0] JumpReg_addr,        // Register source for JALR
    input  logic [31:0] imm,                 // Immediate offset
    
    // Stage Outputs
    output logic [31:0] instruction,         // Fetched instruction
    output logic [31:0] pc_plus_4,           // PC + 4 for sequential flow / link register
    output logic [31:0] pc_current           // Current Program Counter value
);

    // Instantiate Program Counter (PC) Generation Unit
    pc_unit u_pc_unit (
        .clk                 (clk),
        .rst_n               (rst_n),
        .stall_pc            (stall_pc),
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

    // Instantiate Instruction Memory (ROM / Instruction Cache model)
    instruction_memory u_instruction_memory (
        .address             (pc_current),
        .instruction         (instruction)
    );

endmodule
