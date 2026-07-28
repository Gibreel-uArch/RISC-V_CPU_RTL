import rv32_types_pkg::*;

module ID_EX (
    input  logic          clk, 
    input  logic          rst_n,
    input  logic [2:0]    func3_in,
    input  logic [6:0]    func7_in,
    input  logic [4:0]    rd_in,
    input  logic [31:0]   pc_plus_4_in,
    input  logic [31:0]   pc_current_in,
    input  logic [31:0]   imm_in,
    input  logic [31:0]   src1_in,
    input  logic [31:0]   src2_in,
    input  ctrl_signals_t ctrl_in,
    output logic [2:0]    func3_out,
    output logic [6:0]    func7_out,
    output logic [4:0]    rd_out,
    output logic [31:0]   pc_current_out,
    output logic [31:0]   pc_plus_4_out,
    output logic [31:0]   src1_out,
    output logic [31:0]   src2_out,
    output logic [31:0]   imm_out,
    output ex_ctrl_t      ex_ctrl_out,
    output mem_wb_ctrl_t  mem_wb_ctrl_out
);

    always_ff @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin
            func3_out       <= 3'b0;
            func7_out       <= 7'b0;
            rd_out          <= 5'b0;
            pc_current_out  <= 32'b0;
            pc_plus_4_out   <= 32'b0;
            src1_out        <= 32'b0;
            src2_out        <= 32'b0;
            imm_out         <= 32'b0;
            ex_ctrl_out     <= '0;
            mem_wb_ctrl_out <= '0;
        end else begin
            func3_out       <= func3_in;
            func7_out       <= func7_in;
            rd_out          <= rd_in;
            pc_current_out  <= pc_current_in;
            pc_plus_4_out   <= pc_plus_4_in;
            src1_out        <= src1_in;
            src2_out        <= src2_in;
            imm_out         <= imm_in;
            ex_ctrl_out     <= ctrl_in.ex;
            mem_wb_ctrl_out.mem <= ctrl_in.mem;
            mem_wb_ctrl_out.wb  <= ctrl_in.wb;
        end
    end

endmodule
