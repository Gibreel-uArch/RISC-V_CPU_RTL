/**
 * @file immediate_generator.sv
 * @brief RISC-V 32-Bit Immediate Generation Unit
 * @details Extracts and sign-extends or pads instruction immediate fields based on 
 *          the opcode type (I-type, S-type, SB-type, U-type, UJ-type).
 */

import rv32_types_pkg::*;

module immediate_generator (
    input  logic [31:0] instruction, // Raw 32-bit RISC-V instruction word
    output logic [31:0] imm          // Sign-extended / formatted 32-bit immediate output
);

    /**
     * @brief Combinational Immediate Extraction Multiplexer
     * @details Decodes instruction[6:0] opcode to parse formatting fields and apply 
     *          proper bit-shifting, concatenation, and sign extension.
     */
    always_comb begin 
        case (instruction[6:0])
            // 1. I-type instructions (e.g., Load, JALR, I-type ALU) -> imm[11:0]
            7'b0010011, 7'b0000011, 7'b1100111: begin
                imm = {{20{instruction[31]}}, instruction[31:20]};
            end
            
            // 2. S-type instructions (Stores: SB, SH, SW) -> imm[11:5] & imm[4:0]
            7'b0100011: begin
                imm = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]}; 
            end
            
            // 3. SB-type instructions (Branches: BEQ, BNE, etc.) -> imm[12|10:5|4:1|11] with implicit LSB 0
            7'b1100011: begin
                imm = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
            end        
            
            // 4. U-type instructions (LUI, AUIPC) -> upper 20 bits shifted, lower 12 bits zeroed
            7'b0010111, 7'b0110111: begin
                imm = {instruction[31:12], 12'b0};
            end
            
            // 5. UJ-type instructions (JAL) -> imm[20|10:1|11|19:12] with implicit LSB 0
            7'b1101111: begin
                imm = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            end
            
            // Default: Safe fallback for R-type or unmapped opcodes
            default: begin
                imm = 32'b0;
            end
        endcase
    end

endmodule
