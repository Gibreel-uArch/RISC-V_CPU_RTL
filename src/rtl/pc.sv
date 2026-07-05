module pc(
    input  logic clk,
    input  logic rst_n,
    output logic [15:0] count
    );

    always_ff@(posedge clk or negedge rst_n) begin 
        if(!rst_n) begin
            count <= 16'h0000 ;
        end else begin
            count <= count + 1'b1 ;
        end
    end
endmodule 

