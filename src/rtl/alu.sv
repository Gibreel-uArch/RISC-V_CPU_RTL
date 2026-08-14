/**
 * @file alu.sv
 * @brief RISC-V 32-Bit Arithmetic Logic Unit (ALU)
 * @details Performs arithmetic, logical, shift, and comparison operations. 
 *          Computes auxiliary status flags (zero, signed less-than, unsigned less-than) 
 *          used by branch and set instructions.
 */

import rv32_types_pkg::*;

module alu (
    // Control & Operands
    input  logic [3:0]  alu_control,    // Operation selection code
    input  logic [31:0] src1,           // First operand
    input  logic [31:0] src2,           // Second operand
    
    // Outputs & Status Flags
    output logic [31:0] alu_result,     // Computed operation result
    output logic        zero,           // High if alu_result is zero
    output logic        less,           // High if src1 < src2 (signed)
    output logic        less_unsigned   // High if src1 < src2 (unsigned)
);

    // Internal Status and Subtraction Signals
    logic [31:0] sub_result;
    logic        overflow;
    logic        sign;
    
    // Core subtraction path used for arithmetic comparisons and sub operations
    assign sub_result = src1 - src2;

    // Status flag derivations
    assign zero          = (sub_result == 32'b0);  
    assign sign          = sub_result[31];        
    assign overflow      = (src1[31] ^ src2[31]) & (sub_result[31] ^ src1[31]);
    assign less          = sign ^ overflow;       // Signed comparison flag (SLT)
    assign less_unsigned = (src1 < src2);         // Unsigned comparison flag (SLTU)

    /**
     * @brief Combinational ALU Operation Multiplexer
     * @details Decodes alu_control to execute logic, arithmetic, shifts, or comparisons.
     */
    always_comb begin
        case (alu_control)
            4'b0000  : alu_result = src1 & src2;                     // AND / ANDI
            4'b0001  : alu_result = src1 | src2;                     // OR / ORI
            4'b0010  : alu_result = src1 + src2;                     // ADD / ADDI
            4'b0011  : alu_result = src1 ^ src2;                     // XOR / XORI
            4'b0100  : alu_result = src1 << src2[4:0];               // SLL / SLLI (Shift Left Logical)
            4'b0101  : alu_result = src1 >> src2[4:0];               // SRL / SRLI (Shift Right Logical)
            4'b0110  : alu_result = sub_result;                      // SUB / Branch condition baseline
            4'b0111  : alu_result = {31'b0, less};                   // SLT / SLTI (Set Less Than Signed)
            4'b1000  : alu_result = $signed(src1) >>> src2[4:0];     // SRA / SRAI (Shift Right Arithmetic)
            4'b1001  : alu_result = {31'b0, less_unsigned};          // SLTU / SLTUI (Set Less Than Unsigned)
            4'b1010  : alu_result = src2;                            // LUI (Load Upper Immediate pass-through)
            default  : alu_result = 32'b0;                           // Default / Safe fallback
        endcase
    end

endmodule
