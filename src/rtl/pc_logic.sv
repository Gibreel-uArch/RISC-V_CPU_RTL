module pc_logic (
    input  logic branch,           // signal from "check branch"
    input  logic [31:0] pc_in,
    output logic [31:0] pc_next,
    input  logic [31:0] imm        // direct immediate form decoder unit
);
    always_comb begin  

        if (branch) begin
            pc_next = pc_in + imm;
        end else begin 
            pc_next = pc_in + 4;
        end
    end
endmodule
