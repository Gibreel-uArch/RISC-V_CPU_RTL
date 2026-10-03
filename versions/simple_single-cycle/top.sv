module top (
    input logic clk,
    input logic rst_n
);

    // ==========================================
    // Internal Wires & Signals Declaration
    // ==========================================

    // Data Wires
    logic [31:0] instruction;
    logic [31:0] imm;
    logic [31:0] ReadData1;
    logic [31:0] ReadData2;
    logic [31:0] mux_alu_src_out;
    logic [31:0] alu_result;
    logic        zero_flage;
    logic [31:0] MemoryData;
    logic [31:0] WriteBackData;
    logic [31:0] address;

    // Control Wires
    logic        RegWrite;
    logic        MemRead;
    logic        MemWrite;
    logic        MemtoReg;
    logic        AluSrc;
    logic        branch;
    logic [1:0]  AluOp;
    logic [3:0]  alu_control;

    // Instruction Fields
    logic [6:0]  opcode;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [4:0]  rd;
    logic [2:0]  func3;
    logic [6:0]  func7;

    // ==========================================
    // Instruction Fields Decoding
    // ==========================================
    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign func3  = instruction[14:12];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];
    assign func7  = instruction[31:25];

    // ==========================================
    // Multiplexers Implemented via always_comb
    // ==========================================
    always_comb begin
        // ALU Source Multiplexer (RegData2 vs Immediate)
        mux_alu_src_out = (AluSrc) ? imm : ReadData2;

        // Memory to Register Multiplexer (ALU Result vs Memory Data)
        WriteBackData   = (MemtoReg) ? MemoryData : alu_result;
    end

    // ==========================================
    // Processor Modules Instantiation
    // ==========================================
    instruction_fetch u_instruction_fetch (
        .clk        (clk),
        .rst_n      (rst_n),
        .instruction(instruction),         
        .imm        (imm),
        .branch     (branch),
        .address    (address),
        .zero_flage (zero_flage)
    );

    control_unit u_control_unit (
        .opcode     (opcode),
        .AluOp      (AluOp),      
        .MemRead    (MemRead),
        .MemWrite   (MemWrite),
        .RegWrite   (RegWrite),
        .branch     (branch),
        .AluSrc     (AluSrc),
        .MemtoReg   (MemtoReg)
    );

    alu_control_unit u_alu_control_unit (
        .AluOp      (AluOp),
        .func3      (func3),
        .func7      (func7),
        .alu_control(alu_control)
    );

    immediate_generator u_immediate_generator (
        .instruction(instruction),
        .imm        (imm)  
    );

    memory u_data_memory (
        .clk        (clk),
        .rst_n      (rst_n),
        .MemRead    (MemRead),
        .MemWrite   (MemWrite),
        .WriteData  (ReadData2),
        .address    (alu_result),
        .MemoryData (MemoryData)
    );

    registers_file u_registers_file (
        .clk        (clk),
        .rst_n      (rst_n),
        .RegWrite   (RegWrite),
        .rs1        (rs1),
        .rs2        (rs2),
        .rd         (rd),
        .WriteData  (WriteBackData),            
        .ReadData1  (ReadData1),
        .ReadData2  (ReadData2)
    );

    alu u_alu (
        .alu_control(alu_control),  
        .src1       (ReadData1),            
        .src2       (mux_alu_src_out),            
        .alu_result (alu_result),
        .zero_flage (zero_flage)
    );

    // Simulation Debugging & Monitoring block
    core_monitor u_mon (
        .clk(clk), .rst_n(rst_n),
        .instruction(instruction), .opcode(opcode),
        .rs1(rs1), .rs2(rs2), .rd(rd),
        .ReadData1(ReadData1), .ReadData2(ReadData2), .imm(imm),
        .mux_alu_src_out(mux_alu_src_out), .alu_result(alu_result),
        .MemoryData(MemoryData), .WriteBackData(WriteBackData),
        .alu_control(alu_control),
        .zero_flage(zero_flage), .branch(branch),
        .MemRead(MemRead), .MemWrite(MemWrite), .RegWrite(RegWrite),
        .address(address)
    );

endmodule
