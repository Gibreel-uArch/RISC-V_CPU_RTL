module single_cycle (
   input logic clk,rst_n
);

//////// data wires ////////
    logic [31:0] instruction;
    logic [31:0] imm;
    logic [31:0] ReadData1;
    logic [31:0] ReadData2;
    logic [31:0] mux_alu_src_out;
    logic [31:0] alu_result;
    logic        zero_flag;
    logic [31:0] MemoryData;
    logic [31:0] WriteBackData;

////////  control wires ///// 
    logic        RegWrite;
    logic        MemRead;
    logic        MemWrite;
    logic        MemtoReg;
    logic        AluSrc;
    logic        branch;
    logic [1:0]  AluOp;
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
    .imm(imm),
    .branch(branch),
    .zero_flag(zero_flag)
);

control_unit u_control_unit (
    .opcode(opcode),
    .AluOp(AluOp),      
    .MemRead(MemRead),
    .MemWrite(MemWrite),
    .RegWrite(RegWrite),
    .branch(branch),
    .AluSrc(AluSrc),
    .MemtoReg(MemtoReg)
);

alu_control_unit u_alu_control_unit (
    .AluOp(AluOp),
    .func3(func3),
    .func7(func7),
    .alu_control(alu_control)
);

imm_gen u_imm_gen (
    .instruction(instruction),
    .imm(imm) 
);

memory u_data_memory (
    .clk(clk),
    .rst_n(rst_n),
    .MemRead(MemRead),
    .MemWrite(MemWrite),
    .WriteData(ReadData2),
    .address(alu_result),
    .MemoryData(MemoryData)
);

multiplexer u_mux_alu_src (
    .sel(AluSrc), 
    .in0(ReadData2),
    .in1(imm),
    .out(mux_alu_src_out)
);

multiplexer u_mux_mem_to_reg (
    .sel(MemtoReg), 
    .in0(alu_result),
    .in1(MemoryData),
    .out(WriteBackData)
);

registers_file u_registers_file (
    .clk(clk),
    .rst_n(rst_n),
    .RegWrite(RegWrite),
    .rs1(rs1),
    .rs2(rs2),
    .rd(rd),
    .WriteData(WriteBackData),           
    .ReadData1(ReadData1),
    .ReadData2(ReadData2)
);

alu u_alu (
    .alu_control(alu_control),  
    .src1(ReadData1),          
    .src2(mux_alu_src_out),           
    .alu_result(alu_result),
    .zero_flag(zero_flag)
);
// always @(posedge clk) begin
//     $display("------------------------------------------------------------------------------------------------------------------------");
//     $display("PC_Instr: %h | Opcode: %b | rs1: %d | rs2: %d | rd: %d", instruction, opcode, rs1, rs2, rd);
//     $display("------------------------------------------------------------------------------------------------------------------------");
//     $display("DATA PATH:  ReadData1: %h | ReadData2: %h | Imm: %h | Mux_ALU_Src: %h", ReadData1, ReadData2, imm, mux_alu_src_out);
//     $display("ALU & MEM:  ALU_Out: %h | Zero: %b | MemData: %h | WB_Data: %h", alu_result, zero_flag, MemoryData, WriteBackData);
//     $display("CONTROLS:  Branch: %b | AluSrc: %b | AluOp: %b | AluCtrl: %b | MemRead: %b | MemWrite: %b | MemtoReg: %b | RegWrite: %b", 
//               branch, AluSrc, AluOp, alu_control, MemRead, MemWrite, MemtoReg, RegWrite);
//     $display("------------------------------------------------------------------------------------------------------------------------\n");
// end
endmodule
