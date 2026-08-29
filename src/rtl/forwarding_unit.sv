/**
 * @file forwarding_unit.sv
 * @brief RISC-V 5-Stage Pipeline Forwarding Unit
 * @details Resolves data hazards by forwarding results from older pipeline stages 
 *          (EX/MEM, MEM/WB) to younger consuming stages (EX for ALU/Stores, IF for early Branches).
 */

import rv32_types_pkg::*;

module forwarding_unit (
    // Register Destination Indices from Pipeline Stages
    input  logic [4:0]    ex_rd,  // Actually represents EX stage destination (mapped from top)
    input  logic [4:0]    mem_rd, // Actually represents MEM stage destination (mapped from top)
    input  logic [4:0]    wb_rd,  // Actually represents WB stage destination (mapped from top)
    
    // Register Source Indices
    input  logic [4:0]    ex_rs1, // EX stage source 1
    input  logic [4:0]    ex_rs2, // EX stage source 2
    input  logic [4:0]    id_rs1, // ID stage source 1 (for early branch evaluation)
    input  logic [4:0]    id_rs2, // ID stage source 2 (for early branch evaluation)

    // Control Signals for Hazard and Source Validation
    input ctrl_signals_t  id_ctrl,  
    input ctrl_signals_t  ex_ctrl,  
    input ctrl_signals_t  mem_ctrl, 
    input ctrl_signals_t  wb_ctrl,  
    
    // Forwarding Selection Outputs
    output logic [1:0]    ForwardA,
    output logic [1:0]    ForwardB,
    output logic [1:0]    ForwardStore,
    output logic [2:0]    ForwardBranchA,
    output logic [2:0]    ForwardBranchB,
    output logic [1:0]    ForwardCSR
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
    function automatic logic [1:0] calc_forward_alu(
        input logic [4:0] rs
    );
        begin
            calc_forward_alu = 2'b00;

            // x0 is hardwired to zero and must never be forwarded.
            if (rs != 5'd0) begin
                // EX/MEM has the highest priority because it is the newest producer in the pipeline. use csr data
                if (mem_ctrl.wb.RegWrite && (mem_rd != 5'd0) && (mem_rd == rs) && mem_ctrl.csr.Read) begin
                    calc_forward_alu = 2'b01;
                end
                // use aku result
                else if (mem_ctrl.wb.RegWrite && (mem_rd != 5'd0) && (mem_rd == rs)) begin
                    calc_forward_alu = 2'b10;
                end

                // MEM/WB is used only if EX/MEM does not match (older producer). use wb data
                else if (wb_ctrl.wb.RegWrite && (wb_rd != 5'd0) && (wb_rd == rs)) begin
                    calc_forward_alu = 2'b11;
                end
            end
        end
    endfunction
    
    /**
     * @brief Computes forwarding selection for early branch resolution (IF/ID vs ID/EX & EX/MEM)
     * @param rs Source register address to check for hazards in earlier stages
     * @return 2-bit forwarding control code for branch operands
     */
    function automatic logic [2:0] calc_forward_branch(
        input logic [4:0] rs
    );
        begin
            calc_forward_branch = 3'b000;

            // x0 is hardwired to zero and must never be forwarded.
            if (rs != 5'd0) begin
                // ID/EX has the highest priority for early branch resolution (newest producer). use csr data 
                if (ex_ctrl.wb.RegWrite && ex_ctrl.csr.Read && (ex_rd != 5'd0) && (ex_rd == rs)) begin
                    calc_forward_branch = 3'b001;
                end
                // ID/EX has the highest priority for early branch resolution (newest producer). use alu result 
                else if (ex_ctrl.wb.RegWrite && (ex_rd != 5'd0) && (ex_rd == rs)) begin
                    calc_forward_branch = 3'b010;
                end
                // EX/MEM is used if ID/EX does not match, take data from memory_data_out.  use memory data 
                else if (mem_ctrl.wb.RegWrite && mem_ctrl.mem.MemRead && (mem_rd != 5'd0) && (mem_rd == rs)) begin
                    calc_forward_branch = 3'b011;
                end
                // EX/MEM use data from csr data 
                else if (mem_ctrl.wb.RegWrite && mem_ctrl.csr.Read && (mem_rd != 5'd0) && (mem_rd == rs)) begin
                    calc_forward_branch = 3'b100;
                end
                // EX/MEM take data from alu_result if instruction not load, use alu result
                else if (mem_ctrl.wb.RegWrite && (mem_rd != 5'd0) && (mem_rd == rs)) begin
                    calc_forward_branch = 3'b101; 
                end
            end
        end
    endfunction

    function automatic logic [1:0] calc_forward_csr(
        input logic [4:0] rs
    );
        begin
            calc_forward_csr = 2'b00;

            // x0 is hardwired to zero and must never be forwarded.
            if (rs != 5'd0) begin
                // EX/MEM has the highest priority because it is the newest producer in the pipeline.  use csr data
                if (mem_ctrl.wb.RegWrite && (mem_rd != 5'd0) && (mem_rd == rs) && mem_ctrl.csr.Read) begin
                    calc_forward_csr = 2'b01;
                end
                // use alu result in mem stage
                else if (mem_ctrl.wb.RegWrite && (mem_rd != 5'd0) && (mem_rd == rs)) begin
                    calc_forward_csr = 2'b10;
                end

                // MEM/WB is used only if EX/MEM does not match (older producer). use wb data 
                else if (wb_ctrl.wb.RegWrite && (wb_rd != 5'd0) && (wb_rd == rs)) begin
                    calc_forward_csr = 2'b11;
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
        ForwardBranchA = 3'b000;
        ForwardBranchB = 3'b000;
        ForwardCSR     = 2'b00;

        // --- Execute Stage Forwarding Logic (ALU & Stores) ---
        // Operand A forwarding is relevant only when sourced from rs1 (not PC).
        if (ex_ctrl.id.UseRs1)
            ForwardA = calc_forward_alu(ex_rs1);

        // Compute RS2 forwarding once to be shared between ALU B input and Store data path.
        rs2_forward = calc_forward_alu(ex_rs2);

        // For ALU B input, forwarding applies if sourced from a register and not a store instruction.
        if (ex_ctrl.id.UseRs2 && !ex_ctrl.mem.MemWrite)
            ForwardB = rs2_forward;

        // Store instructions require forwarded RS2 as write-data, even though ALU uses an immediate for address calculation.
        if (ex_ctrl.mem.MemWrite)
            ForwardStore = rs2_forward;


        // --- Decode Stage Forwarding Logic (Early Branch Evaluation) ---
        if (id_ctrl.id.UseRs1)
            ForwardBranchA = calc_forward_branch(id_rs1);
        
        if (id_ctrl.id.UseRs2)
            ForwardBranchB = calc_forward_branch(id_rs2);
            

        // --- Execute Satge Forwarding Logic (CSR Registers) 
        if (ex_ctrl.id.UseRs1)
            ForwardCSR = calc_forward_csr(ex_rs1);

    end

endmodule
