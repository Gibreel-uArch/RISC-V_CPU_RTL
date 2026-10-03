/**
 * @file registers_file.sv
 * @brief RISC-V 32x32-Bit General Purpose Register File
 * @details Implements dual asynchronous read ports with built-in combinational bypass 
 *          (internal forwarding for write-through scenarios) and a single synchronous write port.
 *          Register x0 is hardwired to zero.
 */

import rv32_types_pkg::*;

module registers_file (
    // Clock and Reset
    input  logic        clk,
    input  logic        rst_n,
    
    // Write Control & Address/Data
    input  logic        RegWrite,
    input  logic [4:0]  rd,
    input  logic [31:0] WriteData,
    
    // Read Addresses
    input  logic [4:0]  rs1,
    input  logic [4:0]  rs2,
    
    // Read Data Outputs
    output logic [31:0] ReadData1,
    output logic [31:0] ReadData2
);

    // 32 x 32-bit register array
    logic [31:0] RegFile [0:31];

    //----------------------------------------------------------------------
    // Combinational Read Logic with Internal Bypass (Write-Through Forwarding)
    //----------------------------------------------------------------------
    always_comb begin
        // --- Read Port 1 (rs1) Evaluation ---
        if (rs1 == 5'b0) begin
            ReadData1 = 32'b0; // x0 is hardwired to zero
        end
        else if (RegWrite && (rd != 5'b0) && (rd == rs1)) begin
            ReadData1 = WriteData; // Internal bypass: forward new write data if reading destination register simultaneously
        end
        else begin
            ReadData1 = RegFile[rs1]; // Standard register file read
        end

        // --- Read Port 2 (rs2) Evaluation ---
        if (rs2 == 5'b0) begin
            ReadData2 = 32'b0; // x0 is hardwired to zero
        end
        else if (RegWrite && (rd != 5'b0) && (rd == rs2)) begin
            ReadData2 = WriteData; // Internal bypass: forward new write data if reading destination register simultaneously
        end
        else begin
            ReadData2 = RegFile[rs2]; // Standard register file read
        end
    end

    //----------------------------------------------------------------------
    // Sequential Write Logic
    //----------------------------------------------------------------------
    /**
     * @brief Updates register array synchronously on the positive clock edge.
     * @details Clears all registers on active-low asynchronous reset. 
     *          Prevents writing to hardwired zero register (x0).
     */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) begin
                RegFile[i] <= 32'b0;
            end
        end
        else if (RegWrite && (rd != 5'b0)) begin
            RegFile[rd] <= WriteData;
        end
    end

endmodule
