module instruction_memory (
    input  logic [31:0] address,
    output logic [31:0] instruction
);
    logic [31:0] mem [0:16383];
    
    string hex_file;
    initial begin
        if ($value$plusargs("HEX_FILE=%s", hex_file)) begin
            $readmemh(hex_file, mem);
        end else begin
            $display("Error: No HEX file specified!");
            $finish;
        end
    end

    assign instruction = mem[address[31:2]];

endmodule
