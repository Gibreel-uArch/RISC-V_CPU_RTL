module multiplexer (
    input  logic sel, 
    input  logic [31:0] in0, in1,
    output logic [31:0] out
);
    assign out = (sel) ? in1 : in0;
endmodule
