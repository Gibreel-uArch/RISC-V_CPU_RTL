module registers_file (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        RegWrite,
    input  logic [4:0]  rs1,
    input  logic [4:0]  rs2,
    input  logic [4:0]  rd,
    input  logic [31:0] WriteData,
    output logic [31:0] ReadData1,
    output logic [31:0] ReadData2
);

    // ==========================================
    // Internal Register Array Declaration
    // ==========================================
    logic [31:0] RegFile [0:31];

    // ==========================================
    // Asynchronous Read Logic (x0 hardwired to 0)
    // ==========================================
    always_comb begin
        ReadData1 = (rs1 == 5'b0) ? 32'b0 : RegFile[rs1];
        ReadData2 = (rs2 == 5'b0) ? 32'b0 : RegFile[rs2];
    end

    // ==========================================
    // Synchronous Write Logic
    // ==========================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) begin
                RegFile[i] <= 32'b0;
            end
        end
        else if (RegWrite && (rd != 5'b0)) begin
            RegFile[rd] <= WriteData;
        end
    end

endmodule
