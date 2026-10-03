module alu (
    input  logic [3:0]  alu_control,
    input  logic [31:0] src1,
    input  logic [31:0] src2,
    output logic [31:0] alu_result,
    output logic        zero,
    output logic        less,
    output logic        less_unsigned
);

    logic [31:0] sub_result;
    assign sub_result = src1 - src2;

    logic overflow, sign;
    
    assign zero          = (sub_result == 32'b0); 
    assign sign          = sub_result[31];        
    
    assign overflow      = (src1[31] ^ src2[31]) & (sub_result[31] ^ src1[31]);
    
    assign less          = sign ^ overflow;       
    assign less_unsigned = (src1 < src2);         

    always_comb begin
        case (alu_control)
            4'b0000  : alu_result = src1 & src2;                     // AND / ANDI
            4'b0001  : alu_result = src1 | src2;                     // OR / ORI
            4'b0010  : alu_result = src1 + src2;                     // ADD / ADDI
            4'b0011  : alu_result = src1 ^ src2;                     // XOR / XORI
            4'b0100  : alu_result = src1 << src2[4:0];               // SLL / SLLI
            4'b0101  : alu_result = src1 >> src2[4:0];               // SRL / SRLI
            4'b0110  : alu_result = sub_result;                      // SUB 
            4'b0111  : alu_result = {31'b0, less};                   // SLT / SLTI 
            4'b1000  : alu_result = $signed(src1) >>> src2[4:0];     // SRA / SRAI
            4'b1001  : alu_result = {31'b0, less_unsigned};          // SLTU / SLTUI 
            4'b1010  : alu_result = src2;                            // LUI
            default  : alu_result = 32'b0 ;
        endcase
    end

endmodule
