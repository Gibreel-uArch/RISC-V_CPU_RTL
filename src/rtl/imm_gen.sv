module imm_gen (
    input  logic [31:0] instruction,
    output logic [31:0] imm 
);
    always_comb begin 
        case (instruction[6:0])
            // (I Type)
            7'b0010011, 7'b0000011: begin
                imm = { {20{instruction[31]}}, instruction[31:20] };
            end
            // store (S Type)
            7'b0100011: begin
                imm = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]}; 
            end
            // branch (SB Type)
            7'b1100011: begin
                imm = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
            end       

            default: imm = 32'b0;
        endcase
    end
endmodule
