// ============================================================================
//  core_monitor.sv
//  RV32 Pipeline Monitor + Forwarding + Hazards
// ============================================================================
import rv32_types_pkg::*;

module core_monitor (
    input logic clk,
    input logic rst_n,

    // ---------------- IF Stage ----------------
    input logic [31:0] if_pc_current,
    input logic [31:0] if_pc_plus_4,
    input logic [31:0] if_instruction,

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
    input logic [ 1:0] ForwardBranchA,
    input logic [ 1:0] ForwardBranchB,
    input ctrl_signals_t id_ctrl,

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
    input ctrl_signals_t ex_ctrl,

    // ---------------- MEM Stage ----------------
    input logic [ 4:0] mem_rd,
    input logic [31:0] mem_alu_result,
    input logic [31:0] mem_store_data,
    input logic [31:0] mem_memory_data,
    input ctrl_signals_t mem_ctrl,

    // ---------------- WB Stage ----------------
    input logic [ 4:0] wb_rd,
    input logic [31:0] wb_alu_result,
    input logic [31:0] wb_memory_data,
    input logic [31:0] wb_reg_write_data,
    input ctrl_signals_t wb_ctrl,

    // ---------------- Hazard / Stall ----------------
    input logic stall,
    input logic if_id_flush,
    input logic id_ex_flush,
    input logic stall_branch
);

    int cycle_count = 0;

    // ------------------------------------------------------------------------
    //  Helper: Reg name
    // ------------------------------------------------------------------------
    function automatic string get_reg_name(input logic [4:0] reg_addr);
        string names [32] = '{
            "zero","ra","sp","gp","tp","t0","t1","t2",
            "s0/fp","s1","a0","a1","a2","a3","a4","a5",
            "a6","a7","s2","s3","s4","s5","s6","s7",
            "s8","s9","s10","s11","t3","t4","t5","t6"
        };
        return $sformatf("%s(x%0d)", names[reg_addr], reg_addr);
    endfunction

    // ------------------------------------------------------------------------
    //  Main Monitoring Block
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            $display("==================================================================================================");
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
                     ex_ctrl.id.UseRs1, ex_ctrl.id.UseRs2);
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
                     mem_ctrl.mem.MemRead, mem_ctrl.mem.MemWrite, mem_memory_data);

            // 5. WRITE BACK STAGE
            $display(" --------------------------------------------------------------------------------------------------");
            $display(" [5. WB Stage]  ALU Result  : %h  |  Mem Data   : %h  |  Final WB : %h",
                     wb_alu_result, wb_memory_data, wb_reg_write_data);
            $display("                Control     : RegWrite=%b | Dest Reg  : %s",
                     wb_ctrl.wb.RegWrite, get_reg_name(wb_rd));

            $display("==================================================================================================\n");
        end
    end

endmodule
