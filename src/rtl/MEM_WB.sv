/**
 * @file MEM_WB.sv
 * @brief Memory to Writeback (MEM/WB) Pipeline Register Stage
 * @details This module registers data and control signals passing from 
 *          the Memory Access (MEM) stage to the Writeback (WB) stage.
 *          It supports asynchronous active-low reset.
 */

import rv32_types_pkg::*;

module MEM_WB (
    // Clock and Reset
    input  logic                 clk, 
    input  logic                 rst_n,
    
    // Data & Control Inputs from MEM Stage
    input  logic [ 4:0]          mem_rd,
    input  logic [31:0]          mem_pc_plus_4,
    input  logic [31:0]          mem_alu_result,
    input  logic [31:0]          mem_memory_data, 
    input  wb_ctrl_t             mem_wb_ctrl,

    // Data & Control Outputs to WB Stage
    output logic [ 4:0]          wb_rd,
    output logic [31:0]          wb_pc_plus_4,
    output logic [31:0]          wb_alu_result,
    output logic [31:0]          wb_memory_data, 
    output wb_ctrl_t             wb_ctrl
);

    always_ff @(posedge clk or negedge rst_n) begin  
        if (!rst_n) begin
            // Asynchronous active-low reset: clear all pipeline registers
            wb_rd           <= 5'b0;
            wb_pc_plus_4    <= 32'b0;
            wb_alu_result   <= 32'b0;
            wb_memory_data  <= 32'b0;
            wb_ctrl         <= '0; 
        end 
        else begin
            // Normal pipeline operation: propagate inputs to outputs
            wb_rd           <= mem_rd;
            wb_pc_plus_4    <= mem_pc_plus_4;
            wb_alu_result   <= mem_alu_result;
            wb_memory_data  <= mem_memory_data;
            wb_ctrl         <= mem_wb_ctrl; 
        end
    end

endmodule
