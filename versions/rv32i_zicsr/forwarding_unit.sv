/**
 * @file forwarding_unit.sv
 * @brief RISC-V 5-Stage Pipeline Forwarding Unit (Enhanced with CSR and Early Branch Forwarding)
 *
 * @details
 * This module resolves data hazards by forwarding results from older pipeline stages
 * to younger consuming stages. It supports:
 *   - ALU operands in the Execute stage (ForwardA, ForwardB)
 *   - Store data in the Execute stage (ForwardStore)
 *   - Early branch operands in the Decode stage (ForwardBranchA, ForwardBranchB)
 *   - CSR read data in the Execute stage (ForwardCSR)
 *
 * The forwarding logic prioritizes the newest producer (EX/MEM over MEM/WB),
 * and distinguishes between different data sources (ALU result, load data, CSR read data)
 * using extended encoding schemes where necessary.
 */

import rv32_types_pkg::*;

module forwarding_unit (
    //----------------------------------------------------------------------
    // Destination Register Indices from Pipeline Stages
    //----------------------------------------------------------------------
    input  logic [4:0]    ex_rd,   
    input  logic [4:0]    mem_rd,  
    input  logic [4:0]    wb_rd,   

    //----------------------------------------------------------------------
    // Source Register Indices
    //----------------------------------------------------------------------
    input  logic [4:0]    ex_rs1,  
    input  logic [4:0]    ex_rs2,  
    input  logic [4:0]    id_rs1,  
    input  logic [4:0]    id_rs2,  

    //----------------------------------------------------------------------
    // Control Signals from each pipeline stage
    //----------------------------------------------------------------------
    input ctrl_signals_t  id_ctrl,   
    input ctrl_signals_t  ex_ctrl,   
    input ctrl_signals_t  mem_ctrl,  
    input ctrl_signals_t  wb_ctrl,   

    //----------------------------------------------------------------------
    // Forwarding Selection Outputs
    //----------------------------------------------------------------------
    output logic [1:0]    ForwardA,        
    output logic [1:0]    ForwardB,        
    output logic [1:0]    ForwardStore,    
    output logic [2:0]    ForwardBranchA,
    output logic [2:0]    ForwardBranchB,
    output logic [2:0]    ForwardJump,
    output logic [1:0]    ForwardCSR       
);

    //======================================================================
    // Forwarding MUX Encoding Schemes
    //======================================================================
    // For ALU / Store / CSR (2-bit):
    //   00 : No forwarding (use Register File)
    //   01 : Forward from EX/MEM stage – CSR read data
    //   10 : Forward from EX/MEM stage – ALU result (or other non-CSR data)
    //   11 : Forward from MEM/WB stage
    //
    // For Branch (3-bit):
    //   000 : No forwarding (use Register File)
    //   001 : Forward from EX stage – CSR read data
    //   010 : Forward from EX stage – ALU result
    //   011 : Forward from MEM stage – Load data (memory read)
    //   100 : Forward from MEM stage – CSR read data
    //   101 : Forward from MEM stage – ALU result (or other non-load, non-CSR data)
    //======================================================================

    /**
     * @brief Calculates forwarding selection for ALU operands and store data in EX stage.
     *
     * @param rs Source register address to check for hazards.
     * @return 2-bit forwarding control code according to the ALU/Store encoding.
     *
     * Priority:
     *   1. EX/MEM stage (newest producer) – if the instruction writes to the same register.
     *      - If it is a CSR read instruction, select CSR data (01).
     *      - Otherwise, select ALU result (10).
     *   2. MEM/WB stage (older producer) – if EX/MEM does not match.
     *      - Select WB data (11).
     */
    function automatic logic [1:0] calc_forward_alu(
        input logic [4:0] rs
    );
        begin
            calc_forward_alu = 2'b00;

            // Never forward x0 (hardwired to zero).
            if (rs != 5'd0) begin
                // EX/MEM stage match: check if the instruction in MEM stage writes to rs
                // and it is a CSR read (i.e., data comes from CSR read port).
                if (mem_ctrl.wb.RegWrite && (mem_rd != 5'd0) && (mem_rd == rs) && mem_ctrl.csr.Read) begin
                    calc_forward_alu = 2'b01;
                end
                // EX/MEM stage match: general register write (ALU result, etc.)
                else if (mem_ctrl.wb.RegWrite && (mem_rd != 5'd0) && (mem_rd == rs)) begin
                    calc_forward_alu = 2'b10;
                end
                // MEM/WB stage match: only if EX/MEM does not match.
                else if (wb_ctrl.wb.RegWrite && (wb_rd != 5'd0) && (wb_rd == rs)) begin
                    calc_forward_alu = 2'b11;
                end
            end
        end
    endfunction

    /**
     * @brief Calculates forwarding selection for early branch operands in ID stage.
     *
     * @param rs Source register address to check for hazards.
     * @return 3-bit forwarding control code according to the Branch encoding.
     *
     * Priority:
     *   1. EX stage (newest producer) – if the instruction currently in EX writes to rs.
     *      - If it is a CSR read, select CSR data (001).
     *      - Otherwise, select ALU result (010).
     *   2. MEM stage – if EX does not match and the instruction in MEM writes to rs.
     *      - If it is a load (memory read), select load data (011).
     *      - If it is a CSR read, select CSR data (100).
     *      - Otherwise, select ALU result (101).
     */
    function automatic logic [2:0] calc_forward_branch(
        input logic [4:0] rs
    );
        begin
            calc_forward_branch = 3'b000;

            if (rs != 5'd0) begin
                // EX stage match: CSR read
                if (ex_ctrl.wb.RegWrite && ex_ctrl.csr.Read && (ex_rd != 5'd0) && (ex_rd == rs)) begin
                    calc_forward_branch = 3'b001;
                end
                // EX stage match: general register write (ALU result)
                else if (ex_ctrl.wb.RegWrite && (ex_rd != 5'd0) && (ex_rd == rs)) begin
                    calc_forward_branch = 3'b010;
                end
                // MEM stage match: load instruction (memory read)
                else if (mem_ctrl.wb.RegWrite && mem_ctrl.mem.MemRead && (mem_rd != 5'd0) && (mem_rd == rs)) begin
                    calc_forward_branch = 3'b011;
                end
                // MEM stage match: CSR read
                else if (mem_ctrl.wb.RegWrite && mem_ctrl.csr.Read && (mem_rd != 5'd0) && (mem_rd == rs)) begin
                    calc_forward_branch = 3'b100;
                end
                // MEM stage match: general register write (ALU result, non-load)
                else if (mem_ctrl.wb.RegWrite && (mem_rd != 5'd0) && (mem_rd == rs)) begin
                    calc_forward_branch = 3'b101;
                end
            end
        end
    endfunction

    /**
     * @brief Calculates forwarding selection for CSR read data in EX stage.
     *
     * @param rs Source register address to check for hazards.
     * @return 2-bit forwarding control code (same encoding as ALU/Store).
     *
     * This is used when the current EX instruction reads a CSR and the CSR
     * address matches a destination register of an older instruction.
     * The forwarding paths are:
     *   - EX/MEM stage with CSR read (01) or ALU result (10)
     *   - MEM/WB stage (11)
     */
    function automatic logic [1:0] calc_forward_csr(
        input logic [4:0] rs
    );
        begin
            calc_forward_csr = 2'b00;

            if (rs != 5'd0) begin
                // EX/MEM stage match: CSR read
                if (mem_ctrl.wb.RegWrite && (mem_rd != 5'd0) && (mem_rd == rs) && mem_ctrl.csr.Read) begin
                    calc_forward_csr = 2'b01;
                end
                // EX/MEM stage match: general register write (ALU result)
                else if (mem_ctrl.wb.RegWrite && (mem_rd != 5'd0) && (mem_rd == rs)) begin
                    calc_forward_csr = 2'b10;
                end
                // MEM/WB stage match
                else if (wb_ctrl.wb.RegWrite && (wb_rd != 5'd0) && (wb_rd == rs)) begin
                    calc_forward_csr = 2'b11;
                end
            end
        end
    endfunction

    //======================================================================
    // Combinational Forwarding Decision Logic
    //======================================================================
    always_comb begin
        // Temporary variable to hold RS2 forwarding for potential reuse
        logic [1:0] rs2_forward;

        // Default: no forwarding (use register file)
        ForwardA       = 2'b00;
        ForwardB       = 2'b00;
        ForwardStore   = 2'b00;
        ForwardBranchA = 3'b000;
        ForwardBranchB = 3'b000;
        ForwardJump    = 3'b000;
        ForwardCSR     = 2'b00;

        //------------------------------------------------------------------
        // Execute Stage Forwarding for ALU and Store
        //------------------------------------------------------------------
        // ALU operand A: only forward if the current EX instruction uses rs1.
        if (ex_ctrl.id.UseRs1)
            ForwardA = calc_forward_alu(ex_rs1);

        // Compute RS2 forwarding once; it may be used for both ALU B and Store data.
        rs2_forward = calc_forward_alu(ex_rs2);

        // ALU operand B: forward if the current EX instruction uses rs2 and is not a store
        // (stores use the same value for data but do not need it at the ALU input).
        if (ex_ctrl.id.UseRs2 && !ex_ctrl.mem.MemWrite)
            ForwardB = rs2_forward;

        // Store data: forward the RS2 value when the current instruction is a store.
        // Note: store instructions still need the forwarded data for writing to memory.
        if (ex_ctrl.mem.MemWrite)
            ForwardStore = rs2_forward;

        //------------------------------------------------------------------
        // Decode Stage Forwarding for Early Branch Evaluation
        //------------------------------------------------------------------
        // Branch operands are forwarded from EX or MEM stages to the ID stage
        // to allow early branch resolution without stalling.
        if (id_ctrl.id.UseRs1)
            ForwardBranchA = calc_forward_branch(id_rs1);

        if (id_ctrl.id.UseRs2)
            ForwardBranchB = calc_forward_branch(id_rs2);

        ForwardJump = calc_forward_branch(id_rs1);

        //------------------------------------------------------------------
        // Execute Stage Forwarding for CSR Read Data
        //------------------------------------------------------------------
        // If the EX instruction reads a CSR (indicated by ex_ctrl.id.UseRs1?),
        // we forward the CSR data from older stages if a hazard exists.
        // Note: The condition uses ex_ctrl.id.UseRs1 as a proxy; in a real design,
        // a dedicated control signal for CSR read should be used.
        if (ex_ctrl.id.UseRs1)
            ForwardCSR = calc_forward_csr(ex_rs1);
    end

endmodule
