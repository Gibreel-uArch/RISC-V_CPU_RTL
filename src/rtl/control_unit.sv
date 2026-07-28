import rv32_types_pkg::*;

module control_unit (
    input  logic [6:0]   opcode,
    output ctrl_signals_t ctrl  
);
    always_comb begin
        ctrl.ex.AluOp     = 3'b000;
        ctrl.ex.AluSrc1   = 1'b0;
        ctrl.ex.AluSrc2   = 1'b0;
        ctrl.id.Branch    = 1'b0;
        ctrl.id.JumpImm   = 1'b0;
        ctrl.id.JumpReg   = 1'b0;

        ctrl.mem.MemRead  = 1'b0;
        ctrl.mem.MemWrite = 1'b0;

        ctrl.wb.RegWrite  = 1'b0;
        ctrl.wb.MemtoReg  = 1'b0; 
        ctrl.wb.WriteData = 1'b0;

        ctrl.wb.MemtoReg  = 1'b0;

        case (opcode)

            // 1. R-type instructions 
            7'b0110011: begin
                ctrl.wb.RegWrite = 1'b1;
                ctrl.ex.AluOp    = 3'b010; 
            end

            // 2. I-type instructions
            7'b0010011: begin
                ctrl.wb.RegWrite = 1'b1;
                ctrl.ex.AluSrc2  = 1'b1; 
                ctrl.ex.AluOp    = 3'b011; 
            end

            // 3. Load Word (LW)
            7'b0000011: begin
                ctrl.wb.RegWrite = 1'b1;
                ctrl.ex.AluSrc2  = 1'b1; 
                ctrl.mem.MemRead = 1'b1;
                ctrl.wb.MemtoReg = 1'b1; 
                ctrl.ex.AluOp    = 3'b000; 
            end

            // 4. Store Word (SW)
            7'b0100011: begin
                ctrl.ex.AluSrc2   = 1'b1;
                ctrl.mem.MemWrite = 1'b1;
                ctrl.ex.AluOp     = 3'b000; 
            end

            // 5. Branch instructions (SB)
            7'b1100011: begin
                ctrl.id.Branch    = 1'b1;
                ctrl.ex.AluOp     = 3'b001; 
            end
            
            // 6. Upper immediate (LUI)
            7'b0110111: begin
                ctrl.ex.AluOp     = 3'b000;
                ctrl.ex.AluSrc2   = 1'b1;
                ctrl.wb.RegWrite  = 1'b1;
            end 

            // 7. Upper immediate (AUIPC)
            7'b0010111: begin
                ctrl.ex.AluOp     = 3'b100;
                ctrl.ex.AluSrc1   = 1'b1;
                ctrl.ex.AluSrc2   = 1'b1;
                ctrl.wb.RegWrite  = 1'b1;
            end 
            
            // 8. Jump instruction (JAL)
            7'b1101111: begin
                ctrl.wb.WriteData = 1'b1;
                ctrl.id.JumpImm   = 1'b1;
                ctrl.wb.RegWrite  = 1'b1;
            end

            // 9. Jump instruction (JALR)
            7'b1100111: begin
                ctrl.wb.WriteData = 1'b1;
                ctrl.id.JumpReg   = 1'b1;
                ctrl.wb.RegWrite  = 1'b1;
            end 

            default: begin

            end
        endcase
    end
endmodule
