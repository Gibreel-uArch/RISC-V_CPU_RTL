module instruction_fetch (
    input  logic        clk, rst_n,
    input  logic        take_branch,
    input  logic        JumpImm,
    input  logic        JumpReg,
    input  logic [31:0] instruction_address,
    input  logic [31:0] ReadData1,
    input  logic [31:0] imm,
    output logic [31:0] instruction,
    output logic [31:0] pc_plus_4,       
    output logic [31:0] pc_current
);


    pc_unit pc_block (
        .clk(clk),
        .rst_n(rst_n),
        .take_branch(take_branch),
        .JumpImm(JumpImm),
        .JumpReg(JumpReg),
        .ReadData1(ReadData1),
        .imm(imm),
        .instruction_address(instruction_address),
        .pc_current(pc_current),
        .pc_plus_4(pc_plus_4) 
    );

    instruction_memory inst_mem (
        .address(pc_current),
        .instruction(instruction)
    );

endmodule
