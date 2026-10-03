module core_monitor (
    input logic        clk,
    input logic        rst_n,
    input logic [31:0] instruction,
    input logic [6:0]  opcode,
    input logic [4:0]  rs1, rs2, rd,
    input logic [31:0] ReadData1, ReadData2, imm,
    input logic [31:0] mux_alu_src_out, alu_result,
    input logic [31:0] MemoryData, WriteBackData,
    input logic [3:0]  alu_control,
    input logic        zero_flage, branch,
    input logic        MemRead, MemWrite, RegWrite,
    input logic [31:0] address
);
    int cycle_count = 0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            $display("========== [SIM_CYCLE : %0d] ==========", cycle_count);
            $display("  [IF] Instruction : 0x%08h | Opcode: %07b | PC: 0x%h | rd: %02d",
                     instruction, opcode, address, rd);
            $display("  [ID] rs1(%02d)=0x%08h | rs2(%02d)=0x%08h | Imm=0x%08h",
                     rs1, ReadData1, rs2, ReadData2, imm);
            $display("  [EX] Src1=0x%08h | Src2=0x%08h | Ctrl=%04b",
                     ReadData1, mux_alu_src_out, alu_control);
            $display("       ALU=0x%08h | Zero=%b | BranchTaken=%b",
                     alu_result, zero_flage, (branch && zero_flage));
            $display("  [ME] MemRead=0x%08h | WriteData=0x%08h | R/W=%b/%b",
                     MemoryData, ReadData2, MemRead, MemWrite);
            $display("  [WB] WBData=0x%08h | RegWrite=%b\n", WriteBackData, RegWrite);
        end
    end
endmodule
