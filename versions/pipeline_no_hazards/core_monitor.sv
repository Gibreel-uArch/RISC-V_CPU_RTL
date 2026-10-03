// ============================================================================
//  core_monitor.sv
//  Pipeline Monitor for RV32 Core
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
    input logic [6:0]  id_opcode,
    input logic [4:0]  id_rs1, id_rs2, id_rd,
    input logic [31:0] id_read_data1, id_read_data2, id_imm,
    input logic        id_take_branch,
    input ctrl_signals_t id_ctrl,

    // ---------------- EX Stage ----------------
    input logic [31:0] ex_pc_current,
    input logic [31:0] ex_pc_plus_4,
    input logic [4:0]  ex_rd,
    input logic [31:0] ex_mux_alu_src1_out,
    input logic [31:0] ex_mux_alu_src2_out,
    input logic [3:0]  ex_alu_control,
    input logic [31:0] ex_alu_result,
    input logic        ex_zero, ex_less, ex_less_unsigned,

    // ---------------- MEM Stage ----------------
    input logic [4:0]  mem_rd,
    input logic [31:0] mem_alu_result,
    input logic [31:0] mem_src2,
    input logic [31:0] mem_memory_data,
    input mem_ctrl_t   mem_ctrl,

    // ---------------- WB Stage ----------------
    input logic [4:0]  wb_rd,
    input logic [31:0] wb_alu_result,
    input logic [31:0] wb_memory_data,
    input logic [31:0] wb_reg_write_data,
    input wb_ctrl_t    wb_ctrl
);

    // ========================================================================
    //  Cycle Counter
    // ========================================================================
    int cycle_count = 0;

    // ========================================================================
    //  Helper Functions
    // ========================================================================
    function automatic string opcode_name(input logic [6:0] op);
        case (op)
            7'b0110011: return "R-type";
            7'b0010011: return "I-type (addi)";
            7'b0000011: return "LOAD (lw)";
            7'b0100011: return "STORE (sw)";
            7'b1100011: return "BRANCH (beq)";
            7'b1101111: return "JAL";
            7'b1100111: return "JALR";
            7'b0110111: return "LUI";
            7'b0010111: return "AUIPC";
            default:    return "UNKNOWN";
        endcase
    endfunction

    function automatic string reg_name(input logic [4:0] r);
        case (r)
            5'd0:  return "x0/zero";
            5'd1:  return "x1/ra";
            5'd2:  return "x2/sp";
            5'd3:  return "x3/gp";
            5'd4:  return "x4/tp";
            5'd5:  return "x5/t0";
            5'd6:  return "x6/t1";
            5'd7:  return "x7/t2";
            5'd8:  return "x8/s0";
            5'd9:  return "x9/s1";
            5'd10: return "x10/a0";
            5'd11: return "x11/a1";
            5'd12: return "x12/a2";
            5'd13: return "x13/a3";
            5'd14: return "x14/a4";
            5'd15: return "x15/a5";
            5'd16: return "x16/a6";
            5'd17: return "x17/a7";
            5'd18: return "x18/s2";
            default: return "x??";
        endcase
    endfunction

    // ========================================================================
    //  Main Monitoring Block
    // ========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            
            $display("================================================================================");
            $display(" [CYC = %0d] ---------------- PIPELINE STATUS MONITOR ----------------", cycle_count);
            $display("================================================================================");
            
            // 1. FETCH STAGE
            $display("[IF]  PC + 4       : %h | Raw Instruction : %h", if_pc_plus_4, if_instruction);
            
            // 2. DECODE STAGE
            $display("[ID]  Instruction  : %h | Opcode: %b (%s)", 
                     id_instruction, id_opcode, opcode_name(id_opcode));
            $display("      RD: %02d                  | RS1: %02d (%h) | RS2: %02d (%h)", 
                     id_rd, id_rs1, id_read_data1, id_rs2, id_read_data2);
            $display("      Imm          : %h | Branch: %b | TakeBranch: %b | JumpImm/Reg: %b/%b", 
                     id_imm, id_ctrl.id.Branch, id_take_branch, id_ctrl.id.JumpImm, id_ctrl.id.JumpReg);

            // 3. EXECUTE STAGE
            $display("[EX]  PC + 4       : %h | RD: %02d", ex_pc_plus_4, ex_rd);
            $display("      ALU Src1     : %h | ALU Src2     : %h | ALU Ctrl   : %b", 
                     ex_mux_alu_src1_out, ex_mux_alu_src2_out, ex_alu_control);
            $display("      ALU Result   : %h | Zero: %b | Less: %b", 
                     ex_alu_result, ex_zero, ex_less);

            // 4. MEMORY STAGE
            $display("[MEM] ALU Result   : %h | Mem Addr/Data: %h | MemRead/Write: %b/%b", 
                     mem_alu_result, mem_src2, mem_ctrl.MemRead, mem_ctrl.MemWrite);
            $display("      Mem Data Out : %h | RD           : %02d", 
                     mem_memory_data, mem_rd);

            // 5. WRITE BACK STAGE
            $display("[WB]  ALU Res      : %h | Mem Data     : %h | Final WB Data: %h", 
                     wb_alu_result, wb_memory_data, wb_reg_write_data);
            $display("      RegWrite     : %b | RD (Dest)    : %02d", 
                     wb_ctrl.RegWrite, wb_rd);

            $display("--------------------------------------------------------------------------------\n");
        end
    end

endmodule
