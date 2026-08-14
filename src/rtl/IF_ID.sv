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
    
    // Pipeline Control Signals
    input  logic        stall,
    input  logic        if_id_flush,

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
            // Asynchronous active-low reset: clear all pipeline registers
            id_pc_current    <= 32'b0;
            id_pc_plus_4     <= 32'b0;
            id_instruction   <= 32'b0;
        end 
        else if (if_id_flush) begin
            // Synchronous flush: insert a bubble (NOP instruction: ADDI x0, x0, 0 or 32'h00000013)
            id_pc_current    <= 32'b0;
            id_pc_plus_4     <= 32'b0;
            id_instruction   <= 32'h00000013; // Standard RISC-V NOP instruction
        end 
        else if (!stall) begin
            // Normal operation: capture incoming values when pipeline is not stalled
            id_pc_current    <= if_pc_current;
            id_pc_plus_4     <= if_pc_plus_4;
            id_instruction   <= if_instruction;
        end
        // Note: If 'stall' is asserted, registers implicitly hold their current values (no assignment needed)
    end

endmodule
