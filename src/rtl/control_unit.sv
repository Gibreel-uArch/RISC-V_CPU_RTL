module control_unit (
    input  logic [6:0] opcode,
    output logic [1:0] AluOp,      
    output logic       MemRead,
    output logic       MemWrite,
    output logic       RegWrite,
    output logic       branch,
    output logic       AluSrc,
    output logic       MemtoReg
);
    always_comb begin
        AluOp    = 2'b00;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        RegWrite = 1'b0;
        branch   = 1'b0;
        AluSrc   = 1'b0;
        MemtoReg = 1'b0;

        case (opcode)
            // 1. R-type instructions (ADD, SUB)
            7'b0110011: begin
                RegWrite = 1'b1;
                AluOp    = 2'b10; 
            end

            // 2. I-type ALU (ADDI)
            7'b0010011: begin
                RegWrite = 1'b1;
                AluSrc   = 1'b1; 
                AluOp    = 2'b11; 
            end

            // 3. Load Word (LW)
            7'b0000011: begin
                RegWrite = 1'b1;
                AluSrc   = 1'b1; 
                MemRead  = 1'b1;
                MemtoReg = 1'b1; 
                AluOp    = 2'b00; 
            end

            // 4. Store Word (SW)
            7'b0100111: begin
                AluSrc   = 1'b1;
                MemWrite = 1'b1;
                AluOp    = 2'b00; 
            end

            // 5. Branch Equal (BEQ)
            7'b1100011: begin
                branch   = 1'b1;
                AluOp    = 2'b01; 
            end

            default: begin
                
            end
        endcase
    end
endmodule
