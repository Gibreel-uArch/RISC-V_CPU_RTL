module instruction_memory (
    input  logic [31:0] address,
    output logic [31:0] instruction
);
    logic [31:0] mem [0:16383];
    initial begin
        $readmemh("program.hex",mem);
    end
    assign instruction = mem[address[31:2]];

endmodule
