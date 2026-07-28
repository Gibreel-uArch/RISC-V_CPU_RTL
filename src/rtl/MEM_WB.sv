module MEM_WB (
    input  logic          clk, 
    input  logic          rst_n,
    input  logic [4:0]    rd_in,
    input  logic [31:0]   pc_plus_4_in,
    input  logic [31:0]   alu_result_in,
    input  logic [31:0]   memort_data_in,
    input  wb_ctrl_t      wb_ctrl_in,
    output logic [4:0]    rd_out,
    output logic [31:0]   pc_plus_4_out,
    output logic [31:0]   alu_result_out,
    output logic [31:0]   memort_data_out,
    output wb_ctrl_t      wb_ctrl_out
);

    always_ff @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin
            rd_out          <= 5'b0;
            pc_plus_4_out   <= 32'b0;
            alu_result_out  <= 32'b0;
            memort_data_out <= 32'b0;
            wb_ctrl_out     <= '0; 
        end else begin
            rd_out          <= rd_in;
            pc_plus_4_out   <= pc_plus_4_in;
            alu_result_out  <= alu_result_in;
            memort_data_out <= memort_data_in;
            wb_ctrl_out     <= wb_ctrl_in; 
        end
    end

endmodule
