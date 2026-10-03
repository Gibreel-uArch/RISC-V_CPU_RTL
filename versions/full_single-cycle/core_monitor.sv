// ============================================================
//  core_monitor.sv
//  Monitor / Debugger for RISC-V Core
// ============================================================
module core_monitor (
    input logic        clk,
    input logic        rst_n,

    // ---- Instruction / IF ----
    input logic [31:0] instruction,
    input logic [6:0]  opcode,
    input logic [31:0] pc_current,
    input logic [31:0] pc_plus_4,

    // ---- Decode / ID ----
    input logic [4:0]  rs1, rs2, rd,
    input logic [31:0] ReadData1, ReadData2,
    input logic [31:0] imm,

    // ---- Execute / EX ----
    input logic [31:0] mux_alu_src_out_1,
    input logic [31:0] mux_alu_src_out_2,
    input logic [31:0] alu_result,
    input logic [3:0]  alu_control,
    input logic        zero,
    input logic        less,
    input logic        less_unsigned,
    input logic        take_branch,

    // ---- Memory / ME ----
    input logic [31:0] MemoryData,
    input logic        MemRead,
    input logic        MemWrite,
    input logic [31:0] address,
    input logic [31:0] WriteData,

    // ---- WriteBack / WB ----
    input logic [31:0] RegWriteData,
    input logic        RegWrite
);

    // ==========================================================
    //  Cycle Counter
    // ==========================================================
    int cycle_count = 0;
    function automatic string opcode_name(input logic [6:0] op);
        case (op)
            7'b0110011: return "R-type (add/sub/...)";
            7'b0010011: return "I-type (addi/...)";
            7'b0000011: return "LOAD  (lw)";
            7'b0100011: return "STORE (sw)";
            7'b1100011: return "BRANCH(beq/bne)";
            7'b1101111: return "JAL";
            7'b1100111: return "JALR";
            7'b0110111: return "LUI";
            7'b0010111: return "AUIPC";
            default:    return "UNKNOWN";
        endcase
    endfunction

    // ==========================================================
    //  Main Debugging / Monitoring Block
    // ==========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            $display("=================================================================");
            $display(" [SIM_CYCLE : %0d]", cycle_count);

            // ---------- IF ----------
            $display("  [IF] PC        : 0x%08h  | NextPC: 0x%08h",
                     pc_current, pc_plus_4);
            $display("       Instr     : 0x%08h  | Opcode: %07b  (%s)",
                     instruction, opcode, opcode_name(opcode));

            // ---------- ID ----------
            $display("  [ID] rs1(x%0d)  : 0x%08h", rs1, ReadData1);
            $display("       rs2(x%0d)  : 0x%08h", rs2, ReadData2);
            $display("       Imm       : 0x%08h  | rd = x%0d", imm, rd);

            // ---------- EX ----------
            $display("  [EX] Src1      : 0x%08h", mux_alu_src_out_1);
            $display("       Src2      : 0x%08h", mux_alu_src_out_2);
            $display("       ALU Ctrl  : %04b", alu_control);
            $display("       ALU Result: 0x%08h  | Zero=%b  Less=%b  LessU=%b",
                     alu_result, zero, less, less_unsigned);
            $display("       Branch    : take_branch=%b", take_branch);

            // ---------- ME ----------
            $display("  [ME] Address   : 0x%08h", address);
            $display("       WriteData : 0x%08h  | ReadData: 0x%08h",
                     WriteData, MemoryData);
            $display("       MemRead   : %b     | MemWrite: %b",
                     MemRead, MemWrite);

            // ---------- WB ----------
            $display("  [WB] RegWrite  : %b     | WB Data : 0x%08h",
                     RegWrite, RegWriteData);

            $display("");
        end
    end

endmodule
