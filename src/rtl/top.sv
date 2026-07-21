module top (
   input logic clk,rst_n
);

//////// data wires ////////
    logic [31:0] instruction /*verilator public*/;
    logic [31:0] imm;
    logic [31:0] ReadData1;
    logic [31:0] ReadData2;
    logic [31:0] mux_alu_src_out_1;
    logic [31:0] mux_alu_src_out_2;
    logic [31:0] alu_result  /*verilator public*/;
    logic [31:0] MemoryData;
    logic [31:0] WriteBackData;
    logic [31:0] pc_plus_4;
    logic [31:0] RegWriteData;
    logic        zero;
    logic        less;
    logic        less_unsigned;
    logic        take_branch;

////////  control wires ///// 
    logic        RegWrite;
    logic        MemRead;
    logic        MemWrite;
    logic        MemtoReg;
    logic        AluSrc1;
    logic        AluSrc2;
    logic        Branch;
    logic        WriteData;
    logic        JumpImm;
    logic        JumpReg;
    logic [2:0]  AluOp;
    logic [3:0]  alu_control;
    
//////// instruction ////////
    logic [6:0]  opcode;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [4:0]  rd;
    logic [2:0]  func3;
    logic [6:0]  func7;

    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign func3  = instruction[14:12];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];
    assign func7  = instruction[31:25];


instruction_fetch u_instruction_fetch (
    .clk(clk),
    .rst_n(rst_n),
    .instruction(instruction),
    .JumpImm(JumpImm),
    .JumpReg(JumpReg),
    .alu_result(alu_result),
    .imm(imm),
    .take_branch(take_branch),
    .pc_plus_4(pc_plus_4)
);

control_unit u_control_unit (
    .opcode(opcode),
    .AluOp(AluOp),      
    .MemRead(MemRead),
    .MemWrite(MemWrite),
    .RegWrite(RegWrite),
    .Branch(Branch),
    .AluSrc1(AluSrc1),
    .AluSrc2(AluSrc2),
    .WriteData(WriteData),
    .JumpReg(JumpReg),
    .JumpImm(JumpImm),
    .MemtoReg(MemtoReg)
);

alu_control_unit u_alu_control_unit (
    .AluOp(AluOp),
    .func3(func3),
    .func7(func7),
    .alu_control(alu_control)
);

immediate_generator u_immediate_generator (
    .instruction(instruction),
    .imm(imm) 
);

branch_unit u_branch_unit(
    .Branch(Branch),
    .func3(func3),
    .zero(zero),
    .less(less),
    .less_unsigned(less_unsigned),
    .take_branch(take_branch)
);

memory u_data_memory (
    .clk(clk),
    .MemRead(MemRead),
    .MemWrite(MemWrite),
    .WriteData(ReadData2),
    .address(alu_result),
    .MemoryData(MemoryData)
);

registers_file u_registers_file (
    .clk(clk),
    .rst_n(rst_n),
    .RegWrite(RegWrite),
    .rs1(rs1),
    .rs2(rs2),
    .rd(rd),
    .WriteData(RegWriteData),           
    .ReadData1(ReadData1),
    .ReadData2(ReadData2)
);

alu u_alu (
    .alu_control(alu_control),  
    .src1(mux_alu_src_out_1),          
    .src2(mux_alu_src_out_2),           
    .alu_result(alu_result),
    .zero(zero),
    .less(less),
    .less_unsigned(less_unsigned)
);

multiplexer u_mux_alu_src_1 (
    .sel(AluSrc1), 
    .in0(ReadData1),
    .in1(pc_plus_4),
    .out(mux_alu_src_out_1)
);

multiplexer u_mux_alu_src_2 (
    .sel(AluSrc2), 
    .in0(ReadData2),
    .in1(imm),
    .out(mux_alu_src_out_2)
);

multiplexer u_mux_mem_to_reg (
    .sel(MemtoReg), 
    .in0(alu_result),
    .in1(MemoryData),
    .out(WriteBackData)
);

multiplexer u_mux_rd_src (
    .sel(WriteData), 
    .in0(WriteBackData),
    .in1(pc_plus_4),
    .out(RegWriteData)
);

// always @(posedge clk) begin
//     $display("------------------------------------------------------------------------------------------------------------------------");
//     $display("PC_Instr: %h | Opcode: %b | rs1: %d | rs2: %d | rd: %d", instruction, opcode, rs1, rs2, rd);
//     $display("------------------------------------------------------------------------------------------------------------------------");
//     $display("DATA PATH:  ReadData1: %h | ReadData2: %h | Imm: %h | Mux_ALU_Src1: %h | Mux_ALU_Src2: %h", ReadData1, ReadData2, imm, mux_alu_src_out_1, mux_alu_src_out_2);
//     $display("ALU & MEM:  ALU_Out: %h | MemData: %h | WB_Data: %h", alu_result, MemoryData, WriteBackData);
//     $display("CONTROLS:  Branch: %b | AluSrc1: %b | AluSrc2: %b | AluOp: %b | AluCtrl: %b | MemRead: %b | MemWrite: %b | MemtoReg: %b | RegWrite: %b", 
//               Branch, AluSrc1, AluSrc2, AluOp, alu_control, MemRead, MemWrite, MemtoReg, RegWrite);
//     $display("------------------------------------------------------------------------------------------------------------------------\n");
// end
always @(posedge clk) begin
    $display("--- [Cycle Debug] ---");
    $display("INST  : %h | Opcode: %b | rs1: %2d (val: %h) | rs2: %2d (val: %h) | rd: %2d", 
             instruction, opcode, rs1, ReadData1, rs2, ReadData2, rd);
    $display("ALU   : Src1: %h | Src2: %h | Result: %h | Control: %b", 
             mux_alu_src_out_1, mux_alu_src_out_2, alu_result, alu_control);
    $display("MEM/WB: MemData: %h | WriteBackData: %h | RegWrite: %b", 
             MemoryData, RegWriteData, RegWrite);
    $display("BRANCH: Branch_En: %b | Take_Branch: %b | JumpImm/Reg: %b/%b", 
             Branch, take_branch, JumpImm, JumpReg);
    $display("--------------------------------------------------------------------------------\n");
end
endmodule
