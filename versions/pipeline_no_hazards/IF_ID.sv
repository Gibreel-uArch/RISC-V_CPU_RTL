module IF_ID (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] instruction_in,
    input  logic [31:0] pc_plus_4_in,
    input  logic [31:0] pc_current_in,
    output logic [31:0] instruction_out,
    output logic [31:0] pc_plus_4_out,
    output logic [31:0] pc_current_out
);

    always_ff @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin
            pc_current_out  <= 32'b0;
            pc_plus_4_out   <= 32'b0;
            instruction_out <= 32'b0;
        end else begin
            pc_current_out  <= pc_current_in;
            pc_plus_4_out   <= pc_plus_4_in;
            instruction_out <= instruction_in;
        end
    end
endmodule
