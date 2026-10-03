/**
 * @file hazard_detection_unit.sv
 * @brief RISC-V Pipeline Hazard Detection Unit
 * @details Detects structural, data (load-use hazards), and control hazards.
 *          Generates pipeline stalls, PC freezes, and flush signals to maintain correct execution order.
 */

import rv32_types_pkg::*;

module hazard_detection_unit (
    // Source and Destination Register Indices
    input  logic [4:0]        id_rs1,        // Source register 1 in ID stage
    input  logic [4:0]        id_rs2,        // Source register 2 in ID stage
    input  logic [4:0]        ex_rd,         // Destination register in ID/EX stage
  
    // Control Structures
    input  ctrl_signals_t     id_ctrl,       // Decoded control signals in ID
    input  ctrl_signals_t     ex_ctrl,       // Control signals in ID/EX
    
    // Control Hazard Trigger
    input  logic              take_branch,   // Branch taken signal from branch unit
    input  logic              icache_miss,   // Miss signal from instruction cache
    input  logic              dcache_miss,   // Miss signal from data cache

    // Hazard Mitigation Outputs
    output logic              if_id_branch_flush, // Flushes IF/ID register
    output logic              if_id_stall,   // Freezes IF/ID pipeline register
    output logic              pc_stall,      // Freezes Program Counter
    output logic              branch_stall,  // Freezes branch evaluation unit
    output logic              id_ex_stall,   // Freezes ID/EX pipeline register
    output logic              ex_mem_stall,  // Freezes EX/MEM pipeline register
    output logic              mem_wb_stall,  // Freezes MEM/WB pipeline register
    output logic              id_ex_flush    // Flushes ID/EX register
);

    // Internal signals for cleaner logic
    logic control_flush;
    logic load_use_hazard;

    // 1. Control Hazard Trigger (Branch Taken or Jumps)
    assign control_flush = take_branch || id_ctrl.id.JumpImm || id_ctrl.id.JumpReg;

    // 2. Data Hazard Trigger (Load-Use)
    assign load_use_hazard = ex_ctrl.mem.MemRead && (ex_rd != 5'd0) &&
                             ((id_ctrl.id.UseRs1 && (id_rs1 == ex_rd)) ||
                              (id_ctrl.id.UseRs2 && (id_rs2 == ex_rd)));

    always_comb begin
        // --- 0. Default States (No Hazards - Let it flow) ---
        pc_stall           = 1'b0;
        branch_stall       = 1'b0;
        if_id_stall        = 1'b0;
        id_ex_stall        = 1'b0;
        ex_mem_stall       = 1'b0;
        mem_wb_stall       = 1'b0;
        
        id_ex_flush        = 1'b0;
        if_id_branch_flush = 1'b0;

        // =================================================================
        // THE PRIORITY MATRIX (Highest to Lowest)
        // =================================================================

        // --- Priority 1: Data Cache Miss (Absolute Freeze) ---
        // A memory operation is taking time. The whole pipeline must stop.
        if (dcache_miss) begin
            pc_stall     = 1'b1; 
            if_id_stall  = 1'b1; 
            id_ex_stall  = 1'b1;
            ex_mem_stall = 1'b1;
            mem_wb_stall = 1'b1; 
            branch_stall = 1'b1; // Prevent branch unit from firing while frozen
        end

        // --- Priority 2: Load-Use Data Hazard ---
        // ID stage needs data from a Load in EX stage. Need to wait 1 cycle.
        else if (load_use_hazard) begin
            pc_stall     = 1'b1; // Stop fetching new instructions
            if_id_stall  = 1'b1; // Keep current instruction in ID
            id_ex_flush  = 1'b1; // Insert a bubble into EX stage
            
            // If the stalled instruction is a branch/jump, freeze the branch unit too
            if (id_ctrl.id.Branch || id_ctrl.id.JumpReg) begin
                branch_stall = 1'b1;
            end
        end

        // --- Priority 3: Control Hazard (Branch Taken / Jump) ---
        // We jumped to a new address. The instruction just fetched is wrong.
        else if (control_flush) begin
            // PC is NOT stalled (It needs to update to the branch target)
            if_id_branch_flush = 1'b1; // Kill the wrong instruction in IF/ID
        end

        // --- Priority 4: Instruction Cache Miss ---
        // Fetching is slow. Freeze PC, but let older instructions finish.
        else if (icache_miss) begin
            pc_stall           = 1'b1; // Wait for memory
            
            // WE FLUSH IF/ID HERE, WE DO NOT STALL IT!
            // If we stall IF/ID, the old instruction stays in ID and executes repeatedly.
            // By flushing it, we inject NOPs (bubbles) into ID until the cache is ready.
            if_id_branch_flush = 1'b1; 
            
            branch_stall       = 1'b1; // Prevent phantom branch evaluations from NOPs
        end

    end

endmodule
