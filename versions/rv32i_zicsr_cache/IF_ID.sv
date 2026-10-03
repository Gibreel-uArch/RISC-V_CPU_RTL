/**
 * @file IF_ID.sv
 * @brief Instruction Fetch to Instruction Decode (IF/ID) Pipeline Register Stage
 * @details This module registers the instruction and associated Program Counter (PC) 
 *          values passing from the Fetch (IF) stage to the Decode (ID) stage.
 *          It supports synchronous reset, pipeline flushing (inserting a NOP bubble), 
 *          and stalling (holding the previous state during hazard conditions).
 */

module IF_ID (
    // Clock and Reset
    input  logic        clk,
    input  logic        rst_n,

    // Control Signals
    input  logic        if_id_stall,
    input  logic        if_id_branch_flush,
    input  logic        if_id_trap_flush,

    // Inputs from IF Stage
    input  logic [31:0] if_instruction,
    input  logic [31:0] if_pc_plus_4,
    input  logic [31:0] if_pc_current,

    // Outputs to ID Stage
    output logic [31:0] id_instruction,
    output logic [31:0] id_pc_plus_4,
    output logic [31:0] id_pc_current
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 1. Reset - highest priority
            id_pc_current   <= 32'b0;
            id_pc_plus_4    <= 32'b0;
            id_instruction  <= 32'b0;
        end
        else if (if_id_trap_flush) begin
            // 2. Trap/Exception Flush - overrides stall immediately
            id_pc_current   <= 32'b0;
            id_pc_plus_4    <= 32'b0;
            id_instruction  <= 32'h00000013; // NOP
        end
        else if (!if_id_stall) begin
            // 3. Normal update (only allowed when no cache stall)
            if (if_id_branch_flush) begin
                // Branch/Jump flush
                id_pc_current   <= 32'b0;
                id_pc_plus_4    <= 32'b0;
                id_instruction  <= 32'h00000013; // NOP
            end else begin
                // Normal instruction fetch
                id_pc_current   <= if_pc_current;
                id_pc_plus_4    <= if_pc_plus_4;
                id_instruction  <= if_instruction;
            end
        end
        // 4. If if_id_stall is asserted and no trap_flush: register holds its value
    end

endmodule
