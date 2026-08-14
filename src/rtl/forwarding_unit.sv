/**
 * @file forwarding_unit.sv
 * @brief RISC-V 5-Stage Pipeline Forwarding Unit
 * @details Resolves data hazards by forwarding results from older pipeline stages 
 *          (EX/MEM, MEM/WB) to younger consuming stages (EX for ALU/Stores, IF for early Branches).
 */

import rv32_types_pkg::*;

module forwarding_unit (
    // Register Destination Indices from Pipeline Stages
    input  logic [4:0]    id_rd,  // Actually represents EX stage destination (mapped from top)
    input  logic [4:0]    ex_rd,  // Actually represents MEM stage destination (mapped from top)
    input  logic [4:0]    mem_rd, // Actually represents WB stage destination (mapped from top)
    
    // Register Source Indices
    input  logic [4:0]    id_rs1, // EX stage source 1
    input  logic [4:0]    id_rs2, // EX stage source 2
    input  logic [4:0]    if_rs1, // ID stage source 1 (for early branch evaluation)
    input  logic [4:0]    if_rs2, // ID stage source 2 (for early branch evaluation)

    // Control Signals for Hazard and Source Validation
    input  ctrl_signals_t if_ctrl, // Control signals for IF/ID stage
    input  ctrl_signals_t id_ctrl, // Control signals for ID/EX stage

    input  wb_ctrl_t      ex_wb_ctrl,  // Control signals in EX/MEM stage
    input  mem_ctrl_t     ex_mem_ctrl,
    input  wb_ctrl_t      mem_ctrl, // Control signals in MEM/WB stage

    // Forwarding Selection Outputs
    output logic [1:0]    ForwardA,
    output logic [1:0]    ForwardB,
    output logic [1:0]    ForwardStore,
    output logic [1:0]    ForwardBranchA,
    output logic [1:0]    ForwardBranchB
);

    //----------------------------------------------------------------------
    // Forwarding MUX Encoding Scheme:
    // 00 : Read from Register File
    // 01 : Forward from EX/MEM pipeline register (Newest producer)
    // 10 : Forward from MEM/WB pipeline register (Older producer)
    // 11 : Reserved / Unused
    //----------------------------------------------------------------------

    /**
     * @brief Computes forwarding selection for the execute stage (ID/EX vs EX/MEM & MEM/WB)
     * @param rs Source register address to check for hazards
     * @return 2-bit forwarding control code
     */
    function automatic logic [1:0] calc_forward(
        input logic [4:0] rs
    );
        begin
            calc_forward = 2'b00;

            // x0 is hardwired to zero and must never be forwarded.
            if (rs != 5'd0) begin
                // EX/MEM has the highest priority because it is the newest producer in the pipeline.
                if (ex_wb_ctrl.RegWrite && (ex_rd != 5'd0) && (ex_rd == rs)) begin
                    calc_forward = 2'b01;
                end
                // MEM/WB is used only if EX/MEM does not match (older producer).
                else if (mem_ctrl.RegWrite && (mem_rd != 5'd0) && (mem_rd == rs)) begin
                    calc_forward = 2'b10;
                end
            end
        end
    endfunction
    
    /**
     * @brief Computes forwarding selection for early branch resolution (IF/ID vs ID/EX & EX/MEM)
     * @param rs Source register address to check for hazards in earlier stages
     * @return 2-bit forwarding control code for branch operands
     */
    function automatic logic [1:0] calc_forward_branch(
        input logic [4:0] rs
    );
        begin
            calc_forward_branch = 2'b00;

            // x0 is hardwired to zero and must never be forwarded.
            if (rs != 5'd0) begin
                // ID/EX has the highest priority for early branch resolution (newest producer).
                if (id_ctrl.wb.RegWrite && (id_rd != 5'd0) && (id_rd == rs)) begin
                    calc_forward_branch = 2'b01;
                end
                // EX/MEM is used if ID/EX does not match (older producer).
                else if (ex_wb_ctrl.RegWrite && ex_mem_ctrl.MemRead && (ex_rd != 5'd0) && (ex_rd == rs)) begin
                    calc_forward_branch = 2'b10;
                end
                // EX/MEM take data from alu_result if instruction not load.
                else if (ex_wb_ctrl.RegWrite && (ex_rd != 5'd0) && (ex_rd == rs)) begin
                    calc_forward_branch = 2'b11; 
                end
            end
        end
    endfunction

    always_comb begin
        logic [1:0] rs2_forward;

        // Default values: Default to Register File source (00)
        ForwardA       = 2'b00;
        ForwardB       = 2'b00;
        ForwardStore   = 2'b00;
        ForwardBranchA = 2'b00;
        ForwardBranchB = 2'b00;

        // --- Execute Stage Forwarding Logic (ALU & Stores) ---
        // Operand A forwarding is relevant only when sourced from rs1 (not PC).
        if (id_ctrl.id.UseRs1)
            ForwardA = calc_forward(id_rs1);

        // Compute RS2 forwarding once to be shared between ALU B input and Store data path.
        rs2_forward = calc_forward(id_rs2);

        // For ALU B input, forwarding applies if sourced from a register and not a store instruction.
        if (id_ctrl.id.UseRs2 && !id_ctrl.mem.MemWrite)
            ForwardB = rs2_forward;

        // Store instructions require forwarded RS2 as write-data, even though ALU uses an immediate for address calculation.
        if (id_ctrl.mem.MemWrite)
            ForwardStore = rs2_forward;

        // --- Decode Stage Forwarding Logic (Early Branch Evaluation) ---
        if (if_ctrl.id.UseRs1)
            ForwardBranchA = calc_forward_branch(if_rs1);
        
        if (if_ctrl.id.UseRs2)
            ForwardBranchB = calc_forward_branch(if_rs2);
    end

endmodule
