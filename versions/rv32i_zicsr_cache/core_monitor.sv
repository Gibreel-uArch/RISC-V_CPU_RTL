// ============================================================================
//  core_monitor.sv
//  RV32 Pipeline Monitor with Performance Analytics
//  - Full pipeline trace (same beautiful format)
//  - Trap/Exception/Interrupt tracking
//  - Cache performance tracking
//  - Final performance report at end of simulation
// ============================================================================
import rv32_types_pkg::*;

module core_monitor (
    input logic clk,
    input logic rst_n,
    input logic report_trigger,

    // ---------------- IF Stage ----------------
    input logic [31:0] if_pc_current,
    input logic [31:0] if_pc_plus_4,
    input logic [31:0] if_instruction,
    input logic        icache_miss,

    // ---------------- ID Stage ----------------
    input logic [31:0] id_instruction,
    input logic [ 6:0] id_opcode,
    input logic [ 4:0] id_rs1,
    input logic [ 4:0] id_rs2,
    input logic [ 4:0] id_rd,
    input logic [31:0] id_read_data1,
    input logic [31:0] id_read_data2,
    input logic [31:0] id_imm,
    input logic        id_take_branch,
    input logic [31:0] branchSrc1,
    input logic [31:0] branchSrc2,
    input logic [ 2:0] ForwardBranchA,
    input logic [ 2:0] ForwardBranchB,
    input ctrl_signals_t  id_ctrl,
    input excep_signals_t id_excep,

    // ---------------- EX Stage ----------------
    input logic [31:0] ex_pc_current,
    input logic [ 4:0] ex_rd,
    input logic [ 1:0] ForwardA,
    input logic [ 1:0] ForwardB,
    input logic [ 1:0] ForwardStore,
    input logic [31:0] ex_mux_alu_src1_out,
    input logic [31:0] ex_mux_alu_src2_out,
    input logic [31:0] ex_alu_operand_a,
    input logic [31:0] ex_alu_operand_b,
    input logic [31:0] ex_store_data,
    input logic [ 3:0] ex_alu_control,
    input logic [31:0] ex_alu_result,
    input logic        ex_zero,
    input logic        ex_less,
    input logic [31:0] ex_csr_rdata,
    input logic [31:0] csr_wdata,
    input logic [11:0] csr_addr,
    input ctrl_signals_t  ex_ctrl,
    input excep_signals_t ex_excep,

    // ---------------- MEM Stage ----------------
    input logic [ 4:0] mem_rd,
    input logic [31:0] mem_alu_result,
    input logic [31:0] mem_store_data,
    input logic [31:0] mem_memory_data,
    input logic [31:0] mem_csr_rdata,
    input logic        dcache_miss,
    input ctrl_signals_t mem_ctrl,

    // ---------------- WB Stage ----------------
    input logic [ 4:0] wb_rd,
    input logic [31:0] wb_alu_result,
    input logic [31:0] wb_memory_data,
    input logic [31:0] wb_reg_write_data,
    input ctrl_signals_t wb_ctrl,

    // ---------------- Hazard / Stall ----------------
    input logic pc_stall,
    input logic if_id_stall,
    input logic id_ex_stall,
    input logic ex_mem_stall,
    input logic mem_wb_stall,
    input logic hazard_if_id_flush,
    input logic id_ex_flush,
    input logic ex_mem_flush,
    input logic trap_if_id_flush,

    // ---------------- Trap / CSR ----------------
    input logic        trap_taken,
    input logic        mret_taken,
    input logic        trap_jump,
    input logic        mret_jump,
    input logic [31:0] trap_pc,
    input logic [31:0] trap_cause,
    input logic [31:0] trap_vector,
    input logic [31:0] mepc_value,
    input logic [31:0] trap_next_pc
);

    // ========================================================================
    //  Cycle Counter + Performance Counters
    // ========================================================================
    int cycle_count = 0;

    // Pipeline activity
    int inst_retired   = 0;   
    int inst_fetched   = 0;   

    // Stalls
    int stall_pc_cnt    = 0;
    int stall_ifid_cnt  = 0;
    int stall_idex_cnt  = 0;
    int stall_exmem_cnt = 0;
    int stall_memwb_cnt = 0;

    // Flushes
    int flush_ifid_cnt  = 0;
    int flush_idex_cnt  = 0;
    int flush_exmem_cnt = 0;

    // Cache
    int icache_miss_cnt = 0;
    int dcache_miss_cnt = 0;

    // Control hazards
    int branch_taken_cnt = 0;
    int forward_used_cnt = 0;

    // Traps
    int trap_cnt        = 0;
    int mret_cnt        = 0;
    int exception_cnt   = 0;

    // Track last values to count edges (rising only)
    logic prev_icache_miss, prev_dcache_miss;
    logic prev_id_take_branch;
    logic prev_trap_taken, prev_mret_taken;
    logic prev_any_exception;

    logic prev_pc_stall, prev_ifid_stall, prev_idex_stall, prev_exmem_stall, prev_memwb_stall;
    logic prev_f_ifid, prev_f_idex, prev_f_exmem;

    // ========================================================================
    //  Helper Functions
    // ========================================================================
    function automatic string get_reg_name(input logic [4:0] reg_addr);
        string names [32] = '{
            "zero","ra","sp","gp","tp","t0","t1","t2",
            "s0/fp","s1","a0","a1","a2","a3","a4","a5",
            "a6","a7","s2","s3","s4","s5","s6","s7",
            "s8","s9","s10","s11","t3","t4","t5","t6"
        };
        return $sformatf("%s(x%0d)", names[reg_addr], reg_addr);
    endfunction

    function automatic string get_trap_cause_name(input logic [31:0] cause);
        case (cause)
            32'd0  : return "Instr Addr Misaligned";
            32'd1  : return "Instr Access Fault";
            32'd2  : return "Illegal Instruction";
            32'd3  : return "Breakpoint";
            32'd4  : return "Load Addr Misaligned";
            32'd5  : return "Load Access Fault";
            32'd6  : return "Store Addr Misaligned";
            32'd7  : return "Store Access Fault";
            32'd8  : return "ECALL (U-mode)";
            32'd9  : return "ECALL (S-mode)";
            32'd11 : return "ECALL (M-mode)";
            32'd12 : return "Instr Page Fault";
            32'd13 : return "Load Page Fault";
            32'd15 : return "Store Page Fault";
            default: return "Unknown";
        endcase
    endfunction

    function automatic string get_trap_status();
        if (trap_taken)                       return "TRAP TAKEN";
        else if (mret_taken)                  return "MRET EXECUTED";
        else if (ex_excep.illegal_inst)       return "ILLEGAL INST";
        else if (ex_excep.ecall_inst)         return "ECALL DETECTED";
        else if (ex_excep.ebreak_inst)        return "EBREAK DETECTED";
        else                                  return "NORMAL";
    endfunction

    // ========================================================================
    //  Event Detection (rising edges)
    // ========================================================================
    wire cur_any_exception = ex_excep.illegal_inst || ex_excep.ecall_inst ||
                             ex_excep.ebreak_inst  || ex_excep.mret_inst;

    wire cur_any_flush = hazard_if_id_flush || trap_if_id_flush ||
                         id_ex_flush || ex_mem_flush;

    // ========================================================================
    //  Main Monitoring Block
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count      <= 0;
            inst_retired     <= 0;
            inst_fetched     <= 0;
            stall_pc_cnt     <= 0;
            stall_ifid_cnt   <= 0;
            stall_idex_cnt   <= 0;
            stall_exmem_cnt  <= 0;
            stall_memwb_cnt  <= 0;
            flush_ifid_cnt   <= 0;
            flush_idex_cnt   <= 0;
            flush_exmem_cnt  <= 0;
            icache_miss_cnt  <= 0;
            dcache_miss_cnt  <= 0;
            branch_taken_cnt <= 0;
            forward_used_cnt <= 0;
            trap_cnt         <= 0;
            mret_cnt         <= 0;
            exception_cnt    <= 0;

            prev_icache_miss   <= 0;
            prev_dcache_miss   <= 0;
            prev_id_take_branch<= 0;
            prev_trap_taken    <= 0;
            prev_mret_taken    <= 0;
            prev_any_exception <= 0;
            prev_pc_stall      <= 0;
            prev_ifid_stall    <= 0;
            prev_idex_stall    <= 0;
            prev_exmem_stall   <= 0;
            prev_memwb_stall   <= 0;
            prev_f_ifid        <= 0;
            prev_f_idex        <= 0;
            prev_f_exmem       <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            // ============================================================
            //  Update counters (rising edges)
            // ============================================================
            if (icache_miss  && !prev_icache_miss)  icache_miss_cnt  <= icache_miss_cnt + 1;
            if (dcache_miss  && !prev_dcache_miss)  dcache_miss_cnt  <= dcache_miss_cnt + 1;
            if (id_take_branch && !prev_id_take_branch) branch_taken_cnt <= branch_taken_cnt + 1;
            if (trap_taken   && !prev_trap_taken)   trap_cnt   <= trap_cnt + 1;
            if (mret_taken   && !prev_mret_taken)   mret_cnt   <= mret_cnt + 1;
            if (cur_any_exception && !prev_any_exception) exception_cnt <= exception_cnt + 1;

            if (pc_stall    && !prev_pc_stall)     stall_pc_cnt    <= stall_pc_cnt + 1;
            if (if_id_stall && !prev_ifid_stall)   stall_ifid_cnt  <= stall_ifid_cnt + 1;
            if (id_ex_stall && !prev_idex_stall)   stall_idex_cnt  <= stall_idex_cnt + 1;
            if (ex_mem_stall&& !prev_exmem_stall)  stall_exmem_cnt <= stall_exmem_cnt + 1;
            if (mem_wb_stall&& !prev_memwb_stall)  stall_memwb_cnt <= stall_memwb_cnt + 1;

            if (hazard_if_id_flush && !prev_f_ifid)  flush_ifid_cnt  <= flush_ifid_cnt + 1;
            if (id_ex_flush        && !prev_f_idex)  flush_idex_cnt  <= flush_idex_cnt + 1;
            if (ex_mem_flush       && !prev_f_exmem) flush_exmem_cnt <= flush_exmem_cnt + 1;

            // Instruction retired: any instruction that successfully writes back
            // (RegWrite asserted OR explicit non-write instruction reaching WB)
            if (!mem_wb_stall)
                inst_retired <= inst_retired + 1;

            // Instruction fetched
            if (!pc_stall && !icache_miss)
                inst_fetched <= inst_fetched + 1;

            // Forwarding used
            if ((ForwardA != 2'b00) || (ForwardB != 2'b00) || (ForwardStore != 2'b00))
                forward_used_cnt <= forward_used_cnt + 1;

            // ============================================================
            //  TRAP/EXCEPTION EVENT BANNER (same beautiful format)
            // ============================================================
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
                $display("  │  CSR Addr       : 0x%-52h    │", {20'b0, csr_addr});
                $display("  │  CSR Write Data : 0x%-52h    │", csr_wdata);
                $display("  └─────────────────────────────────────────────────────────────────────────────┘");
            end

            // ============================================================
            //  STANDARD PIPELINE TRACE (same format)
            // ============================================================
            $display("\n==================================================================================================");
            $display(" [CYC: %0d] RV32 PIPELINE EXECUTION TRACE", cycle_count);
            $display(" [Stall_pc: %b | Stall_ID: %b | Stall_EX: %b | Stall_MEM: %b | Stall_WB: %b] icache_miss : %b",
                     pc_stall, if_id_stall, id_ex_stall, ex_mem_stall, mem_wb_stall, icache_miss);
            $display(" [Flush_IF: %b | Flush_ID: %b | Flush_EX: %b | FLUSH_MEM: 0 | Flush_WB: 0] dcache_miss : %b",
                     hazard_if_id_flush || trap_if_id_flush, id_ex_flush, ex_mem_flush, dcache_miss);
            $display("==================================================================================================");

            if (trap_taken || mret_taken || ex_excep.illegal_inst ||
                ex_excep.ecall_inst || ex_excep.ebreak_inst) begin
                $display(" *** TRAP STATUS: %s | Cause: %s ***",
                         get_trap_status(), get_trap_cause_name(trap_cause));
                $display(" -------------------------------------------------------------------------------------------------");
            end

            // 1. FETCH
            $display(" [1. IF Stage]  PC Current : 0x%h  |  PC + 4 : 0x%h  |  Instruction : 0x%h",
                     if_pc_current, if_pc_plus_4, if_instruction);
            if (trap_jump) $display("                ⚠️  Trap PC Override → Next PC: 0x%h", trap_next_pc);
            if (mret_jump) $display("                ⚠️  MRET PC Override → Next PC: 0x%h", trap_next_pc);

            // 2. DECODE
            $display(" -------------------------------------------------------------------------------------------------");
            $display(" [2. ID Stage]  Instruction : 0x%h  |  Opcode : %b  |  Imm : 0x%h",
                     id_instruction, id_opcode, id_imm);
            $display("                Registers   : RS1=%s (0x%h) | RS2=%s (0x%h) | RD=%s",
                     get_reg_name(id_rs1), id_read_data1,
                     get_reg_name(id_rs2), id_read_data2,
                     get_reg_name(id_rd));
            $display("                Branch Unit : Branch=%b | TakeBr : %b | JumpI/R=%b/%b | FwdA : %b | FwdB : %b",
                     id_ctrl.id.Branch, id_take_branch,
                     id_ctrl.id.JumpImm, id_ctrl.id.JumpReg,
                     ForwardBranchA, ForwardBranchB);
            $display("                Branch Srcs : Src1=0x%h     | Src2=0x%h", branchSrc1, branchSrc2);

            if (id_excep.illegal_inst || id_excep.ecall_inst || id_excep.ebreak_inst || id_excep.mret_inst)
                $display("                ⚠️  Exception Flags: Illegal=%b | ECALL=%b | EBREAK=%b | MRET=%b",
                         id_excep.illegal_inst, id_excep.ecall_inst, id_excep.ebreak_inst, id_excep.mret_inst);

            // 3. EXECUTE
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
                     csr_wdata, trap_vector, mepc_value);
            $display("                CSR         : rdata : 0x%h | read = %b",
                     ex_csr_rdata, ex_ctrl.csr.Read);

            if (ex_excep.illegal_inst || ex_excep.ecall_inst || ex_excep.ebreak_inst || ex_excep.mret_inst)
                $display("                ⚠️  EXCEPTION DETECTED: Illegal=%b | ECALL=%b | EBREAK=%b | MRET=%b",
                         ex_excep.illegal_inst, ex_excep.ecall_inst, ex_excep.ebreak_inst, ex_excep.mret_inst);

            // 4. MEMORY
            $display(" -------------------------------------------------------------------------------------------------");
            $display(" [4. MEM Stage] ALU Result  : 0x%h |  Store Data : 0x%h  | CSR_data : 0x%h",
                     mem_alu_result, mem_store_data, mem_csr_rdata);
            $display("                Mem Action  : Read=%b   | Write=%b   | Data Out : 0x%h | Dest Reg : %s",
                     mem_ctrl.mem.MemRead, mem_ctrl.mem.MemWrite,
                     mem_memory_data, get_reg_name(mem_rd));

            // 5. WRITE BACK
            $display(" -------------------------------------------------------------------------------------------------");
            $display(" [5. WB Stage]  ALU Result  : 0x%h |  Mem Data   : 0x%h  |  Final WB : 0x%h",
                     wb_alu_result, wb_memory_data, wb_reg_write_data);
            $display("                Control     : RegWrite=%b | WriteData=%b | Dest Reg  : %s",
                     wb_ctrl.wb.RegWrite, wb_ctrl.wb.WriteData, get_reg_name(wb_rd));
            $display("==================================================================================================\n");

            // ============================================================
            //  Update previous values for edge detection
            // ============================================================
            prev_icache_miss    <= icache_miss;
            prev_dcache_miss    <= dcache_miss;
            prev_id_take_branch <= id_take_branch;
            prev_trap_taken     <= trap_taken;
            prev_mret_taken     <= mret_taken;
            prev_any_exception  <= cur_any_exception;
            prev_pc_stall       <= pc_stall;
            prev_ifid_stall     <= if_id_stall;
            prev_idex_stall     <= id_ex_stall;
            prev_exmem_stall    <= ex_mem_stall;
            prev_memwb_stall    <= mem_wb_stall;
            prev_f_ifid         <= hazard_if_id_flush;
            prev_f_idex         <= id_ex_flush;
            prev_f_exmem        <= ex_mem_flush;
        end
    end

    always_comb begin
        if (report_trigger) begin
            dump_report();
        end
    end

    // ========================================================================
    //  FINAL PERFORMANCE REPORT
    // ========================================================================
    function void dump_report();
        int  total_stalls;
        int  total_flushes;
        real ipc, cpi, stall_rate, flush_rate;

        total_stalls  = stall_pc_cnt + stall_ifid_cnt + stall_idex_cnt +
                        stall_exmem_cnt + stall_memwb_cnt;
        total_flushes = flush_ifid_cnt + flush_idex_cnt + flush_exmem_cnt;

        ipc        = (cycle_count   > 0) ? real'(inst_retired) / real'(cycle_count)   : 0.0;
        cpi        = (inst_retired  > 0) ? real'(cycle_count)  / real'(inst_retired)  : 0.0;
        stall_rate = (cycle_count   > 0) ? 100.0 * real'(total_stalls)  / real'(cycle_count) : 0.0;
        flush_rate = (cycle_count   > 0) ? 100.0 * real'(total_flushes) / real'(cycle_count) : 0.0;

        $display("\n");
        $display("╔══════════════════════════════════════════════════════════════════════════════════════════════╗");
        $display("║                                                                                              ║");
        $display("║                      RISC-V CORE PERFORMANCE REPORT                                          ║");
        $display("║                                                                                              ║");
        $display("╠══════════════════════════════════════════════════════════════════════════════════════════════╣");
        $display("║  🕒 TIMING                                                                                   ║");
        $display("╟──────────────────────────────────────────────────────────────────────────────────────────────╢");
        $display("║    Total Cycles         : %-60d       ║", cycle_count);
        $display("║    Instructions Retired : %-60d       ║", inst_retired);
        $display("║    Instructions Fetched : %-60d       ║", inst_fetched);
        $display("╟──────────────────────────────────────────────────────────────────────────────────────────────╢");
        $display("║  ⚡ PERFORMANCE METRICS                                                                      ║");
        $display("╟──────────────────────────────────────────────────────────────────────────────────────────────╢");
        $display("║    IPC (Instr/Cycle)    : %-60.3f       ║", ipc);
        $display("║    CPI (Cycle/Instr)    : %-60.3f       ║", cpi);
        $display("║    Stall Rate           : %-60.2f%%      ║", stall_rate);
        $display("║    Flush Rate           : %-60.2f%%      ║", flush_rate);
        $display("╟──────────────────────────────────────────────────────────────────────────────────────────────╢");
        $display("║  🛑 PIPELINE STALLS                                                                          ║");
        $display("╟──────────────────────────────────────────────────────────────────────────────────────────────╢");
        $display("║    PC Stall             : %-60d       ║", stall_pc_cnt);
        $display("║    IF/ID Stall          : %-60d       ║", stall_ifid_cnt);
        $display("║    ID/EX Stall          : %-60d       ║", stall_idex_cnt);
        $display("║    EX/MEM Stall         : %-60d       ║", stall_exmem_cnt);
        $display("║    MEM/WB Stall         : %-60d       ║", stall_memwb_cnt);
        $display("║    Total Stalls         : %-60d       ║", total_stalls);
        $display("╟──────────────────────────────────────────────────────────────────────────────────────────────╢");
        $display("║  💥 PIPELINE FLUSHES                                                                         ║");
        $display("╟──────────────────────────────────────────────────────────────────────────────────────────────╢");
        $display("║    IF/ID Flush          : %-60d       ║", flush_ifid_cnt);
        $display("║    ID/EX Flush          : %-60d       ║", flush_idex_cnt);
        $display("║    EX/MEM Flush         : %-60d       ║", flush_exmem_cnt);
        $display("║    Total Flushes        : %-60d       ║", total_flushes);
        $display("╟──────────────────────────────────────────────────────────────────────────────────────────────╢");
        $display("║  🗄️  CACHE PERFORMANCE                                                                        ║");
        $display("╟──────────────────────────────────────────────────────────────────────────────────────────────╢");
        $display("║    I-Cache Misses       : %-60d       ║", icache_miss_cnt);
        $display("║    D-Cache Misses       : %-60d       ║", dcache_miss_cnt);
        $display("╟──────────────────────────────────────────────────────────────────────────────────────────────╢");
        $display("║  🎯 CONTROL HAZARDS                                                                          ║");
        $display("╟──────────────────────────────────────────────────────────────────────────────────────────────╢");
        $display("║    Branches Taken       : %-60d       ║", branch_taken_cnt);
        $display("║    Forwarding Used      : %-60d       ║", forward_used_cnt);
        $display("╟──────────────────────────────────────────────────────────────────────────────────────────────╢");
        $display("║  🚨 EXCEPTIONS & TRAPS                                                                       ║");
        $display("╟──────────────────────────────────────────────────────────────────────────────────────────────╢");
        $display("║    Traps Taken          : %-60d       ║", trap_cnt);
        $display("║    MRET Executed        : %-60d       ║", mret_cnt);
        $display("║    Exceptions Detected  : %-60d       ║", exception_cnt);
        $display("╚══════════════════════════════════════════════════════════════════════════════════════════════╝");
        $display("\n");
    endfunction

endmodule
