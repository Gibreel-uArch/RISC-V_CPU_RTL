module instruction_fetch (
    input  logic clk, rst_n,
    input  logic branch,
    input  logic zero_flag,
    input  logic [31:0] imm,
    output logic [31:0] instruction         
);
    logic [31:0] address;
    logic [31:0] programe_counter;
    pc pc_inst (
        .clk(clk),
        .rst_n(rst_n),
        .pc_in(programe_counter),
        .pc_out(address)
    );
    pc_logic pc_logic_inst(
        .branch(branch && zero_flag),
        .imm(imm),
        .pc_in(address),
        .pc_next(programe_counter)
    );
    instruction_memory inst_mem(
        .address(address),
        .instruction(instruction)
    );
endmodule
