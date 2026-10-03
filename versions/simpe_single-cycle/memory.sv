module memory (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        MemRead,
    input  logic        MemWrite,
    input  logic [31:0] WriteData,
    input  logic [31:0] address,
    output logic [31:0] MemoryData
);

    // ==========================================
    // Internal Memory Array Declaration (1024 words)
    // ==========================================
    logic [31:0] memory [0:1023];

    // ==========================================
    // Asynchronous Read Logic
    // ==========================================
    assign MemoryData = (MemRead) ? memory[address[31:2]] : 32'b0;

    // ==========================================
    // Synchronous Write Logic
    // ==========================================
    always_ff @(posedge clk) begin 
        if (MemWrite) begin
            memory[address[31:2]] <= WriteData; 
        end
    end

endmodule
