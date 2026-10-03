module branch_unit (
    input  logic       Branch,
    input  logic [2:0] func3,
    input  logic       zero,
    input  logic       less,
    input  logic       less_unsigned,
    output logic       take_branch
);

    // ==========================================
    // Internal Wires Declaration
    // ==========================================
    logic sub_cond;

    // ==========================================
    // Branch Condition Selection Logic
    // ==========================================
    always_comb begin
        case (func3[2:1])
            2'b00   : sub_cond = zero;
            2'b10   : sub_cond = less;
            2'b11   : sub_cond = less_unsigned;
            default : sub_cond = 1'b0;
        endcase
    end

    // ==========================================
    // Branch Decision Assignment (Inverted via func3[0] for BNE/BGE/BGEU)
    // ==========================================
    assign take_branch = Branch & (sub_cond ^ func3[0]);

endmodule
