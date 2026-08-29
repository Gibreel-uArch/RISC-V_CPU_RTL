/**
 * @file control_unit.sv
 * @brief RISC-V Main Control Unit
 * @details Decodes the 7-bit instruction opcode and generates control signals 
 *          for instruction decode, execution, memory access, and writeback stages.
 *          Includes safe default values to prevent unintended side effects or latches.
 */

import rv32_types_pkg::*;

module control_unit (
    input  logic [2:0]     func3,
    input  logic [11:0]    imm,
    input  logic [6:0]     opcode,  // Instruction opcode field (bits [6:0])
    
    output ctrl_signals_t  ctrl,    // Structured control signals bundle
    output excep_signals_t excep    // exceptions signals for trap controller
);

    always_comb begin
        // --- Safe Default Control Assignments ---
        // Prevents inference of latches and ensures default NOP/bubble behavior
        ctrl.id.Branch     = 1'b0;
        ctrl.id.JumpImm    = 1'b0;
        ctrl.id.JumpReg    = 1'b0;
        ctrl.id.UseRs1     = 1'b0;
        ctrl.id.UseRs2     = 1'b0;

        ctrl.ex.AluOp      = 3'b000;
        ctrl.ex.AluSrc1    = 1'b0;
        ctrl.ex.AluSrc2    = 1'b0;

        ctrl.mem.MemRead   = 1'b0;
        ctrl.mem.MemWrite  = 1'b0;

        ctrl.wb.RegWrite   = 1'b0;
        ctrl.wb.WriteData  = 2'b00;

        ctrl.csr.Read      = 1'b0;
        ctrl.csr.Write     = 1'b0;
        ctrl.csr.Set       = 1'b0;
        ctrl.csr.Clear     = 1'b0;


        excep.ecall_inst   = 1'b0;
        excep.ebreak_inst  = 1'b0;
        excep.mret_inst    = 1'b0;
        excep.illegal_inst = 1'b0;

        // --- Opcode Decoding Logic ---
        case (opcode)

            // 1. R-type instructions (e.g., ADD, SUB, AND, OR)
            7'b0110011: begin
                ctrl.wb.RegWrite  = 1'b1;
                ctrl.wb.WriteData = 2'b00;
                ctrl.ex.AluOp     = 3'b010;
                ctrl.id.UseRs1    = 1'b1;
                ctrl.id.UseRs2    = 1'b1;
            end

            // 2. I-type arithmetic/logic instructions (e.g., ADDI, SLI, SLTI)
            7'b0010011: begin
                ctrl.wb.RegWrite  = 1'b1;
                ctrl.wb.WriteData = 2'b00;
                ctrl.ex.AluSrc2   = 1'b1;   // Select immediate for ALU source 2
                ctrl.ex.AluOp     = 3'b011; 
                ctrl.id.UseRs1    = 1'b1;
            end

            // 3. Load Word instruction (LW)
            7'b0000011: begin
                ctrl.wb.RegWrite  = 1'b1;
                ctrl.wb.WriteData = 2'b01;
                ctrl.ex.AluSrc2   = 1'b1;   // Select immediate for address calculation
                ctrl.mem.MemRead  = 1'b1;
                ctrl.ex.AluOp     = 3'b000; // Addition (Base + Offset)
                ctrl.id.UseRs1    = 1'b1;
            end

            // 4. Store Word instruction (SW)
            7'b0100011: begin
                ctrl.ex.AluSrc2   = 1'b1;   // Select immediate for address calculation
                ctrl.mem.MemWrite = 1'b1;
                ctrl.ex.AluOp     = 3'b000; // Addition (Base + Offset)
                ctrl.id.UseRs1    = 1'b1;
                ctrl.id.UseRs2    = 1'b1;
            end

            // 5. Branch instructions (SB-type, e.g., BEQ, BNE, BLT)
            7'b1100011: begin
                ctrl.id.Branch    = 1'b1;
                ctrl.ex.AluOp     = 3'b001; 
                ctrl.id.UseRs1    = 1'b1;
                ctrl.id.UseRs2    = 1'b1;
            end
            
            // 6. Load Upper Immediate instruction (LUI)
            7'b0110111: begin
                ctrl.wb.RegWrite  = 1'b1;
                ctrl.wb.WriteData = 2'b00;
                ctrl.ex.AluOp     = 3'b100;
                ctrl.ex.AluSrc2   = 1'b1;
            end 

            // 7. Add Upper Immediate to PC instruction (AUIPC)
            7'b0010111: begin
                ctrl.wb.RegWrite  = 1'b1;
                ctrl.wb.WriteData = 2'b00;
                ctrl.ex.AluOp     = 3'b000;
                ctrl.ex.AluSrc1   = 1'b1;   // Select PC as ALU source 1
                ctrl.ex.AluSrc2   = 1'b1;   // Select immediate as ALU source 2
            end 
            
            // 8. Jump and Link instruction (JAL)
            7'b1101111: begin
                ctrl.wb.RegWrite  = 1'b1;
                ctrl.wb.WriteData = 2'b10;  // Select PC+4 for link register writeback
                ctrl.id.JumpImm   = 1'b1;
            end

            // 9. Jump and Link Register instruction (JALR)
            7'b1100111: begin
                ctrl.wb.RegWrite  = 1'b1;
                ctrl.wb.WriteData = 2'b10;  // Select PC+4 for link register writeback
                ctrl.id.JumpReg   = 1'b1;
                ctrl.id.UseRs1    = 1'b1;
            end

            // 10. System Instructions (ECALL, EBREAK, MRET)
            7'b1110011: begin
                case (func3)
                    // ECALL, EBREAK, MRET, WFI
                    3'b000: begin
                        case (imm[11:0])
                            12'h000 : excep.ecall_inst   = 1'b1;
                            12'h001 : excep.ebreak_inst  = 1'b1;
                            12'h302 : excep.mret_inst    = 1'b1;
                       //     12'h105 : excep.wfi_inst     = 1'b1;  
                            default : excep.illegal_inst = 1'b1;
                        endcase
                    end
                    
                    // CSRRW - Atomic Read/Write CSR
                    3'b001: begin
                        ctrl.csr.Read     = 1'b1;
                        ctrl.csr.Write    = 1'b1;
                        ctrl.id.UseRs1    = 1'b1;
                        ctrl.wb.RegWrite  = 1'b1;
                        ctrl.wb.WriteData = 2'b11;  
                    end
                    
                    // CSRRS - Atomic Read and Set Bits in CSR
                    3'b010: begin
                        ctrl.csr.Read     = 1'b1;
                        ctrl.csr.Set      = 1'b1;
                        ctrl.id.UseRs1    = 1'b1;
                        ctrl.wb.RegWrite  = 1'b1;
                        ctrl.wb.WriteData = 2'b11;  
                    end
                    
                    // CSRRC - Atomic Read and Clear Bits in CSR
                    3'b011: begin
                        ctrl.csr.Read     = 1'b1;
                        ctrl.csr.Clear    = 1'b1;
                        ctrl.id.UseRs1    = 1'b1;
                        ctrl.wb.RegWrite  = 1'b1;
                        ctrl.wb.WriteData = 2'b11;  
                    end
                    
                    // CSRRWI - Atomic Read/Write CSR Immediate
                    3'b101: begin
                        ctrl.csr.Read     = 1'b1;
                        ctrl.csr.Write    = 1'b1;
                        ctrl.wb.RegWrite  = 1'b1;
                        ctrl.wb.WriteData = 2'b11;  
                    end
                    
                    // CSRRSI - Atomic Read and Set Bits in CSR Immediate
                    3'b110: begin
                        ctrl.csr.Read     = 1'b1;
                        ctrl.csr.Set      = 1'b1;
                        ctrl.wb.RegWrite  = 1'b1;
                        ctrl.wb.WriteData = 2'b11;  
                    end
                    
                    // CSRRCI - Atomic Read and Clear Bits in CSR Immediate
                    3'b111: begin
                        ctrl.csr.Read     = 1'b1;
                        ctrl.csr.Clear    = 1'b1;
                        ctrl.wb.RegWrite  = 1'b1;
                        ctrl.wb.WriteData = 2'b11; 
                    end
                    
                    default: excep.illegal_inst = 1'b1;
                endcase
            end
            
            7'b0000000: ;
            // Default fallback: return an exception if the opcode not supported 
            default: excep.illegal_inst = 1'b1; 
        endcase
    end

endmodule
