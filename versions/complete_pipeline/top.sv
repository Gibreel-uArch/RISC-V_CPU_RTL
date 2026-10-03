/**
 * @file top.sv
 * @brief RISC-V 32-Bit 5-Stage Pipelined Top-Level Architecture
 * @details Integrates the instruction fetch, decode, execute, memory, and writeback stages, 
 *          alongside hazard detection, forwarding units, and inter-stage pipeline registers.
 */

import rv32_types_pkg::*;

module top (
    input  logic clk,
    input  logic rst_n,

    output logic        MemWrite,
    output logic [31:0] address,
    output logic [31:0] WriteData
);
    assign MemWrite  = mem_ctrl.mem.MemWrite;
    assign address   = mem_alu_result;
    assign WriteData = mem_store_data;

    // =========================================================================
    // 1. FETCH STAGE (IF)
    // =========================================================================
    logic [31:0] if_instruction;
    logic [31:0] if_pc_plus_4;
    logic [31:0] if_pc_current;

    // In the ID stage: compute the effective rs1 for the jump target.
    logic [31:0] jump_rs1_data;

    always_comb begin
        case (ForwardJump)
            2'b00  : jump_rs1_data = id_read_data1;       // from register file
            2'b01  : jump_rs1_data = ex_alu_result;       // EX ALU output (combinational bypass)
            2'b10  : jump_rs1_data = mem_memory_data;     // MEM load data
            2'b11  : jump_rs1_data = mem_alu_result;      // EX/MEM ALU result
            default: jump_rs1_data = id_read_data1;
        endcase
    end

    instruction_fetch u_instruction_fetch (
        .clk                 (clk),
        .rst_n               (rst_n),
        .stall_pc            (stall_pc),
        .instruction         (if_instruction),
        .JumpImm             (id_ctrl.id.JumpImm),
        .JumpReg             (id_ctrl.id.JumpReg),
        .JumpReg_addr        (jump_rs1_data),
        .instruction_address (id_pc_current),
        .imm                 (id_imm),
        .take_branch         (id_take_branch),
        .pc_plus_4           (if_pc_plus_4),
        .pc_current          (if_pc_current)
    );

    // -------------------------------------------------------------------------
    // PIPELINE REGISTER: IF / ID
    // -------------------------------------------------------------------------
    logic [31:0] id_instruction;
    logic [31:0] id_pc_plus_4;
    logic [31:0] id_pc_current;

    IF_ID u_IF_ID (
        .clk            (clk),
        .rst_n          (rst_n),
        .stall          (stall),
        .if_id_flush    (if_id_flush),
        .if_instruction (if_instruction),
        .if_pc_plus_4   (if_pc_plus_4),
        .if_pc_current  (if_pc_current),
        .id_instruction (id_instruction),
        .id_pc_plus_4   (id_pc_plus_4),
        .id_pc_current  (id_pc_current)
    );


    // =========================================================================
    // 2. DECODE STAGE (ID)
    // =========================================================================
    logic         [ 6:0] id_opcode;
    logic         [ 4:0] id_rs1, id_rs2, id_rd;
    logic         [ 2:0] id_func3;
    logic         [ 6:0] id_func7;
    logic                id_take_branch;

    logic         [31:0] id_imm;
    logic         [31:0] id_read_data1;
    logic         [31:0] id_read_data2;

    logic                if_id_flush;
    logic                id_ex_flush;
    logic                stall;
    logic                stall_pc;
    logic                stall_branch;

    logic         [ 1:0] ForwardA;
    logic         [ 1:0] ForwardB;
    logic         [ 1:0] ForwardStore;
    logic         [ 1:0] ForwardBranchA;
    logic         [ 1:0] ForwardBranchB;
    logic         [ 1:0] ForwardJump;

    logic         [31:0] branchSrc1;
    logic         [31:0] branchSrc2;
  
    ctrl_signals_t       id_ctrl;

    // Instruction Field Extractions
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
  
    hazard_detection_unit u_hazard_detection_unit (
        .id_rs1       (id_rs1),
        .id_rs2       (id_rs2),
        .ex_rd        (ex_rd),
        .id_ctrl      (id_ctrl),
        .ex_ctrl      (ex_ctrl),
        .take_branch  (id_take_branch),
        .id_ex_flush  (id_ex_flush),
        .if_id_flush  (if_id_flush),
        .stall        (stall),
        .stall_pc     (stall_pc),
        .stall_branch (stall_branch)
    );

    forwarding_unit u_forwarding_unit (
        .ex_rd          (ex_rd),
        .mem_rd         (mem_rd),
        .wb_rd          (wb_rd),
        .ex_rs1         (ex_rs1),
        .ex_rs2         (ex_rs2),
        .id_rs1         (id_rs1),
        .id_rs2         (id_rs2),
        .id_ctrl        (id_ctrl),
        .ex_ctrl        (ex_ctrl),
        .mem_ctrl       (mem_ctrl),
        .wb_ctrl        (wb_ctrl),
        .ForwardA       (ForwardA),
        .ForwardB       (ForwardB),
        .ForwardStore   (ForwardStore),
        .ForwardBranchA (ForwardBranchA),
        .ForwardBranchB (ForwardBranchB),
        .ForwardJump    (ForwardJump)
    );

    immediate_generator u_immediate_generator (
        .instruction (id_instruction),
        .imm         (id_imm)
    );

    registers_file u_registers_file (
        .clk       (clk),
        .rst_n     (rst_n),
        .RegWrite  (wb_ctrl.wb.RegWrite),
        .rs1       (id_rs1),
        .rs2       (id_rs2),
        .rd        (wb_rd),
        .WriteData (wb_reg_write_data),
        .ReadData1 (id_read_data1),
        .ReadData2 (id_read_data2)
    );

    branch_unit u_branch_unit (
        .stall_branch (stall_branch),
        .Branch       (id_ctrl.id.Branch),
        .func3        (id_func3),
        .ReadData1    (branchSrc1),
        .ReadData2    (branchSrc2),
        .take_branch  (id_take_branch)
    );

    // Branch Operand Forwarding Muxes
    always_comb begin
        unique case (ForwardBranchA)
            2'b00   : branchSrc1 = id_read_data1;
            2'b01   : branchSrc1 = ex_alu_result;
            2'b10   : branchSrc1 = mem_memory_data;
            2'b11   : branchSrc1 = mem_alu_result;    
            default : branchSrc1 = id_read_data1;
        endcase
    end

    always_comb begin
        unique case (ForwardBranchB)
            2'b00   : branchSrc2 = id_read_data2;
            2'b01   : branchSrc2 = ex_alu_result;
            2'b10   : branchSrc2 = mem_memory_data;
            2'b11   : branchSrc2 = mem_alu_result;    
            default : branchSrc2 = id_read_data2;
        endcase
    end

    // -------------------------------------------------------------------------
    // PIPELINE REGISTER: ID / EX
    // -------------------------------------------------------------------------
    logic         [31:0] ex_pc_plus_4;
    logic         [31:0] ex_pc_current;
    logic         [31:0] ex_imm;
    logic         [31:0] ex_src1;
    logic         [31:0] ex_src2;
    logic         [ 4:0] ex_rs1;
    logic         [ 4:0] ex_rs2;
    logic         [ 4:0] ex_rd;
    logic         [ 2:0] ex_func3;
    logic         [ 6:0] ex_func7;
    ctrl_signals_t       ex_ctrl;

    ID_EX u_ID_EX (
        .clk            (clk),
        .rst_n          (rst_n),
        .id_ex_flush    (id_ex_flush),
        .id_func3       (id_func3),
        .id_func7       (id_func7),
        .id_rs1         (id_rs1),
        .id_rs2         (id_rs2),
        .id_rd          (id_rd),
        .id_pc_current  (id_pc_current),
        .id_pc_plus_4   (id_pc_plus_4),
        .id_imm         (id_imm),
        .id_src1        (id_read_data1),
        .id_src2        (id_read_data2),
        .id_ctrl        (id_ctrl),

        .ex_func3       (ex_func3),
        .ex_func7       (ex_func7),
        .ex_rs1         (ex_rs1),
        .ex_rs2         (ex_rs2),
        .ex_rd          (ex_rd),
        .ex_pc_current  (ex_pc_current),
        .ex_pc_plus_4   (ex_pc_plus_4),
        .ex_src1        (ex_src1),
        .ex_src2        (ex_src2),
        .ex_imm         (ex_imm),
        .ex_ctrl        (ex_ctrl)
    );


    // =========================================================================
    // 3. EXECUTE STAGE (EX)
    // =========================================================================
    logic [ 3:0] ex_alu_control;
    logic [31:0] ex_mux_alu_src1_out;
    logic [31:0] ex_mux_alu_src2_out;

    logic [31:0] ex_alu_operand_a;
    logic [31:0] ex_alu_operand_b;
    logic [31:0] ex_store_data;
    logic [31:0] ex_alu_result;
    logic        ex_zero, ex_less, ex_less_unsigned;

    alu_control_unit u_alu_control_unit (
        .AluOp       (ex_ctrl.ex.AluOp),
        .func3       (ex_func3),
        .func7       (ex_func7),
        .alu_control (ex_alu_control)
    );

    always_comb begin
        unique case (ex_ctrl.ex.AluSrc1)
            1'b0    : ex_mux_alu_src1_out = ex_src1;
            1'b1    : ex_mux_alu_src1_out = ex_pc_current;
            default : ex_mux_alu_src1_out = ex_src1;
        endcase
    end

    always_comb begin
        unique case (ex_ctrl.ex.AluSrc2)
            1'b0    : ex_mux_alu_src2_out = ex_src2;
            1'b1    : ex_mux_alu_src2_out = ex_imm;
            default : ex_mux_alu_src2_out = ex_src2;
        endcase
    end

    // ForwardA Mux - ALU Operand A
    always_comb begin
        unique case (ForwardA)
            2'b00   : ex_alu_operand_a = ex_mux_alu_src1_out;
            2'b01   : ex_alu_operand_a = mem_alu_result;
            2'b10   : ex_alu_operand_a = wb_reg_write_data;
            2'b11   : ex_alu_operand_a = ex_mux_alu_src1_out;
            default : ex_alu_operand_a = ex_mux_alu_src1_out;
        endcase
    end

    // ForwardB Mux - ALU Operand B
    always_comb begin
        unique case (ForwardB)
            2'b00   : ex_alu_operand_b = ex_mux_alu_src2_out;
            2'b01   : ex_alu_operand_b = mem_alu_result;
            2'b10   : ex_alu_operand_b = wb_reg_write_data;
            2'b11   : ex_alu_operand_b = ex_mux_alu_src2_out;
            default : ex_alu_operand_b = ex_mux_alu_src2_out;
        endcase
    end

    // ForwardStore Mux - Store Data Path
    always_comb begin
        unique case (ForwardStore)
            2'b00   : ex_store_data = ex_src2;
            2'b01   : ex_store_data = mem_alu_result;
            2'b10   : ex_store_data = wb_reg_write_data;
            2'b11   : ex_store_data = ex_src2;
            default : ex_store_data = ex_src2;
        endcase
    end

    alu u_alu (
        .alu_control   (ex_alu_control),
        .src1          (ex_alu_operand_a),
        .src2          (ex_alu_operand_b),
        .alu_result    (ex_alu_result),
        .zero          (ex_zero),
        .less          (ex_less),
        .less_unsigned (ex_less_unsigned)
    );

    // -------------------------------------------------------------------------
    // PIPELINE REGISTER: EX / MEM
    // -------------------------------------------------------------------------
    logic [31:0]     mem_alu_result;
    logic [31:0]     mem_store_data;
    logic [31:0]     mem_pc_plus_4;
    logic [ 4:0]     mem_rd;
    logic [ 2:0]     mem_func3;
    ctrl_signals_t   mem_ctrl;

    EX_MEM u_EX_MEM (
        .clk            (clk),
        .rst_n          (rst_n),
        .ex_func3       (ex_func3),
        .ex_rd          (ex_rd),
        .ex_pc_plus_4   (ex_pc_plus_4),
        .ex_alu_result  (ex_alu_result),
        .ex_store_data  (ex_store_data),
        .ex_ctrl        (ex_ctrl),

        .mem_func3      (mem_func3),
        .mem_rd         (mem_rd),
        .mem_pc_plus_4  (mem_pc_plus_4),
        .mem_alu_result (mem_alu_result),
        .mem_store_data (mem_store_data),
        .mem_ctrl       (mem_ctrl)
    );


    // =========================================================================
    // 4. MEMORY STAGE (MEM)
    // =========================================================================
    logic [31:0] mem_memory_data;

    memory u_data_memory (
        .clk        (clk),
        .func3      (mem_func3),
        .MemRead    (mem_ctrl.mem.MemRead),
        .MemWrite   (mem_ctrl.mem.MemWrite),
        .WriteData  (mem_store_data),
        .address    (mem_alu_result),
        .MemoryData (mem_memory_data)
    );

    // -------------------------------------------------------------------------
    // PIPELINE REGISTER: MEM / WB
    // -------------------------------------------------------------------------
    logic [31:0]     wb_alu_result;
    logic [31:0]     wb_memory_data;
    logic [31:0]     wb_pc_plus_4;
    ctrl_signals_t   wb_ctrl;

    MEM_WB u_MEM_WB (
        .clk             (clk),
        .rst_n           (rst_n),
        .mem_rd          (mem_rd),
        .mem_pc_plus_4   (mem_pc_plus_4),
        .mem_alu_result  (mem_alu_result),
        .mem_memory_data (mem_memory_data),
        .mem_ctrl        (mem_ctrl),

        .wb_rd           (wb_rd),
        .wb_pc_plus_4    (wb_pc_plus_4),
        .wb_alu_result   (wb_alu_result),
        .wb_memory_data  (wb_memory_data),
        .wb_ctrl         (wb_ctrl)
    );


    // =========================================================================
    // 5. WRITE BACK STAGE (WB)
    // =========================================================================
    logic [31:0] wb_writeback_data;
    logic [31:0] wb_reg_write_data;
    logic [ 4:0] wb_rd;

    always_comb begin
        unique case (wb_ctrl.wb.MemtoReg)
            1'b0    : wb_writeback_data = wb_alu_result;
            1'b1    : wb_writeback_data = wb_memory_data;
            default : wb_writeback_data = wb_alu_result;
        endcase
    end

    always_comb begin
        unique case (wb_ctrl.wb.WriteData)
            1'b0    : wb_reg_write_data = wb_writeback_data;
            1'b1    : wb_reg_write_data = wb_pc_plus_4;
            default : wb_reg_write_data = wb_writeback_data;
        endcase
    end

    // =========================================================================
    //  PIPELINE MONITOR (External Module)
    // =========================================================================
    core_monitor u_core_monitor (
        .clk, .rst_n,
        // IF
        .if_pc_current, .if_pc_plus_4, .if_instruction,
        // ID
        .id_instruction, .id_opcode, .id_rs1, .id_rs2, .id_rd,
        .id_read_data1, .id_read_data2, .id_imm, .id_take_branch,
        .branchSrc1, .branchSrc2, .ForwardBranchA, .ForwardBranchB, .id_ctrl,
        // EX
        .ex_pc_current, .ex_rd, .ForwardA, .ForwardB, .ForwardStore,
        .ex_mux_alu_src1_out, .ex_mux_alu_src2_out, .ex_alu_operand_a,
        .ex_alu_operand_b, .ex_store_data, .ex_alu_control,
        .ex_alu_result, .ex_zero, .ex_less, .ex_ctrl,
        // MEM
        .mem_rd, .mem_alu_result, .mem_store_data, .mem_memory_data, .mem_ctrl,
        // WB
        .wb_rd, .wb_alu_result, .wb_memory_data, .wb_reg_write_data, .wb_ctrl,
        // Hazard
        .stall, .if_id_flush, .id_ex_flush, .stall_branch
    );

endmodule
