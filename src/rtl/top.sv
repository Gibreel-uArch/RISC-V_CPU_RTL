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

    instruction_fetch u_instruction_fetch (
        .clk                 (clk),
        .rst_n               (rst_n),
        .stall_pc            (stall_pc),
        .trap_jump           (trap_jump),
        .mret_jump           (mret_jump),
        .instruction         (if_instruction),
        .trap_next_pc        (trap_next_pc),
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

    logic        if_id_flush;
    assign if_id_flush = hazard_if_id_flush || trap_if_id_flush;

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

    logic                hazard_if_id_flush;
    logic                hazard_id_ex_flush;
    logic                stall;
    logic                stall_pc;
    logic                stall_branch;

    logic         [ 1:0] ForwardA;
    logic         [ 1:0] ForwardB;
    logic         [ 1:0] ForwardStore;
    logic         [ 2:0] ForwardBranchA;
    logic         [ 2:0] ForwardBranchB;
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
        .id_ex_flush  (hazard_id_ex_flush),
        .if_id_flush  (hazard_if_id_flush),
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
            3'b000  : branchSrc1 = id_read_data1;
            3'b001  : branchSrc1 = ex_csr_rdata;
            3'b010  : branchSrc1 = ex_alu_result;
            3'b011  : branchSrc1 = mem_alu_result;
            3'b100  : branchSrc1 = mem_csr_rdata;
            3'b101  : branchSrc1 = mem_alu_result;
            default : branchSrc1 = id_read_data1;
        endcase
    end

    always_comb begin
        unique case (ForwardBranchB)
            3'b000  : branchSrc2 = id_read_data1;
            3'b001  : branchSrc2 = ex_csr_rdata;
            3'b010  : branchSrc2 = ex_alu_result;
            3'b011  : branchSrc2 = mem_alu_result;
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
    logic        software_interrupt;
    logic        external_interrupt;

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
    logic [31:0]     wb_csr_rdata;
    ctrl_signals_t   wb_ctrl;

    MEM_WB u_MEM_WB (
        .clk             (clk),
        .rst_n           (rst_n),
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
  //  PIPELINE MONITOR & DEBUGGER WITH TRAP/EXCEPTION TRACKING
  // =========================================================================
  int cycle_count = 0;

  // Function to get register name
  function automatic string get_reg_name(input logic [4:0] reg_addr);
    string names[32] = '{
      "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
      "s0/fp", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
      "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
      "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
    };
    return $sformatf("%s(x%0d)", names[reg_addr], reg_addr);
  endfunction

  // Function to get trap cause name
  function automatic string get_trap_cause_name(input logic [31:0] cause);
    case (cause)
      32'd0  : return "Instruction Address Misaligned";
      32'd1  : return "Instruction Access Fault";
      32'd2  : return "Illegal Instruction";
      32'd3  : return "Breakpoint";
      32'd4  : return "Load Address Misaligned";
      32'd5  : return "Load Access Fault";
      32'd6  : return "Store Address Misaligned";
      32'd7  : return "Store Access Fault";
      32'd8  : return "Environment Call from U-mode (ECALL)";
      32'd9  : return "Environment Call from S-mode (ECALL)";
      32'd11 : return "Environment Call from M-mode (ECALL)";
      32'd12 : return "Instruction Page Fault";
      32'd13 : return "Load Page Fault";
      32'd15 : return "Store Page Fault";
      default: return "Unknown Cause";
    endcase
  endfunction

  // Function to get trap status
  function automatic string get_trap_status();
    if (trap_taken)
      return "TRAP TAKEN";
    else if (mret_taken)
      return "MRET EXECUTED";
    else if (ex_excep.illegal_inst)
      return "ILLEGAL INST";
    else if (ex_excep.ecall_inst)
      return "ECALL DETECTED";
    else if (ex_excep.ebreak_inst)
      return "EBREAK DETECTED";
    else
      return "NORMAL";
  endfunction

  // Main pipeline monitor
  always @(posedge clk) begin
    if (!rst_n) begin
      cycle_count <= 0;
    end else begin
      cycle_count <= cycle_count + 1;
      
      // =====================================================================
      // TRAP/EXCEPTION EVENT MONITOR
      // =====================================================================
      if (trap_taken || mret_taken || ex_excep.illegal_inst || 
          ex_excep.ecall_inst || ex_excep.ebreak_inst) begin
        $display("\n╔══════════════════════════════════════════════════════════════════════════════════════════╗");
        $display("║  ⚠️  EXCEPTION/TRAP EVENT DETECTED AT CYCLE %-4d                                         ║", cycle_count);
        $display("╚══════════════════════════════════════════════════════════════════════════════════════════╝");
        
        $display("  ┌─────────────────────────────────────────────────────────────────────────────┐");
        $display("  │  TRAP CONTROLLER STATUS                                                     │");
        $display("  ├─────────────────────────────────────────────────────────────────────────────┤");
        $display("  │  Status         : %-55s   │", get_trap_status());
        $display("  │  Trap Taken     : %-55b   │", trap_taken);
        $display("  │  MRET Taken     : %-55b   │", mret_taken);
        $display("  │  Trap PC        : 0x%-52h    │", trap_pc);
        $display("  │  Trap Cause     : 0x%-8h (%s)         │", trap_cause, get_trap_cause_name(trap_cause));
        $display("  │  Trap Vector    : 0x%-52h    │", trap_vector);
        $display("  │  MEPC Value     : 0x%-52h    │", mepc_value);
        $display("  │  Next PC        : 0x%-52h    │", trap_next_pc);
        $display("  └─────────────────────────────────────────────────────────────────────────────┘");
        
        $display("  ┌─────────────────────────────────────────────────────────────────────────────┐");
        $display("  │  TRAP CAUSE DETAILS                                                         │");
        $display("  ├─────────────────────────────────────────────────────────────────────────────┤");
        $display("  │  Illegal Inst   : %-55b   │", ex_excep.illegal_inst);
        $display("  │  ECALL Inst     : %-55b   │", ex_excep.ecall_inst);
        $display("  │  EBREAK Inst    : %-55b   │", ex_excep.ebreak_inst);
        $display("  │  MRET Inst      : %-55b   │", ex_excep.mret_inst);
        $display("  └─────────────────────────────────────────────────────────────────────────────┘");
        
        $display("  ┌─────────────────────────────────────────────────────────────────────────────┐");
        $display("  │  CSR REGISTER STATE                                                         │");
        $display("  ├─────────────────────────────────────────────────────────────────────────────┤");
        $display("  │  CSR Read Data  : 0x%-52h    │", ex_csr_rdata);
        $display("  │  CSR Write En   : %-55b   │", ex_ctrl.csr.Write);
        $display("  │  CSR Addr       : 0x%-52h    │", csr_addr);
        $display("  │  CSR Write Data : 0x%-52h    │", ex_read_data2);
        $display("  └─────────────────────────────────────────────────────────────────────────────┘");
      end
      
      // =====================================================================
      // STANDARD PIPELINE TRACE
      // =====================================================================
      $display("\n==================================================================================================");
      $display(" [CYC: %0d]  RV32 PIPELINE EXECUTION TRACE  |  [Stall: %b | Flush_IF: %b | Flush_ID: %b | Flush_EX: %b]", 
               cycle_count, stall, if_id_flush, id_ex_flush, ex_mem_flush);
      $display("==================================================================================================");
      
      // Trap/Exception Status Indicator
      if (trap_taken || mret_taken || ex_excep.illegal_inst || 
          ex_excep.ecall_inst || ex_excep.ebreak_inst) begin
        $display(" *** TRAP STATUS: %s | Cause: %s ***", 
                 get_trap_status(), get_trap_cause_name(trap_cause));
        $display(" -------------------------------------------------------------------------------------------------");
      end
      
      // 1. FETCH STAGE
      $display(" [1. IF Stage]  PC Current : 0x%h  |  PC + 4 : 0x%h  |  Instruction : 0x%h", 
               if_pc_current, if_pc_plus_4, if_instruction);
      if (trap_jump) begin
        $display("                ⚠️  Trap PC Override → Next PC: 0x%h", trap_next_pc);
      end
      
      if (mret_jump) begin
        $display("                ⚠️  MRET PC Override → Next PC: 0x%h", trap_next_pc);
      end
      // 2. DECODE STAGE
      $display(" -------------------------------------------------------------------------------------------------");
      $display(" [2. ID Stage]  Instruction : 0x%h  |  Opcode : %b  |  Imm : 0x%h",
               id_instruction, id_opcode, id_imm);
      $display("                Registers   : RS1=%s (0x%h) | RS2=%s (0x%h) | RD=%s",
               get_reg_name(id_rs1), id_read_data1, get_reg_name(id_rs2), id_read_data2, get_reg_name(id_rd));
      $display("                Branch Unit : Branch=%b | TakeBr : %b | JumpI/R=%b/%b | FwdA : %b | FwdB : %b",
               id_ctrl.id.Branch, id_take_branch, id_ctrl.id.JumpImm, id_ctrl.id.JumpReg, ForwardBranchA, ForwardBranchB);
      $display("                Branch Srcs : Src1=0x%h     | Src2=0x%h", branchSrc1, branchSrc2);
      
      // Exception Signals in Decode
      if (id_excep.illegal_inst || id_excep.ecall_inst || id_excep.ebreak_inst || id_excep.mret_inst) begin
        $display("                ⚠️  Exception Flags: Illegal=%b | ECALL=%b | EBREAK=%b | MRET=%b",
                 id_excep.illegal_inst, id_excep.ecall_inst, id_excep.ebreak_inst, id_excep.mret_inst);
      end
      
      // 3. EXECUTE STAGE
      $display(" -------------------------------------------------------------------------------------------------");
      $display(" [3. EX Stage]  PC Current  : 0x%h  |  Dest Reg : %s",
               ex_pc_current, get_reg_name(ex_rd));
      $display("                Usage Flags : UseRs1=%b   | UseRs2=%b",
               ex_ctrl.id.UseRs1, ex_ctrl.id.UseRs2);
      $display("                Forwarding  : FwdA=%b (Val: 0x%h)  --> ALU In1: 0x%h", 
               ForwardA, ex_mux_alu_src1_out, ex_alu_operand_a);
      $display("                Forwarding  : FwdB=%b (Val: 0x%h)  --> ALU In2: 0x%h", 
               ForwardB, ex_mux_alu_src2_out, ex_alu_operand_b);
      $display("                Store Fwd   : FwdS=%b   | Store Data : 0x%h", 
               ForwardStore, ex_store_data);
      $display("                ALU Unit    : Ctrl=%b   | Result     : 0x%h  | Zero=%b | Less=%b", 
               ex_alu_control, ex_alu_result, ex_zero, ex_less);
      $display("                CSR         : wdata : 0x%h | trap vector : 0x%h | mepc : 0x%h", 
               csr_wdata, trap_vector, trap_vector);
      $display("                CSR         : rdata : 0x%h | read = %b ", 
               ex_csr_rdata, ex_ctrl.csr.Read); 
               // Exception Detection in Execute Stage
      if (ex_excep.illegal_inst || ex_excep.ecall_inst || ex_excep.ebreak_inst || ex_excep.mret_inst) begin
        $display("                ⚠️  EXCEPTION DETECTED: Illegal=%b | ECALL=%b | EBREAK=%b | MRET=%b",
                 ex_excep.illegal_inst, ex_excep.ecall_inst, ex_excep.ebreak_inst, ex_excep.mret_inst);
      end
      
      // 4. MEMORY STAGE
      $display(" -------------------------------------------------------------------------------------------------");
      $display(" [4. MEM Stage] ALU Result  : 0x%h  |  Store Data : 0x%h  | CSR_data : 0x%h",
               mem_alu_result, mem_store_data, mem_csr_rdata);
      $display("                Mem Action  : Read=%b     | Write=%b      | Data Out : 0x%h | Dest Reg : %s",
               mem_ctrl.mem.MemRead, mem_ctrl.mem.MemWrite, mem_memory_data, get_reg_name(mem_rd));
      
      // 5. WRITE BACK STAGE
      $display(" -------------------------------------------------------------------------------------------------");
      $display(" [5. WB Stage]  ALU Result  : 0x%h  |  Mem Data   : 0x%h  |  Final WB : 0x%h",
               wb_alu_result, wb_memory_data, wb_reg_write_data);
      $display("                Control     : RegWrite=%b | WriteData=%b | Dest Reg  : %s",
               wb_ctrl.wb.RegWrite,wb_ctrl.wb.WriteData, get_reg_name(wb_rd));
      
      $display("==================================================================================================\n");
    end
  end
 endmodule
