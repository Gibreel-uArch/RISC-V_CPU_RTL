/**
 * @file ID_EX.sv
 * @brief Decode to Execute (ID/EX) Pipeline Register Stage
 * @details This module registers all control and data signals passing from 
 *          the Instruction Decode (ID) stage to the Execute (EX) stage. 
 *          It supports asynchronous active-low reset and pipeline flushing (bubble insertion).
 */

import rv32_types_pkg::*;

module ID_EX (
    // Clock and Reset
    input  logic                 clk, 
    input  logic                 rst_n,
    input  logic                 id_ex_flush,

    // Instruction Fields & Operands (Input from ID Stage)
    input  logic [ 2:0]          id_func3,
    input  logic [ 6:0]          id_func7,
    input  logic [ 4:0]          id_rs1,
    input  logic [ 4:0]          id_rs2,
    input  logic [ 4:0]          id_rd,
    input  logic [31:0]          id_pc_plus_4,
    input  logic [31:0]          id_pc_current,
    input  logic [31:0]          id_imm,
    input  logic [31:0]          id_src1,
    input  logic [31:0]          id_src2,
    
    // Control Signals Input
    input  ctrl_signals_t        id_ctrl,

    // Pipeline Outputs to EX Stage
    output logic [ 2:0]          ex_func3,
    output logic [ 6:0]          ex_func7,
    output logic [ 4:0]          ex_rs1,
    output logic [ 4:0]          ex_rs2,
    output logic [ 4:0]          ex_rd,
    output logic [31:0]          ex_pc_current,
    output logic [31:0]          ex_pc_plus_4,
    output logic [31:0]          ex_src1,
    output logic [31:0]          ex_src2,
    output logic [31:0]          ex_imm,
    
    // Control Signals Output
    output ctrl_signals_t        ex_id_ctrl,
    output ex_ctrl_t             ex_ctrl,
    output mem_wb_ctrl_t         ex_mem_wb_ctrl
);

    always_ff @(posedge clk or negedge rst_n) begin  
        if (!rst_n) begin
            // Asynchronous active-low reset: clear all pipeline registers
            ex_func3       <= 3'b0;
            ex_func7       <= 7'b0;
            ex_rd          <= 5'b0;
            ex_rs1         <= 5'b0;
            ex_rs2         <= 5'b0;
            ex_pc_current  <= 32'b0;
            ex_pc_plus_4   <= 32'b0;
            ex_src1        <= 32'b0;
            ex_src2        <= 32'b0;
            ex_imm         <= 32'b0;
            ex_id_ctrl     <= '0;
            ex_ctrl        <= '0;
            ex_mem_wb_ctrl <= '0;
        end 
        else if (id_ex_flush) begin
            // Synchronous flush: insert a bubble (NOP) by zeroing out control and data fields
            ex_func3       <= 3'b0;
            ex_func7       <= 7'b0;
            ex_rs1         <= 5'b0;
            ex_rs2         <= 5'b0;
            ex_rd          <= 5'b0;
            ex_pc_current  <= 32'b0;
            ex_pc_plus_4   <= 32'b0;
            ex_src1        <= 32'b0;
            ex_src2        <= 32'b0;
            ex_imm         <= 32'b0;
            ex_id_ctrl     <= '0;
            ex_ctrl        <= '0; // Neutralize execution control signals
            ex_mem_wb_ctrl <= '0; // Neutralize memory/writeback control signals
        end 
        else begin
            // Normal pipeline operation: propagate inputs to outputs
            ex_func3       <= id_func3;
            ex_func7       <= id_func7;
            ex_rs1         <= id_rs1;
            ex_rs2         <= id_rs2;
            ex_rd          <= id_rd;
            ex_pc_current  <= id_pc_current;
            ex_pc_plus_4   <= id_pc_plus_4;
            ex_src1        <= id_src1;
            ex_src2        <= id_src2;
            ex_imm         <= id_imm;
            ex_ctrl        <= id_ctrl.ex;
            ex_id_ctrl     <= id_ctrl;
            ex_mem_wb_ctrl.mem <= id_ctrl.mem;
            ex_mem_wb_ctrl.wb  <= id_ctrl.wb;
        end
    end

endmodule
