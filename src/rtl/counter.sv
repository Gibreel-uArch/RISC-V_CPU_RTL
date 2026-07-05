module counter (
    input logic clk,
    input logic rst_n,
    output logic [3:0] count
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) count <= 4'b0;
        else count <= count + 1'b1;
    end
endmodule
