module branch_unit (
    input  logic Branch,
    input  logic [2:0] func3,
    input  logic [31:0] ReadData1,
    input  logic [31:0] ReadData2,
    output logic take_branch
);
    logic zero;
    logic less;
    logic less_unsigned;
    logic overflow, sign;
    logic sub_cond;

    logic [31:0] sub_result;
    assign sub_result = ReadData1 - ReadData2;
    
    assign zero          = (sub_result == 32'b0); 
    assign sign          = sub_result[31];        
    assign overflow      = (ReadData1[31] ^ ReadData2[31]) & (sub_result[31] ^ ReadData1[31]);
    assign less          = sign ^ overflow;       
    assign less_unsigned = (ReadData1 < ReadData2);


    always_comb begin
        case(func3[2:1]) 
            2'b00   : sub_cond = zero;
            2'b10   : sub_cond = less;
            2'b11   : sub_cond = less_unsigned;
            default : sub_cond = 1'b0;
        endcase
    end

    assign take_branch = Branch & (sub_cond ^ func3[0]);
endmodule
