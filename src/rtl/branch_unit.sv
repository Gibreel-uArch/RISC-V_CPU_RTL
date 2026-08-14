/**
 * @file branch_unit.sv
 * @brief RISC-V Branch Evaluation Unit
 * @details Evaluates conditional branch instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
 *          by comparing source operands and applying function code modifiers.
 */

import rv32_types_pkg::*;

module branch_unit (
    // Control and Status Inputs
    input  logic        Branch,       // Indicates a conditional branch instruction
    input  logic [2:0]  func3,        // RISC-V branch type specifier (funct3)
    input  logic [31:0] ReadData1,    // First operand (RS1 value)
    input  logic [31:0] ReadData2,    // Second operand (RS2 value)
    input  logic        stall_branch, // Stall signal masking branch resolution
    
    // Output
    output logic        take_branch   // High if the branch condition is met and should be taken
);

    // Internal Comparison Helper Signals
    logic        zero;
    logic        less;
    logic        less_unsigned;
    logic        overflow;
    logic        sign;
    logic        sub_cond;
    logic [31:0] sub_result;

    // Subtraction result for condition evaluation (ReadData1 - ReadData2)
    assign sub_result = ReadData1 - ReadData2;
    
    // Comparison metrics derivation
    assign zero          = (sub_result == 32'b0);  
    assign sign          = sub_result[31];        
    assign overflow      = (ReadData1[31] ^ ReadData2[31]) & (sub_result[31] ^ ReadData1[31]);
    assign less          = sign ^ overflow;       // Signed less than comparison
    assign less_unsigned = (ReadData1 < ReadData2); // Unsigned less than comparison

    /**
     * @brief Combinational evaluation of branch conditions based on funct3[2:1]
     * @details Maps branch types: BEQ/BNE (00), BLT/BGE (10), BLTU/BGEU (11)
     */
    always_comb begin
        case (func3[2:1])  
            2'b00   : sub_cond = zero;          // BEQ / BNE condition base
            2'b10   : sub_cond = less;          // BLT / BGE condition base
            2'b11   : sub_cond = less_unsigned; // BLTU / BGEU condition base
            default : sub_cond = 1'b0;
        endcase
    end

    // Final branch decision: Active branch signal, condition check inverted by func3[0] (e.g., BNE), and no stall
    assign take_branch = Branch & (sub_cond ^ func3[0]) & (~stall_branch);

endmodule
