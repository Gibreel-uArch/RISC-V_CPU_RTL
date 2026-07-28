import rv32_types_pkg::*;

module EX_MEM (
    input  logic          clk, 
    input  logic          rst_n,
    input  logic [2:0]    func3_in,
    input  logic [4:0]    rd_in,
    input  logic [31:0]   pc_plus_4_in,
    input  logic [31:0]   alu_result_in,
    input  logic [31:0]   src2_in,
    input  mem_wb_ctrl_t  mem_wb_ctrl_in,
    output logic [2:0]    func3_out,
    output logic [4:0]    rd_out,
    output logic [31:0]   pc_plus_4_out,
    output logic [31:0]   alu_result_out,
    output logic [31:0]   src2_out,
    output mem_ctrl_t     mem_ctrl_out,
    output wb_ctrl_t      wb_ctrl_out
);

    always_ff @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin
            func3_out      <= 3'b0;
            rd_out         <= 5'b0;
            pc_plus_4_out  <= 32'b0;
            alu_result_out <= 32'b0;
            src2_out       <= 32'b0;
            mem_ctrl_out   <= '0;
            wb_ctrl_out    <= '0;
        end else begin
            func3_out      <= func3_in;
            rd_out         <= rd_in;
            pc_plus_4_out  <= pc_plus_4_in;
            alu_result_out <= alu_result_in;
            src2_out       <= src2_in;
            mem_ctrl_out   <= mem_wb_ctrl_in.mem;
            wb_ctrl_out    <= mem_wb_ctrl_in.wb;
        end
    end

endmodule
