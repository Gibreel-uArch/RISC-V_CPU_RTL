/**
 * @file EX_MEM.sv
 * @brief Execute to Memory (EX/MEM) Pipeline Register Stage
 * @details This module registers data and control signals passing from 
 *          the Execute (EX) stage to the Memory (MEM) stage. 
 *          It handles asynchronous active-low reset and normal pipeline progression.
 */

import rv32_types_pkg::*;

module EX_MEM (
    // Clock and Reset
    input  logic          clk, 
    input  logic          rst_n,

    // Data & Function Fields (Input from EX Stage)
    input  logic [2:0]    ex_func3,
    input  logic [4:0]    ex_rd,
    input  logic [31:0]   ex_pc_plus_4,
    input  logic [31:0]   ex_alu_result,
    input  logic [31:0]   ex_store_data,
    
    // Control Signals Input
    input  mem_wb_ctrl_t  ex_mem_wb_ctrl,

    // Data & Function Fields (Output to MEM Stage)
    output logic [2:0]    mem_func3,
    output logic [4:0]    mem_rd,
    output logic [31:0]   mem_pc_plus_4,
    output logic [31:0]   mem_alu_result,
    output logic [31:0]   mem_store_data,
    
    // Control Signals Output
    output mem_ctrl_t     mem_ctrl,
    output wb_ctrl_t      mem_wb_ctrl
);

    always_ff @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin
            // Asynchronous active-low reset: clear all pipeline registers and control signals
            mem_func3      <= 3'b0;
            mem_rd         <= 5'b0;
            mem_pc_plus_4  <= 32'b0;
            mem_alu_result <= 32'b0;
            mem_store_data <= 32'b0;
            mem_ctrl       <= '0;
            mem_wb_ctrl    <= '0;
        end else begin
            // Normal pipeline operation: propagate EX signals to MEM stage
            mem_func3      <= ex_func3;
            mem_rd         <= ex_rd;
            mem_pc_plus_4  <= ex_pc_plus_4;
            mem_alu_result <= ex_alu_result;
            mem_store_data <= ex_store_data;
            mem_ctrl       <= ex_mem_wb_ctrl.mem;
            mem_wb_ctrl    <= ex_mem_wb_ctrl.wb;
        end
    end

endmodule
