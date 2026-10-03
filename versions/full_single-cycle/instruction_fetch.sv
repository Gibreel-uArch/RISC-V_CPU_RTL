module instruction_fetch (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        take_branch,
    input  logic        JumpImm,
    input  logic        JumpReg,
    input  logic [31:0] alu_result,
    input  logic [31:0] imm,
    output logic [31:0] instruction,
    output logic [31:0] pc_current,
    output logic [31:0] pc_plus_4       
);

    // ==========================================
    // Sub-modules Instantiation
    // ==========================================
   logic [31:0] current_address;
   assign pc_current = current_address;

    pc_unit pc_block (
        .clk         (clk),
        .rst_n       (rst_n),
        .take_branch (take_branch),
        .JumpImm     (JumpImm),
        .JumpReg     (JumpReg),
        .alu_result  (alu_result),
        .imm         (imm),
        .pc_current  (current_address),
        .pc_plus_4   (pc_plus_4) 
    );

    instruction_memory inst_mem (
        .address     (current_address),
        .instruction (instruction)
    );

endmodule
