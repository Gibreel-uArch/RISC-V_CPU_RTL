module instruction_memory (
    input  logic [31:0] address,
    output logic [31:0] instruction
);
    logic [31:0] mem [0:1023];
    initial begin
        $readmemh("programe.hex",mem);
    end
    assign instruction = mem[address >> 2];

endmodule
