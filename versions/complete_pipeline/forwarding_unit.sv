/**
 * @file forwarding_unit.sv
 * @brief RISC-V 5-Stage Pipeline Forwarding Unit
 * @details Resolves data hazards by forwarding results from older pipeline stages 
 *          (EX/MEM, MEM/WB) to younger consuming stages (EX for ALU/Stores, IF for early Branches).
 */

import rv32_types_pkg::*;

module forwarding_unit (
    // Register Destination Indices from Pipeline Stages
    input  logic [4:0]    ex_rd,
    input  logic [4:0]    mem_rd,
    input  logic [4:0]    wb_rd,

    // Register Source Indices
    input  logic [4:0]    ex_rs1,
    input  logic [4:0]    ex_rs2,
    input  logic [4:0]    id_rs1,
    input  logic [4:0]    id_rs2,

    // Control Signals for Hazard and Source Validation
    input ctrl_signals_t  id_ctrl,
    input ctrl_signals_t  ex_ctrl,
    input ctrl_signals_t  mem_ctrl,
    input ctrl_signals_t  wb_ctrl,

    // Forwarding Selection Outputs
    output logic [1:0]    ForwardA,
    output logic [1:0]    ForwardB,
    output logic [1:0]    ForwardStore,
    output logic [1:0]    ForwardBranchA,
    output logic [1:0]    ForwardBranchB,
    output logic [1:0]    ForwardJump
);

    //----------------------------------------------------------------------
    // Forwarding MUX Encoding Scheme (used for EX-stage ALU operands):
    // 00 : Read from Register File
    // 01 : Forward from EX/MEM pipeline register (Newest producer)
    // 10 : Forward from MEM/WB pipeline register (Older producer)
    // 11 : Reserved / Unused
    //
    // Branch/Jump forwarding (ForwardBranchA/B, Forward_jump) uses a
    // DIFFERENT encoding because it must distinguish between the two
    // possible sources in the MEM stage (load data vs ALU result):
    // 00 : Read from Register File
    // 01 : Forward from ALU of instruction currently in EX (newest)
    // 10 : Forward from load data of instruction currently in MEM
    // 11 : Forward from ALU result of instruction currently in MEM
    //----------------------------------------------------------------------

    function automatic logic [1:0] calc_forward(
        input logic [4:0] rs
    );
        begin
            calc_forward = 2'b00;
            if (rs != 5'd0) begin
                if (mem_ctrl.wb.RegWrite && (mem_rd != 5'd0) && (mem_rd == rs)) begin
                    calc_forward = 2'b01;
                end
                else if (wb_ctrl.wb.RegWrite && (wb_rd != 5'd0) && (wb_rd == rs)) begin
                    calc_forward = 2'b10;
                end
            end
        end
    endfunction

    function automatic logic [1:0] calc_forward_branch(
        input logic [4:0] rs
    );
        begin
            calc_forward_branch = 2'b00;
            if (rs != 5'd0) begin
                // EX has the highest priority (newest producer).
                if (ex_ctrl.wb.RegWrite && (ex_rd != 5'd0) && (ex_rd == rs)) begin
                    calc_forward_branch = 2'b01;
                end
                // MEM load: forward load data.
                else if (mem_ctrl.wb.RegWrite && mem_ctrl.mem.MemRead
                         && (mem_rd != 5'd0) && (mem_rd == rs)) begin
                    calc_forward_branch = 2'b10;
                end
                // MEM non-load: forward ALU result from EX/MEM.
                else if (mem_ctrl.wb.RegWrite && (mem_rd != 5'd0) && (mem_rd == rs)) begin
                    calc_forward_branch = 2'b11;
                end
            end
        end
    endfunction

    always_comb begin
        logic [1:0] rs2_forward;

        // Defaults
        ForwardA       = 2'b00;
        ForwardB       = 2'b00;
        ForwardStore   = 2'b00;
        ForwardBranchA = 2'b00;
        ForwardBranchB = 2'b00;
        ForwardJump    = 2'b00;

        // --- Execute Stage Forwarding Logic (ALU & Stores) ---
        if (ex_ctrl.id.UseRs1)
            ForwardA = calc_forward(ex_rs1);

        rs2_forward = calc_forward(ex_rs2);

        if (ex_ctrl.id.UseRs2 && !ex_ctrl.mem.MemWrite)
            ForwardB = rs2_forward;

        if (ex_ctrl.mem.MemWrite)
            ForwardStore = rs2_forward;

        // --- Decode Stage Forwarding Logic (Early Branch Evaluation) ---
        if (id_ctrl.id.UseRs1)
            ForwardBranchA = calc_forward_branch(id_rs1);

        if (id_ctrl.id.UseRs2)
            ForwardBranchB = calc_forward_branch(id_rs2);

        // --- Jump Target Forwarding ---
        ForwardJump  = calc_forward_branch(id_rs1);
    end

endmodule
