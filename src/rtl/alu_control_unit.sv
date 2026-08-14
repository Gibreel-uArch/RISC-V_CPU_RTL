/**
 * @file alu_control_unit.sv
 * @brief RISC-V ALU Control Unit
 * @details Decodes ALU operation type (AluOp), function 3 (funct3), and function 7 
 *          (funct7) bits to generate the appropriate 4-bit control code for the ALU.
 */

import rv32_types_pkg::*;

module alu_control_unit (
    input  logic [2:0] AluOp,       // Operation category from main control unit
    input  logic [2:0] func3,       // Instruction funct3 field
    input  logic [6:0] func7,       // Instruction funct7 field
    output logic [4:0] alu_control  // 4-bit control signal mapping to ALU operations
);
    
    /**
     * @brief Combinational ALU control decoder
     * @details Maps instruction types (R-type, I-type, loads/stores, branches, LUI) 
     *          to specific internal ALU control signals. Defaults to ADD (4'b0010).
     */
    always_comb begin
        // Default safe operation: ADD
        alu_control = 4'b0010;

        case (AluOp)
            // Memory accesses, LUI/AUIPC address additions, JALR
            3'b000 : alu_control = 4'b0010;            // ADD
            
            // LUI specific direct pass-through or shift handling
            3'b100 : alu_control = 4'b1010;            // LUI pass / specialized op

            // Branch operations (Subtraction for comparison)
            3'b001 : alu_control = 4'b0110;            // SUB (for SB-type branches)

            // R-Type Instructions Decoding
            3'b010 : begin
                case (func3)
                    3'b000: begin
                        if (func7[5] == 1'b1)  
                            alu_control = 4'b0110;     // SUB (e.g., sub)
                        else                     
                            alu_control = 4'b0010;     // ADD (e.g., add)
                    end
                    3'b001 : alu_control = 4'b0100;    // SLL (Shift Left Logical)
                    3'b010 : alu_control = 4'b0111;    // SLT (Set Less Than - Signed)
                    3'b011 : alu_control = 4'b1000;    // SLTU (Set Less Than - Unsigned)    
                    3'b100 : alu_control = 4'b0011;    // XOR
                    3'b101 : begin
                        if (func7[5] == 1'b1)  
                            alu_control = 4'b1000;     // SRA (Shift Right Arithmetic)  
                        else                     
                            alu_control = 4'b0101;     // SRL (Shift Right Logical)
                    end
                    3'b110 : alu_control = 4'b0001;    // OR
                    3'b111 : alu_control = 4'b0000;    // AND
                    default: alu_control = 4'b0010;
                endcase
            end

            // I-Type (Immediate Arithmetic & Logical) Instructions Decoding
            3'b011 : begin
                case (func3)
                    3'b000 : alu_control = 4'b0010;    // ADDI 
                    3'b001 : alu_control = 4'b0100;    // SLLI
                    3'b010 : alu_control = 4'b0111;    // SLTI
                    3'b011 : alu_control = 4'b1001;    // SLTUI   
                    3'b100 : alu_control = 4'b0011;    // XORI
                    3'b101 : begin
                        if (func7[5] == 1'b1)  
                            alu_control = 4'b1000;     // SRAI  
                        else                     
                            alu_control = 4'b0101;     // SRLI
                    end
                    3'b110 : alu_control = 4'b0001;    // ORI
                    3'b111 : alu_control = 4'b0000;    // ANDI
                    default: alu_control = 4'b0010;
                endcase
            end

            default: alu_control = 4'b0010;
        endcase
    end

endmodule
