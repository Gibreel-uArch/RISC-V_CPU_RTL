/**
 * @file hazard_detection_unit.sv
 * @brief RISC-V Pipeline Hazard Detection Unit
 * @details Detects structural, data (load-use hazards), and control hazards.
 *          Generates pipeline stalls, PC freezes, and flush signals to maintain correct execution order.
 */

import rv32_types_pkg::*;

module hazard_detection_unit (
    // Source and Destination Register Indices
    input  logic [4:0]    id_rs1,        // Source register 1 of instruction in ID stage
    input  logic [4:0]    id_rs2,        // Source register 2 of instruction in ID stage
    input  logic [4:0]    ex_rd,         // Destination register of instruction in ID/EX stage
  
    // Control Structures
    input  ctrl_signals_t id_ctrl,       // Decoded control signals for instruction in ID stage
    input  mem_ctrl_t     ex_mem_ctrl,   // Memory stage control signals of instruction in ID/EX stage
    
    // Control Hazard Trigger
    input  logic          take_branch,   // Branch taken signal from branch unit

    // Hazard Mitigation Outputs
    output logic          id_ex_flush,   // Inserts a bubble into the ID/EX register
    output logic          if_id_flush,   // Flushes the IF/ID register on control flow changes
    output logic          stall,         // Freezes the IF/ID pipeline register
    output logic          stall_pc,      // Freezes the Program Counter (PC)
    output logic          stall_branch   // Freezes the branch evaluation unit during stalls
);

    // Internal signal to evaluate any control transfer (branch taken, unconditional jump, or register jump)
    logic control_flush;
    assign control_flush = take_branch || id_ctrl.id.JumpImm || id_ctrl.id.JumpReg;

    always_comb begin
        // --- Default Safe States (No Hazards) ---
        stall        = 1'b0;
        stall_pc     = 1'b0;
        stall_branch = 1'b0;
        id_ex_flush  = 1'b0;
        if_id_flush  = 1'b0;

        //--------------------------------------------------------------------------
        // Load-Use Data Hazard Detection & Mitigation
        //--------------------------------------------------------------------------
        /**
         * @details If the instruction currently in the ID/EX stage is a load operation (MemRead)
         *          and its destination register (ex_rd) matches either source register (id_rs1/id_rs2)
         *          demanded by the instruction in the ID stage, a load-use hazard occurs.
         *          This cannot be bypassed via forwarding alone because the data is not yet read from memory.
         *          Action: Stall PC and IF/ID, and insert a bubble into ID/EX.
         */
        if (ex_mem_ctrl.MemRead && (ex_rd != 5'd0)) begin
            if ((id_ctrl.id.UseRs1 && (id_rs1 == ex_rd)) ||
                (id_ctrl.id.UseRs2 && (id_rs2 == ex_rd))) begin
                
                stall        = 1'b1;
                stall_pc     = 1'b1;
                
                // If a branch or register jump is stalled in ID, stall the branch unit evaluation;
                // otherwise, insert a structural bubble into ID/EX.
                if (id_ctrl.id.Branch || id_ctrl.id.JumpReg) begin
                    stall_branch = 1'b1;
                end else begin
                    id_ex_flush  = 1'b1; // Insert pipeline bubble
                end
            end
        end
        
        //--------------------------------------------------------------------------
        // Control Hazard Flush Handling
        //--------------------------------------------------------------------------
        /**
         * @details Triggered whenever a branch is taken or a jump instruction executes.
         *          Flushes the younger instruction residing in the IF/ID stage to discard 
         *          speculatively fetched instructions down the wrong path.
         */
        if (control_flush) begin
            if_id_flush = 1'b1;
        end

    end

endmodule
