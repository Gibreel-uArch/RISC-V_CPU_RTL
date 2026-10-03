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
    input  logic report_trigger,

    // test flags
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
    logic [31:0] jump_rs1_data;
    logic        icache_miss;

    always_comb begin
        unique case (ForwardJump)
            3'b000  : jump_rs1_data = id_read_data1;
            3'b001  : jump_rs1_data = ex_csr_rdata;
            3'b010  : jump_rs1_data = ex_alu_result;
            3'b011  : jump_rs1_data = mem_memory_data;
            3'b100  : jump_rs1_data = mem_csr_rdata;
            3'b101  : jump_rs1_data = mem_alu_result;
            default : jump_rs1_data = id_read_data2;
        endcase
    end

    instruction_fetch u_instruction_fetch (
        .clk                 (clk),
        .rst_n               (rst_n),
        .pc_stall            (pc_stall),
        .trap_jump           (trap_jump),
        .mret_jump           (mret_jump),
        .icache_miss         (icache_miss),
        .instruction         (if_instruction),
        .trap_next_pc        (trap_next_pc),
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
        .clk                (clk),
        .rst_n              (rst_n),
        .if_id_stall        (if_id_stall),
        .if_id_branch_flush (hazard_if_id_flush),
        .if_id_trap_flush   (trap_if_id_flush),

        .if_instruction     (if_instruction),
        .if_pc_plus_4       (if_pc_plus_4),
        .if_pc_current      (if_pc_current),

        .id_instruction     (id_instruction),
        .id_pc_plus_4       (id_pc_plus_4),
        .id_pc_current      (id_pc_current) 
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

    logic                hazard_if_id_flush;
    logic                hazard_id_ex_flush;
    logic                if_id_stall;
    logic                id_ex_stall;
    logic                ex_mem_stall;
    logic                mem_wb_stall;
    logic                pc_stall;
    logic                branch_stall;

    logic         [ 1:0] ForwardA;
    logic         [ 1:0] ForwardB;
    logic         [ 1:0] ForwardStore;
    logic         [ 2:0] ForwardBranchA;
    logic         [ 2:0] ForwardBranchB;
    logic         [ 2:0] ForwardJump;
    logic         [ 1:0] ForwardCSR;

    logic         [31:0] branchSrc1;
    logic         [31:0] branchSrc2;
  
    ctrl_signals_t       id_ctrl;
    excep_signals_t      id_excep;

    // Instruction Field Extractions
    assign id_opcode = id_instruction[6:0];
    assign id_rd     = id_instruction[11:7];
    assign id_func3  = id_instruction[14:12];
    assign id_rs1    = id_instruction[19:15];
    assign id_rs2    = id_instruction[24:20];
    assign id_func7  = id_instruction[31:25];

    control_unit u_control_unit (
        .func3  (id_func3),
        .imm    (id_imm),
        .opcode (id_opcode),
        .ctrl   (id_ctrl),
        .excep  (id_excep)
    );
  
    hazard_detection_unit u_hazard_detection_unit (
        .id_rs1       (id_rs1),
        .id_rs2       (id_rs2),
        .ex_rd        (ex_rd),
        .id_ctrl      (id_ctrl),
        .ex_ctrl      (ex_ctrl),
        .take_branch  (id_take_branch),
        .icache_miss  (icache_miss),
        .dcache_miss  (dcache_miss),
        .id_ex_flush  (hazard_id_ex_flush),
        .if_id_branch_flush  (hazard_if_id_flush),
        .if_id_stall  (if_id_stall),
        .id_ex_stall  (id_ex_stall),
        .ex_mem_stall (ex_mem_stall),
        .mem_wb_stall (mem_wb_stall),
        .pc_stall     (pc_stall),
        .branch_stall (branch_stall)
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
        .ForwardJump    (ForwardJump),
        .ForwardCSR     (ForwardCSR)
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
        .branch_stall (branch_stall),
        .Branch       (id_ctrl.id.Branch),
        .func3        (id_func3),
        .ReadData1    (branchSrc1),
        .ReadData2    (branchSrc2),
        .take_branch  (id_take_branch)
    );

    // Branch Operand Forwarding Muxes
    always_comb begin
        unique case (ForwardBranchA)
            3'b000  : branchSrc1 = id_read_data1;
            3'b001  : branchSrc1 = ex_csr_rdata;
            3'b010  : branchSrc1 = ex_alu_result;
            3'b011  : branchSrc1 = mem_memory_data;
            3'b100  : branchSrc1 = mem_csr_rdata;
            3'b101  : branchSrc1 = mem_alu_result;
            default : branchSrc1 = id_read_data1;
        endcase
    end

    always_comb begin
        unique case (ForwardBranchB)
            3'b000  : branchSrc2 = id_read_data2;
            3'b001  : branchSrc2 = ex_csr_rdata;
            3'b010  : branchSrc2 = ex_alu_result;
            3'b011  : branchSrc2 = mem_memory_data;
            3'b100  : branchSrc2 = mem_csr_rdata;
            3'b101  : branchSrc2 = mem_alu_result;
            default : branchSrc2 = id_read_data2;
        endcase
    end

    // -------------------------------------------------------------------------
    // PIPELINE REGISTER: ID / EX
    // -------------------------------------------------------------------------
    logic         [31:0] ex_pc_plus_4;
    logic         [31:0] ex_pc_current;
    logic         [31:0] ex_imm;
    logic         [31:0] ex_read_data1;
    logic         [31:0] ex_read_data2;
    logic         [ 4:0] ex_rs1;
    logic         [ 4:0] ex_rs2;
    logic         [ 4:0] ex_rd;
    logic         [ 2:0] ex_func3;
    logic         [ 6:0] ex_func7;

    logic                id_ex_flush;

    assign id_ex_flush = hazard_id_ex_flush || trap_id_ex_flush;

    ctrl_signals_t       ex_ctrl;
    excep_signals_t      ex_excep;


    ID_EX u_ID_EX (
        .clk            (clk),
        .rst_n          (rst_n),
        .id_ex_flush    (id_ex_flush),
        .id_ex_stall    (id_ex_stall),

        .id_func3       (id_func3),
        .id_func7       (id_func7),
        .id_rs1         (id_rs1),
        .id_rs2         (id_rs2),
        .id_rd          (id_rd),
        .id_pc_current  (id_pc_current),
        .id_pc_plus_4   (id_pc_plus_4),
        .id_imm         (id_imm),
        .id_read_data1  (id_read_data1),
        .id_read_data2  (id_read_data2),
        .id_ctrl        (id_ctrl),
        .id_excep       (id_excep),

        .ex_func3       (ex_func3),
        .ex_func7       (ex_func7),
        .ex_rs1         (ex_rs1),
        .ex_rs2         (ex_rs2),
        .ex_rd          (ex_rd),
        .ex_pc_current  (ex_pc_current),
        .ex_pc_plus_4   (ex_pc_plus_4),
        .ex_read_data1  (ex_read_data1),
        .ex_read_data2  (ex_read_data2),
        .ex_imm         (ex_imm),
        .ex_ctrl        (ex_ctrl),
        .ex_excep       (ex_excep)
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

    // ============================================
    // Trap Controller Signals
    // ============================================
    logic        trap_taken;
    logic        mret_taken;
    logic        trap_jump;
    logic        mret_jump;

    logic        trap_if_id_flush;
    logic        trap_id_ex_flush;
    logic        trap_ex_mem_flush;

    logic [31:0] trap_pc;
    logic [31:0] trap_cause;
    logic [31:0] trap_next_pc;

    // ============================================
    // CSR Signals
    // ============================================
    logic [31:0] trap_vector;
    logic [31:0] mepc_value;
    logic [31:0] ex_csr_rdata;
    logic [31:0] csr_wdata;
    logic [11:0] csr_addr;

    logic [31:0] ex_mux_csr_wdata;
    logic [31:0] ex_csr_wdata_imm;

    // CSR write-back signals from trap controller
    logic        trap_csr_mepc_write;
    logic [31:0] trap_csr_mepc_next;
    logic        trap_csr_mcause_write;
    logic [31:0] trap_csr_mcause_next;
    logic        trap_csr_mstatus_write;
    logic [31:0] trap_csr_mstatus_next;

    // Interrupt signals
    logic        timer_interrupt;

    // mstatus/mie values for trap controller
    logic [31:0] mstatus_value;
    logic [31:0] mie_value;
    logic [31:0] mip_value;

    // ============================================
    // CSR Immediate Value
    // ============================================
    assign ex_csr_wdata_imm = {27'b0, ex_rs1};
    assign csr_addr         = ex_imm[11:0];

    // ============================================
    // CSR Registers Module
    // ============================================
    cs_registers u_cs_registers (
        .clk          (clk),
        .rst_n        (rst_n),
        
        // Regular CSR access from pipeline
        .csr_write_en (ex_ctrl.csr.Write),
        .csr_set_en   (ex_ctrl.csr.Set),
        .csr_clear_en (ex_ctrl.csr.Clear),
        .csr_addr     (csr_addr),
        .csr_wdata    (csr_wdata),
        .csr_rdata    (ex_csr_rdata),
        
        // Trap controller interface
        .trap_mepc_write    (trap_csr_mepc_write),
        .trap_mepc_next     (trap_csr_mepc_next),
        .trap_mcause_write  (trap_csr_mcause_write),
        .trap_mcause_next   (trap_csr_mcause_next),
        .trap_mstatus_write (trap_csr_mstatus_write),
        .trap_mstatus_next  (trap_csr_mstatus_next),
        
        // Interrupt pending inputs
        .timer_interrupt_pending    (timer_interrupt),
        
        // CSR outputs
        .mstatus_value  (mstatus_value),
        .mie_value      (mie_value),
        .mip_value      (mip_value),
        .mtvec_value    (trap_vector),
        .mepc_value     (mepc_value),
        .mcause_value   (),  // Can be connected if needed
        .mtval_value    (),  // Can be connected if needed
        .mscratch_value ()   // Can be connected if needed
    );

    // ============================================
    // Trap Controller Module
    // ============================================
    trap_controller u_trap_controller (
        .clk          (clk),
        .rst_n        (rst_n),
        
        // Exception signals
        .ex_ecall     (ex_excep.ecall_inst),
        .ex_ebreak    (ex_excep.ebreak_inst),
        .ex_illegal   (ex_excep.illegal_inst),
        .ex_mret      (ex_excep.mret_inst),
        
        // Interrupt signals
        .timer_interrupt    (timer_interrupt),
        
        // CSR values from cs_registers
        .mstatus_value  (mstatus_value),
        .mie_value      (mie_value),
        .mip_value      (mip_value),
        .trap_vector    (trap_vector),
        .mepc_value     (mepc_value),
        
        // Pipeline control
        .inst_pc        (ex_pc_current),
        
        // CSR write-back
        .csr_mepc_write    (trap_csr_mepc_write),
        .csr_mepc_next     (trap_csr_mepc_next),
        .csr_mcause_write  (trap_csr_mcause_write),
        .csr_mcause_next   (trap_csr_mcause_next),
        .csr_mstatus_write (trap_csr_mstatus_write),
        .csr_mstatus_next  (trap_csr_mstatus_next),
        
        // Trap control outputs
        .trap_taken    (trap_taken),
        .mret_taken    (mret_taken),
        .trap_jump     (trap_jump),
        .mret_jump     (mret_jump),
        .trap_pc       (trap_pc),
        .trap_cause    (trap_cause),
        .trap_next_pc  (trap_next_pc),
        
        // Pipeline flush signals
        .if_id_flush   (trap_if_id_flush),
        .id_ex_flush   (trap_id_ex_flush),
        .ex_mem_flush  (trap_ex_mem_flush)
    );  

    always_comb begin
        unique case (ex_ctrl.id.UseRs1)
            1'b0    : ex_mux_csr_wdata = ex_csr_wdata_imm;
            1'b1    : ex_mux_csr_wdata = ex_read_data1;
            default : ex_mux_csr_wdata = ex_read_data1;
        endcase
    end

     always_comb begin
        unique case (ForwardCSR)
            2'b00   : csr_wdata = ex_mux_csr_wdata;
            2'b01   : csr_wdata = mem_csr_rdata;
            2'b10   : csr_wdata = mem_alu_result;
            2'b11   : csr_wdata = wb_reg_write_data;
            default : csr_wdata = ex_mux_csr_wdata;
        endcase
    end
    
    alu_control_unit u_alu_control_unit (
        .AluOp       (ex_ctrl.ex.AluOp),
        .func3       (ex_func3),
        .func7       (ex_func7),
        .alu_control (ex_alu_control)
    );

    always_comb begin
        unique case (ex_ctrl.ex.AluSrc1)
            1'b0    : ex_mux_alu_src1_out = ex_read_data1;
            1'b1    : ex_mux_alu_src1_out = ex_pc_current;
            default : ex_mux_alu_src1_out = ex_read_data1;
        endcase
    end

    always_comb begin
        unique case (ex_ctrl.ex.AluSrc2)
            1'b0    : ex_mux_alu_src2_out = ex_read_data2;
            1'b1    : ex_mux_alu_src2_out = ex_imm;
            default : ex_mux_alu_src2_out = ex_read_data2;
        endcase
    end

    // ForwardA Mux - ALU Operand A
    always_comb begin
        unique case (ForwardA)
            2'b00   : ex_alu_operand_a = ex_mux_alu_src1_out;
            2'b01   : ex_alu_operand_a = mem_csr_rdata;
            2'b10   : ex_alu_operand_a = mem_alu_result;
            2'b11   : ex_alu_operand_a = wb_reg_write_data;
            default : ex_alu_operand_a = ex_mux_alu_src1_out;
        endcase
    end

    // ForwardB Mux - ALU Operand B
    always_comb begin
        unique case (ForwardB)
            2'b00   : ex_alu_operand_b = ex_mux_alu_src2_out;
            2'b01   : ex_alu_operand_b = mem_csr_rdata;
            2'b10   : ex_alu_operand_b = mem_alu_result;
            2'b11   : ex_alu_operand_b = wb_reg_write_data;
            default : ex_alu_operand_b = ex_mux_alu_src2_out;
        endcase
    end

    // ForwardStore Mux - Store Data Path
    always_comb begin
        unique case (ForwardStore)
            2'b00   : ex_store_data = ex_read_data2;
            2'b01   : ex_store_data = mem_csr_rdata;
            2'b10   : ex_store_data = mem_alu_result;
            2'b11   : ex_store_data = wb_reg_write_data;
            default : ex_store_data = ex_read_data2;
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
    logic [31:0]     mem_csr_rdata;
    logic [ 4:0]     mem_rd;
    logic [ 2:0]     mem_func3;
    logic            ex_mem_flush;

    assign ex_mem_flush = trap_ex_mem_flush;

    ctrl_signals_t   mem_ctrl;

    EX_MEM u_EX_MEM (
        .clk            (clk),
        .rst_n          (rst_n),
        .ex_mem_flush   (ex_mem_flush),
        .ex_mem_stall   (ex_mem_stall),

        .ex_func3       (ex_func3),
        .ex_rd          (ex_rd),
        .ex_pc_plus_4   (ex_pc_plus_4),
        .ex_alu_result  (ex_alu_result),
        .ex_store_data  (ex_store_data),
        .ex_csr_rdata   (ex_csr_rdata),
        .ex_ctrl        (ex_ctrl),

        .mem_func3      (mem_func3),
        .mem_rd         (mem_rd),
        .mem_pc_plus_4  (mem_pc_plus_4),
        .mem_alu_result (mem_alu_result),
        .mem_store_data (mem_store_data),
        .mem_csr_rdata  (mem_csr_rdata),
        .mem_ctrl       (mem_ctrl)
    );


    // =========================================================================
    // 4. MEMORY STAGE (MEM)
    // =========================================================================
    logic         dcache_mem_req;
    logic         dcache_mem_rnw;
    logic [31:0]  dcache_mem_addr;
    logic [127:0] dcache_mem_wdata;
    logic [127:0] dcache_mem_rdata;
    logic         dcache_mem_ready;
    logic         dcache_miss;

    logic [31:0] mem_memory_data;

    dcache u_data_cache (
        .clk        (clk),
        .rst_n      (rst_n),                  
        
        // --- CPU Interface (Pipeline) ---
        .address    (mem_alu_result),         
        .MemRead    (mem_ctrl.mem.MemRead),
        .MemWrite   (mem_ctrl.mem.MemWrite),
        .func3      (mem_func3),              
        .WriteData  (mem_store_data),         
        .MemoryData (mem_memory_data),      
        .stall      (dcache_miss),           
        
        // --- Main Memory Interface ---
        .mem_req    (dcache_mem_req),
        .mem_rnw    (dcache_mem_rnw),
        .mem_addr   (dcache_mem_addr),
        .mem_wdata  (dcache_mem_wdata),
        .mem_rdata  (dcache_mem_rdata),
        .mem_ready  (dcache_mem_ready)
    );

    block_memory u_main_memory (
        .clk        (clk),
        .mem_req    (dcache_mem_req),
        .mem_rnw    (dcache_mem_rnw),
        .mem_addr   (dcache_mem_addr),
        .mem_wdata  (dcache_mem_wdata),
        .mem_rdata  (dcache_mem_rdata),
        .mem_ready  (dcache_mem_ready)
    ); 

    // -------------------------------------------------------------------------
    // PIPELINE REGISTER: MEM / WB
    // -------------------------------------------------------------------------
    logic [31:0]     wb_alu_result;
    logic [31:0]     wb_memory_data;
    logic [31:0]     wb_pc_plus_4;
    logic [31:0]     wb_csr_rdata;

    ctrl_signals_t   wb_ctrl;

    MEM_WB u_MEM_WB (
        .clk             (clk),
        .rst_n           (rst_n),
        .mem_wb_stall    (mem_wb_stall),

        .mem_rd          (mem_rd),
        .mem_pc_plus_4   (mem_pc_plus_4),
        .mem_alu_result  (mem_alu_result),
        .mem_memory_data (mem_memory_data),
        .mem_csr_rdata   (mem_csr_rdata),
        .mem_ctrl        (mem_ctrl),

        .wb_rd           (wb_rd),
        .wb_pc_plus_4    (wb_pc_plus_4),
        .wb_alu_result   (wb_alu_result),
        .wb_memory_data  (wb_memory_data),
        .wb_csr_rdata    (wb_csr_rdata),
        .wb_ctrl         (wb_ctrl)
    );


    // =========================================================================
    // 5. WRITE BACK STAGE (WB)
    // =========================================================================
    logic [31:0] wb_reg_write_data;
    logic [ 4:0] wb_rd;

    always_comb begin
        unique case (wb_ctrl.wb.WriteData)
            2'b00   : wb_reg_write_data = wb_alu_result;
            2'b01   : wb_reg_write_data = wb_memory_data;
            2'b10   : wb_reg_write_data = wb_pc_plus_4;
            2'b11   : wb_reg_write_data = wb_csr_rdata;
            default : wb_reg_write_data = wb_alu_result;
        endcase
    end

    // =========================================================================
    //  PIPELINE MONITOR (External Module)
    // =========================================================================
    core_monitor u_core_monitor (
        .clk, .rst_n, .report_trigger(report_trigger),

        // ---------------- IF ----------------
        .if_pc_current, .if_pc_plus_4, .if_instruction, .icache_miss,

        // ---------------- ID ----------------
        .id_instruction, .id_opcode, .id_rs1, .id_rs2, .id_rd,
        .id_read_data1, .id_read_data2, .id_imm, .id_take_branch,
        .branchSrc1, .branchSrc2, .ForwardBranchA, .ForwardBranchB,
        .id_ctrl, .id_excep,

        // ---------------- EX ----------------
        .ex_pc_current, .ex_rd, .ForwardA, .ForwardB, .ForwardStore,
        .ex_mux_alu_src1_out, .ex_mux_alu_src2_out, .ex_alu_operand_a,
        .ex_alu_operand_b, .ex_store_data, .ex_alu_control,
        .ex_alu_result, .ex_zero, .ex_less, .ex_csr_rdata,
        .csr_wdata, .csr_addr, .ex_ctrl, .ex_excep,

        // ---------------- MEM ----------------
        .mem_rd, .mem_alu_result, .mem_store_data, .mem_memory_data,
        .mem_csr_rdata, .dcache_miss, .mem_ctrl,

        // ---------------- WB ----------------
        .wb_rd, .wb_alu_result, .wb_memory_data, .wb_reg_write_data, .wb_ctrl,

        // ---------------- Hazard / Stall ----------------
        .pc_stall, .if_id_stall, .id_ex_stall, .ex_mem_stall, .mem_wb_stall,
        .hazard_if_id_flush, .id_ex_flush, .ex_mem_flush, .trap_if_id_flush,

        // ---------------- Trap / CSR ----------------
        .trap_taken, .mret_taken, .trap_jump, .mret_jump,
        .trap_pc, .trap_cause, .trap_vector, .mepc_value, .trap_next_pc
    );

 endmodule
