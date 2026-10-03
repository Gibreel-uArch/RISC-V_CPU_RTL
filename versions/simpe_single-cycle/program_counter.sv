module program_counter (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        branch,
    input  logic [31:0] imm,
    output logic [31:0] pc_out
);

    // ==========================================
    // Program Counter Synchronous Logic
    // ==========================================
    always_ff @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin
            pc_out <= 32'b0;
        end 
        else if (branch) begin
            pc_out <= pc_out + imm;
        end 
        else begin 
            pc_out <= pc_out + 32'd4;
        end
    end

endmodule

