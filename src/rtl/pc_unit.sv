module pc_unit (
    input  logic        clk, 
    input  logic        rst_n,
    input  logic        take_branch,
    input  logic        JumpImm,
    input  logic        JumpReg,
    input  logic [31:0] alu_result,
    input  logic [31:0] imm,
    output logic [31:0] pc_current,   
    output logic [31:0] pc_plus_4     
);

    logic [31:0] pc_next;

    assign pc_plus_4 = pc_current + 32'd4;
    
    always_comb begin
        if (take_branch || JumpImm) begin
            pc_next = pc_current + imm;
        end else if (JumpReg) begin
            pc_next = alu_result;
        end else begin
            pc_next = pc_plus_4;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_current <= 32'b0;
        end else begin
            pc_current <= pc_next;
        end
    end

endmodule
