module top (
    input  logic        clk,
    input  logic        rst_n,
    output logic        MemWrite,
    output logic [31:0] address,
    output logic [31:0] WriteData
);

    assign address   = alu_result;
    assign WriteData = ReadData2;

    // ==========================================
    // Internal Wires & Signals Declaration
    // ==========================================
    
    // Data Wires
    logic [31:0] instruction;
    logic [31:0] imm;
    logic [31:0] ReadData1;
    logic [31:0] ReadData2;
    logic [31:0] mux_alu_src_out_1;
    logic [31:0] mux_alu_src_out_2;
    logic [31:0] alu_result;
    logic [31:0] MemoryData;
    logic [31:0] WriteBackData;
    logic [31:0] pc_plus_4;
    logic [31:0] pc_current;
    logic [31:0] RegWriteData;
    logic        zero;
    logic        less;
    logic        less_unsigned;
    logic        take_branch;

    // Control Wires
    logic        RegWrite;
    logic        MemRead;
//  logic        MemWrite;
    logic        MemtoReg;
    logic        AluSrc1;
    logic        AluSrc2;
    logic        Branch;
    logic        WriteData1;
    logic        JumpImm;
    logic        JumpReg;
    logic [2:0]  AluOp;
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
        // ALU Source 1 Mux
        mux_alu_src_out_1 = (AluSrc1) ? pc_plus_4 : ReadData1;

        // ALU Source 2 Mux
        mux_alu_src_out_2 = (AluSrc2) ? imm : ReadData2;

        // Memory to Register Mux (WB Stage)
        WriteBackData     = (MemtoReg) ? MemoryData : alu_result;

        // Register Write Data Mux (Link / PC+4 support)
        RegWriteData      = (WriteData1) ? pc_plus_4 : WriteBackData;
    end

    // ==========================================
    // Processor Modules Instantiation
    // ==========================================
    instruction_fetch u_instruction_fetch (
        .clk         (clk),
        .rst_n       (rst_n),
        .instruction (instruction),
        .JumpImm     (JumpImm),
        .JumpReg     (JumpReg),
        .alu_result  (alu_result),
        .imm         (imm),
        .take_branch (take_branch),
        .pc_current  (pc_current),
        .pc_plus_4   (pc_plus_4)
    );

    control_unit u_control_unit (
        .opcode      (opcode),
        .AluOp       (AluOp),      
        .MemRead     (MemRead),
        .MemWrite    (MemWrite),
        .RegWrite    (RegWrite),
        .Branch      (Branch),
        .AluSrc1     (AluSrc1),
        .AluSrc2     (AluSrc2),
        .WriteData   (WriteData1),
        .JumpReg     (JumpReg),
        .JumpImm     (JumpImm),
        .MemtoReg    (MemtoReg)
    );

    alu_control_unit u_alu_control_unit (
        .AluOp       (AluOp),
        .func3       (func3),
        .func7       (func7),
        .alu_control (alu_control)
    );

    immediate_generator u_immediate_generator (
        .instruction (instruction),
        .imm         (imm)  
    );

    branch_unit u_branch_unit (
        .Branch        (Branch),
        .func3         (func3),
        .zero          (zero),
        .less          (less),
        .less_unsigned (less_unsigned),
        .take_branch   (take_branch)
    );

    memory u_data_memory (
        .clk         (clk),
        .func3       (func3),
        .MemRead     (MemRead),
        .MemWrite    (MemWrite),
        .WriteData   (ReadData2),
        .address     (alu_result),
        .MemoryData  (MemoryData)
    );

    registers_file u_registers_file (
        .clk         (clk),
        .rst_n       (rst_n),
        .RegWrite    (RegWrite),
        .rs1         (rs1),
        .rs2         (rs2),
        .rd          (rd),
        .WriteData   (RegWriteData),            
        .ReadData1   (ReadData1),
        .ReadData2   (ReadData2)
    );

    alu u_alu (
        .alu_control   (alu_control),          
        .src1          (mux_alu_src_out_1),            
        .src2          (mux_alu_src_out_2),            
        .alu_result    (alu_result),
        .zero          (zero),
        .less          (less),
        .less_unsigned (less_unsigned)
    );

    // Simulation Debugging & Monitoring block
    core_monitor u_core_monitor (
        .clk, .rst_n,
        // IF
        .instruction, .opcode, .pc_current, .pc_plus_4,
        // ID
        .rs1, .rs2, .rd, .ReadData1, .ReadData2, .imm,
        // EX
        .mux_alu_src_out_1, .mux_alu_src_out_2, .alu_result,
        .alu_control, .zero, .less, .less_unsigned, .take_branch,
        // ME
        .MemoryData, .MemRead, .MemWrite, .address, .WriteData,
        // WB
        .RegWriteData, .RegWrite
    );

endmodule
