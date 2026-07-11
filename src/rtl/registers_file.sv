module registers_file (
    input  logic clk,rst_n,
    input  logic RegWrite,
    input  logic [4:0] rs1, rs2, rd,           // source 1&2 and destination
    input  logic [31:0] WriteData,             // data to save (from alu or memory)
    output logic [31:0] ReadData1, ReadData2
);
    logic [31:0] RegFile [0:31];
 
    always_comb begin
        ReadData1 = (rs1 == 5'b0) ? 32'b0 : RegFile[rs1];
        ReadData2 = (rs2 == 5'b0) ? 32'b0 : RegFile[rs2];
    end

    always_ff @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin
            for (int i = 0;i < 32 ;i++ ) begin
                RegFile[i] <= 32'b0;
            end
        end
        else if (RegWrite && (rd != 0)) begin 
            RegFile[rd] <= WriteData;
        end
    end
endmodule
