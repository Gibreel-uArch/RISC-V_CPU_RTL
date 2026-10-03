// ============================================================================
//  top.sv
//  RV32 Pipelined Core - Top Level
// ============================================================================
import rv32_types_pkg::*;

module top (
    input  logic clk,
    input  logic rst_n,

    output logic        MemWrite,
    output logic [31:0] address,
    output logic [31:0] WriteData
);
    assign MemWrite  = mem_ctrl.MemWrite;
    assign address   = mem_alu_result;
    assign WriteData = mem_src2;
    // ========================================================================
    //  1. FETCH STAGE (IF)
    // ========================================================================
    logic [31:0] if_instruction;
    logic [31:0] if_pc_plus_4;
    logic [31:0] if_pc_current;

    instruction_fetch u_instruction_fetch (
        .clk                 (clk),
        .rst_n               (rst_n),
        .instruction         (if_instruction),
        .JumpImm             (id_ctrl.id.JumpImm),
        .JumpReg             (id_ctrl.id.JumpReg),
        .ReadData1           (id_read_data1),
        .instruction_address (id_pc_current),
        .imm                 (id_imm),
        .take_branch         (id_take_branch),
        .pc_plus_4           (if_pc_plus_4),
        .pc_current          (if_pc_current)
    );

    // ------------------------------------------------------------------------
    //  Pipeline Register: IF / ID
    // ------------------------------------------------------------------------
    logic [31:0] id_instruction;
    logic [31:0] id_pc_plus_4;
    logic [31:0] id_pc_current;

    IF_ID u_IF_ID (
        .clk              (clk),
        .rst_n            (rst_n),
        .instruction_in   (if_instruction),
        .pc_plus_4_in     (if_pc_plus_4),
        .pc_current_in    (if_pc_current),
        .instruction_out  (id_instruction),
        .pc_plus_4_out    (id_pc_plus_4),
        .pc_current_out   (id_pc_current)
    );

    // ========================================================================
    //  2. DECODE STAGE (ID)
    // ========================================================================
    logic [6:0]  id_opcode;
    logic [4:0]  id_rs1, id_rs2, id_rd;
    logic [2:0]  id_func3;
    logic [6:0]  id_func7;
    logic        id_take_branch;
    logic [31:0] id_imm;
    logic [31:0] id_read_data1;
    logic [31:0] id_read_data2;

    ctrl_signals_t id_ctrl;

    assign id_opcode = id_instruction[6:0];
    assign id_rd     = id_instruction[11:7];
    assign id_func3  = id_instruction[14:12];
    assign id_rs1    = id_instruction[19:15];
    assign id_rs2    = id_instruction[24:20];
    assign id_func7  = id_instruction[31:25];

    control_unit u_control_unit (
        .opcode (id_opcode),
        .ctrl   (id_ctrl)
    );

    immediate_generator u_immediate_generator (
        .instruction (id_instruction),
        .imm         (id_imm)
    );

    registers_file u_registers_file (
        .clk       (clk),
        .rst_n     (rst_n),
        .RegWrite  (wb_ctrl.RegWrite),
        .rs1       (id_rs1),
        .rs2       (id_rs2),
        .rd        (wb_rd),
        .WriteData (wb_reg_write_data),
        .ReadData1 (id_read_data1),
        .ReadData2 (id_read_data2)
    );

    branch_unit u_branch_unit (
        .Branch      (id_ctrl.id.Branch),
        .func3       (id_func3),
        .ReadData1   (id_read_data1),
        .ReadData2   (id_read_data2),
        .take_branch (id_take_branch)
    );

    // ------------------------------------------------------------------------
    //  Pipeline Register: ID / EX
    // ------------------------------------------------------------------------
    logic [31:0]  ex_pc_plus_4;
    logic [31:0]  ex_pc_current;
    logic [31:0]  ex_imm;
    logic [31:0]  ex_src1;
    logic [31:0]  ex_src2;
    logic [4:0]   ex_rd;
    logic [2:0]   ex_func3;
    logic [6:0]   ex_func7;
    ex_ctrl_t     ex_ctrl;
    mem_wb_ctrl_t ex_mem_wb_ctrl;

    ID_EX u_ID_EX (
        .clk              (clk),
        .rst_n            (rst_n),
        .func3_in         (id_func3),
        .func7_in         (id_func7),
        .rd_in            (id_rd),
        .pc_current_in    (id_pc_current),
        .pc_plus_4_in     (id_pc_plus_4),
        .imm_in           (id_imm),
        .src1_in          (id_read_data1),
        .src2_in          (id_read_data2),
        .ctrl_in          (id_ctrl),
        .func3_out        (ex_func3),
        .func7_out        (ex_func7),
        .rd_out           (ex_rd),
        .pc_current_out   (ex_pc_current),
        .pc_plus_4_out    (ex_pc_plus_4),
        .src1_out         (ex_src1),
        .src2_out         (ex_src2),
        .imm_out          (ex_imm),
        .ex_ctrl_out      (ex_ctrl),
        .mem_wb_ctrl_out  (ex_mem_wb_ctrl)
    );

    // ========================================================================
    //  3. EXECUTE STAGE (EX)
    // ========================================================================
    logic [3:0]  ex_alu_control;
    logic [31:0] ex_mux_alu_src1_out;
    logic [31:0] ex_mux_alu_src2_out;
    logic [31:0] ex_alu_result;
    logic        ex_zero, ex_less, ex_less_unsigned;

    alu_control_unit u_alu_control_unit (
        .AluOp       (ex_ctrl.AluOp),
        .func3       (ex_func3),
        .func7       (ex_func7),
        .alu_control (ex_alu_control)
    );

    // ALU Muxes 
    always_comb begin
        ex_mux_alu_src1_out = ex_ctrl.AluSrc1 ? ex_pc_current : ex_src1;
        ex_mux_alu_src2_out = ex_ctrl.AluSrc2 ? ex_imm         : ex_src2;
    end

    alu u_alu (
        .alu_control   (ex_alu_control),
        .src1          (ex_mux_alu_src1_out),
        .src2          (ex_mux_alu_src2_out),
        .alu_result    (ex_alu_result),
        .zero          (ex_zero),
        .less          (ex_less),
        .less_unsigned (ex_less_unsigned)
    );

    // ------------------------------------------------------------------------
    //  Pipeline Register: EX / MEM
    // ------------------------------------------------------------------------
    logic [31:0] mem_alu_result;
    logic [31:0] mem_src2;
    logic [31:0] mem_pc_plus_4;
    logic [4:0]  mem_rd;
    logic [2:0]  mem_func3;
    mem_ctrl_t   mem_ctrl;
    wb_ctrl_t    mem_wb_ctrl;

    EX_MEM u_EX_MEM (
        .clk             (clk),
        .rst_n           (rst_n),
        .func3_in        (ex_func3),
        .rd_in           (ex_rd),
        .pc_plus_4_in    (ex_pc_plus_4),
        .alu_result_in   (ex_alu_result),
        .src2_in         (ex_src2),
        .mem_wb_ctrl_in  (ex_mem_wb_ctrl),
        .func3_out       (mem_func3),
        .rd_out          (mem_rd),
        .pc_plus_4_out   (mem_pc_plus_4),
        .alu_result_out  (mem_alu_result),
        .src2_out        (mem_src2),
        .mem_ctrl_out    (mem_ctrl),
        .wb_ctrl_out     (mem_wb_ctrl)
    );

    // ========================================================================
    //  4. MEMORY STAGE (MEM)
    // ========================================================================
    logic [31:0] mem_memory_data;

    memory u_data_memory (
        .clk        (clk),
        .func3      (mem_func3),
        .MemRead    (mem_ctrl.MemRead),
        .MemWrite   (mem_ctrl.MemWrite),
        .WriteData  (mem_src2),
        .address    (mem_alu_result),
        .MemoryData (mem_memory_data)
    );

    // ------------------------------------------------------------------------
    //  Pipeline Register: MEM / WB
    // ------------------------------------------------------------------------
    logic [4:0]  wb_rd;
    logic [31:0] wb_alu_result;
    logic [31:0] wb_memory_data;
    logic [31:0] wb_pc_plus_4;
    wb_ctrl_t    wb_ctrl;

    MEM_WB u_MEM_WB (
        .clk             (clk),
        .rst_n           (rst_n),
        .rd_in           (mem_rd),
        .pc_plus_4_in    (mem_pc_plus_4),
        .alu_result_in   (mem_alu_result),
        .memory_data_in  (mem_memory_data),
        .wb_ctrl_in      (mem_wb_ctrl),
        .rd_out          (wb_rd),
        .pc_plus_4_out   (wb_pc_plus_4),
        .alu_result_out  (wb_alu_result),
        .memory_data_out (wb_memory_data),
        .wb_ctrl_out     (wb_ctrl)
    );

    // ========================================================================
    //  5. WRITE BACK STAGE (WB)
    // ========================================================================
    logic [31:0] wb_writeback_data;
    logic [31:0] wb_reg_write_data;

    // Write Back 
    always_comb begin
        wb_writeback_data = wb_ctrl.MemtoReg ? wb_memory_data : wb_alu_result;
        wb_reg_write_data = wb_ctrl.WriteData ? wb_pc_plus_4  : wb_writeback_data;
    end

    // ========================================================================
    //  DEBUG / MONITOR
    // ========================================================================
    core_monitor u_core_monitor (
        .clk, .rst_n,
        // IF
        .if_pc_current, .if_pc_plus_4, .if_instruction,
        // ID
        .id_instruction, .id_opcode, .id_rs1, .id_rs2, .id_rd,
        .id_read_data1, .id_read_data2, .id_imm, .id_take_branch, .id_ctrl,
        // EX
        .ex_pc_current, .ex_pc_plus_4, .ex_rd,
        .ex_mux_alu_src1_out, .ex_mux_alu_src2_out, .ex_alu_control,
        .ex_alu_result, .ex_zero, .ex_less, .ex_less_unsigned,
        // MEM
        .mem_rd, .mem_alu_result, .mem_src2, .mem_memory_data, .mem_ctrl,
        // WB
        .wb_rd, .wb_alu_result, .wb_memory_data, .wb_reg_write_data, .wb_ctrl
    );

endmodule
