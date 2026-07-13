module memory (
    input  logic clk, rst_n,
    input  logic MemRead,MemWrite,
    input  logic [31:0] WriteData,
    input  logic [31:0] address,
    output logic [31:0] MemoryData
);
    logic [31:0] memory [0:1023];
    initial begin
        $readmemh("memory.hex",memory, 16);
    end
    assign MemoryData = (MemRead) ? memory[address[31:2]] : 32'b0;
    
    always_ff @(posedge clk) begin 
        if (MemWrite) begin
            memory[address[31:2]] <= WriteData; 
        end
    end
endmodule
