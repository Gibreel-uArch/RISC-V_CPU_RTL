module control_unit (
    input  logic [6:0] opcode,
    output logic [2:0] AluOp,      
    output logic       MemRead,
    output logic       MemWrite,
    output logic       RegWrite,
    output logic       Branch,
    output logic       AluSrc1,
    output logic       AluSrc2,
    output logic       MemtoReg,
    output logic       JumpImm,
    output logic       JumpReg,
    output logic       WriteData
);
    always_comb begin
        AluOp    = 3'b000;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        RegWrite = 1'b0;
        Branch   = 1'b0;
        AluSrc2  = 1'b0;
        AluSrc1  = 1'b0;
        MemtoReg = 1'b0;
        JumpImm  = 1'b0;
        JumpReg  = 1'b0;
        WriteData= 1'b0;


        case (opcode)
            // 1. R-type instructions 
            7'b0110011: begin
                RegWrite = 1'b1;
                AluOp    = 3'b010; 
            end

            // 2. I-type instructions
            7'b0010011: begin
                RegWrite = 1'b1;
                AluSrc2  = 1'b1; 
                AluOp    = 3'b011; 
            end

            // 3. Load Word (LW)
            7'b0000011: begin
                RegWrite = 1'b1;
                AluSrc2  = 1'b1; 
                MemRead  = 1'b1;
                MemtoReg = 1'b1; 
                AluOp    = 3'b000; 
            end

            // 4. Store Word (SW)
            7'b0100011: begin
                AluSrc2  = 1'b1;
                MemWrite = 1'b1;
                AluOp    = 3'b000; 
            end

            // 5. Branch instrictions (SB)
            7'b1100011: begin
                Branch   = 1'b1;
                AluOp    = 3'b001; 
            end
            
            // 6. Upper immediate lui
            7'b0110111: begin
                AluOp    = 3'b000;
                AluSrc2  = 1'b1;
                RegWrite = 1'b1;
            end 

            // 6. Upper immediate luipc
            7'b0010111: begin
                AluOp    = 3'b100;
                AluSrc1  = 1'b1;
                AluSrc2  = 1'b1;
                RegWrite = 1'b1;
            end 
            
            // 7. Jump instriction jal
            7'b1101111: begin
                WriteData= 1'b1;
                JumpImm  = 1'b1;
                RegWrite = 1'b1;
            end

            // 8. Jump instriction jalr
            7'b1100111: begin
                WriteData= 1'b1;
                JumpReg  = 1'b1;
                RegWrite = 1'b1;
                AluSrc2  = 1'b1;
                AluOp    = 3'b000;
            end
            default: begin
                
            end
        endcase
    end
endmodule
