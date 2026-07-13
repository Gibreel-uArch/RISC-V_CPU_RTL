module alu (
    input  logic [3:0]   alu_control,  // control signal
    input  logic [31:0]  src1,          // input one
    input  logic [31:0]  src2,          // input two 
    output logic [31:0]  alu_result,
    output logic         zero_flag
);
        always_comb begin  
           case (alu_control)
             4'b0000  : alu_result = src1 & src2;
             4'b0001  : alu_result = src1 | src2;
             4'b0010  : alu_result = src1 + src2;
             4'b0110  : alu_result = src1 - src2;
             default  : alu_result = 32'b0 ;
           endcase 
        end

        assign zero_flag = (alu_result == 32'b0);
endmodule
