module instruction_fetch (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        branch,
    input  logic        zero_flage,
    input  logic [31:0] imm,
    output logic [31:0] address,
    output logic [31:0] instruction         
);

    // ==========================================
    // Sub-Modules Instantiation
    // ==========================================
    program_counter pc_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .branch     (branch && zero_flage),
        .imm        (imm),
        .pc_out     (address)
    );

    instruction_memory inst_mem (
        .address    (address),
        .instruction(instruction)
    );

endmodule
