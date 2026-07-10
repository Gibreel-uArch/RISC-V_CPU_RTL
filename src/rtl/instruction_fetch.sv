module instruction_fetch (
    input  logic clk, rst_n,
    output logic [31:0] instruction,         
    input  logic [31:0] imm,
    input  logic branch
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
        .branch(branch),
        .imm(imm),
        .pc_in(address),
        .pc_next(programe_counter)
    );
    instruction_memory inst_mem(
        .address(address),
        .instruction(instruction)
    );
endmodule
