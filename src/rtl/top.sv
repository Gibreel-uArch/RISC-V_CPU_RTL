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
assign MemWrite  = mem_ctrl.MemWrite;
assign address   = mem_alu_result;
assign WriteData = mem_store_data;
    // =========================================================================
    // 1. FETCH STAGE (IF)
    // =========================================================================
    logic [31:0] if_instruction;
    logic [31:0] if_pc_plus_4;
    logic [31:0] if_pc_current;

    instruction_fetch u_instruction_fetch (
        .clk                 (clk),
        .rst_n               (rst_n),
        .stall_pc            (stall_pc),
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
        .id_ctrl      (id_ctrl),
        .ex_rd        (ex_rd),
        .ex_mem_ctrl  (ex_mem_wb_ctrl),
        .take_branch  (id_take_branch),
        .id_ex_flush  (id_ex_flush),
        .if_id_flush  (if_id_flush),
        .stall        (stall),
        .stall_pc     (stall_pc),
        .stall_branch (stall_branch)
    );

    forwarding_unit u_forwarding_unit (
        .id_rd          (ex_rd),
        .ex_rd          (mem_rd),
        .mem_rd         (wb_rd),
        .id_rs1         (ex_rs1),
        .id_rs2         (ex_rs2),
        .if_rs1         (id_rs1),
        .if_rs2         (id_rs2),
        .if_ctrl        (id_ctrl),
        .id_ctrl        (ex_id_ctrl),
        .ex_wb_ctrl     (mem_wb_ctrl),
        .ex_mem_ctrl    (mem_ctrl),
        .mem_ctrl       (wb_ctrl),
        .ForwardA       (ForwardA),
        .ForwardB       (ForwardB),
        .ForwardStore   (ForwardStore),
        .ForwardBranchA (ForwardBranchA),
        .ForwardBranchB (ForwardBranchB)
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
    ctrl_signals_t       ex_id_ctrl;
    ex_ctrl_t            ex_ctrl;
    mem_wb_ctrl_t        ex_mem_wb_ctrl;

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
        .ex_id_ctrl     (ex_id_ctrl),
        .ex_ctrl        (ex_ctrl),
        .ex_mem_wb_ctrl (ex_mem_wb_ctrl)
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
        .AluOp       (ex_ctrl.AluOp),
        .func3       (ex_func3),
        .func7       (ex_func7),
        .alu_control (ex_alu_control)
    );

    always_comb begin
        unique case (ex_ctrl.AluSrc1)
            1'b0    : ex_mux_alu_src1_out = ex_src1;
            1'b1    : ex_mux_alu_src1_out = ex_pc_current;
            default : ex_mux_alu_src1_out = ex_src1;
        endcase
    end

    always_comb begin
        unique case (ex_ctrl.AluSrc2)
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
    logic [31:0] mem_alu_result;
    logic [31:0] mem_store_data;
    logic [31:0] mem_pc_plus_4;
    logic [ 4:0] mem_rd;
    logic [ 2:0] mem_func3;
    mem_ctrl_t   mem_ctrl;
    wb_ctrl_t    mem_wb_ctrl;

    EX_MEM u_EX_MEM (
        .clk            (clk),
        .rst_n          (rst_n),
        .ex_func3       (ex_func3),
        .ex_rd          (ex_rd),
        .ex_pc_plus_4   (ex_pc_plus_4),
        .ex_alu_result  (ex_alu_result),
        .ex_store_data  (ex_store_data),
        .ex_mem_wb_ctrl (ex_mem_wb_ctrl),

        .mem_func3      (mem_func3),
        .mem_rd         (mem_rd),
        .mem_pc_plus_4  (mem_pc_plus_4),
        .mem_alu_result (mem_alu_result),
        .mem_store_data (mem_store_data),
        .mem_ctrl       (mem_ctrl),
        .mem_wb_ctrl    (mem_wb_ctrl)
    );


    // =========================================================================
    // 4. MEMORY STAGE (MEM)
    // =========================================================================
    logic [31:0] mem_memory_data;

    memory u_data_memory (
        .clk        (clk),
        .func3      (mem_func3),
        .MemRead    (mem_ctrl.MemRead),
        .MemWrite   (mem_ctrl.MemWrite),
        .WriteData  (mem_store_data),
        .address    (mem_alu_result),
        .MemoryData (mem_memory_data)
    );

    // -------------------------------------------------------------------------
    // PIPELINE REGISTER: MEM / WB
    // -------------------------------------------------------------------------
    logic [31:0] wb_alu_result;
    logic [31:0] wb_memory_data;
    logic [31:0] wb_pc_plus_4;
    wb_ctrl_t    wb_ctrl;

    MEM_WB u_MEM_WB (
        .clk             (clk),
        .rst_n           (rst_n),
        .mem_rd          (mem_rd),
        .mem_pc_plus_4   (mem_pc_plus_4),
        .mem_alu_result  (mem_alu_result),
        .mem_memory_data (mem_memory_data),
        .mem_wb_ctrl     (mem_wb_ctrl),

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
        unique case (wb_ctrl.MemtoReg)
            1'b0    : wb_writeback_data = wb_alu_result;
            1'b1    : wb_writeback_data = wb_memory_data;
            default : wb_writeback_data = wb_alu_result;
        endcase
    end

    always_comb begin
        unique case (wb_ctrl.WriteData)
            1'b0    : wb_reg_write_data = wb_writeback_data;
            1'b1    : wb_reg_write_data = wb_pc_plus_4;
            default : wb_reg_write_data = wb_writeback_data;
        endcase
    end

  // =========================================================================
  //  PIPELINE MONITOR & DEBUGGER
  // =========================================================================
    int cycle_count = 0;

  function automatic string get_reg_name(input logic [4:0] reg_addr);
    string names[32] = '{
      "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
      "s0/fp", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
      "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
      "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
    };
    return $sformatf("%s(x%0d)", names[reg_addr], reg_addr);
  endfunction

  always @(posedge clk) begin
    if (!rst_n) begin
      cycle_count <= 0;
    end else begin
      cycle_count <= cycle_count + 1;
      // $display("%h",id_instruction);
      // Header Banner
      $display("\n==================================================================================================");
      $display(" [CYC: %0d]  RV32 PIPELINE EXECUTION TRACE  |  [Stall: %b | Flush_IF: %b | Flush_EX: %b]", 
               cycle_count, stall, if_id_flush, id_ex_flush);
      $display("==================================================================================================");

      // 1. FETCH STAGE
      $display(" [1. IF Stage]  PC Current : %h  |  PC + 4 : %h  |  Instruction : %h", 
               if_pc_current, if_pc_plus_4, if_instruction);

      // 2. DECODE STAGE
      $display(" --------------------------------------------------------------------------------------------------");
      $display(" [2. ID Stage]  Instruction : %h  |  Opcode : %b  |  Imm : %h",
               id_instruction, id_opcode, id_imm);
      $display("                Registers   : RS1=%s (%h) | RS2=%s (%h) | RD=%s",
               get_reg_name(id_rs1), id_read_data1, get_reg_name(id_rs2), id_read_data2, get_reg_name(id_rd));
      $display("                Branch Unit : Branch=%b | TakeBr : %b | JumpI/R=%b/%b | FwdA : %b | FwdB : %b",
               id_ctrl.id.Branch, id_take_branch, id_ctrl.id.JumpImm, id_ctrl.id.JumpReg, ForwardBranchA, ForwardBranchB);
      $display("                Branch Srcs : Src1=%h     | Src2=%h", branchSrc1, branchSrc2);

      // 3. EXECUTE STAGE
      $display(" --------------------------------------------------------------------------------------------------");
      $display(" [3. EX Stage]  PC Current  : %h  |  Dest Reg : %s",
               ex_pc_current, get_reg_name(ex_rd));
      $display("                Usage Flags : UseRs1=%b   | UseRs2=%b",
               ex_id_ctrl.id.UseRs1, ex_id_ctrl.id.UseRs2);
      $display("                Forwarding  : FwdA=%b (Val: %h)  --> ALU In1: %h", 
               ForwardA, ex_mux_alu_src1_out, ex_alu_operand_a);
      $display("                Forwarding  : FwdB=%b (Val: %h)  --> ALU In2: %h", 
               ForwardB, ex_mux_alu_src2_out, ex_alu_operand_b);
      $display("                Store Fwd   : FwdS=%b   | Store Data : %h", 
               ForwardStore, ex_store_data);
      $display("                ALU Unit    : Ctrl=%b   | Result     : %h  | Zero=%b | Less=%b", 
               ex_alu_control, ex_alu_result, ex_zero, ex_less);

      // 4. MEMORY STAGE
      $display(" --------------------------------------------------------------------------------------------------");
      $display(" [4. MEM Stage] ALU Result  : %h  |  Store Data : %h  |  Dest Reg : %s",
               mem_alu_result, mem_store_data, get_reg_name(mem_rd));
      $display("                Mem Action  : Read=%b     | Write=%b      | Data Out : %h",
               mem_ctrl.MemRead, mem_ctrl.MemWrite, mem_memory_data);

      // 5. WRITE BACK STAGE
      $display(" --------------------------------------------------------------------------------------------------");
      $display(" [5. WB Stage]  ALU Result  : %h  |  Mem Data   : %h  |  Final WB : %h",
               wb_alu_result, wb_memory_data, wb_reg_write_data);
      $display("                Control     : RegWrite=%b | Dest Reg  : %s",
               wb_ctrl.RegWrite, get_reg_name(wb_rd));

      $display("==================================================================================================\n");
     end
  end
endmodule
