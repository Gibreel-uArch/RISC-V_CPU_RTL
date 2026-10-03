/**
 * @file memory.sv
 * @brief RISC-V Data Memory Unit (Data RAM)
 * @details Implements byte-, halfword-, and word-addressable data memory operations 
 *          supporting load (LB, LBU, LH, LHU, LW) with sign/zero extension 
 *          and store (SB, SH, SW) accesses.
 */

import rv32_types_pkg::*;

module block_memory (
    input  logic         clk,
    
    // Interface with D-Cache
    input  logic         mem_req,
    input  logic         mem_rnw,    // 1=Read, 0=Write
    input  logic [31:0]  mem_addr,
    input  logic [127:0] mem_wdata,
    output logic [127:0] mem_rdata,
    output logic         mem_ready
);

    // 16K 32-bit words (Same capacity as before, 64 KB)
    logic [31:0] memory [0:16383];

    // Word Address (ignoring byte offset, reading 4 words at a time)
    logic [13:0] word_idx;
    assign word_idx = mem_addr[15:2]; 

    // Simple state machine to simulate memory delay
    logic active;
    
    always_ff @(posedge clk) begin
        if (mem_req && !active) begin
            active <= 1'b1;
            mem_ready <= 1'b0; // Wait 1 cycle
        end 
        else if (mem_req && active) begin
            mem_ready <= 1'b1; // Ready on next cycle
            
            // Execute Write-Back from Cache
            if (!mem_rnw) begin
                memory[word_idx]   <= mem_wdata[31:0];
                memory[word_idx+1] <= mem_wdata[63:32];
                memory[word_idx+2] <= mem_wdata[95:64];
                memory[word_idx+3] <= mem_wdata[127:96];
            end
            
            active <= 1'b0; // Reset for next transaction
        end 
        else begin
            mem_ready <= 1'b0;
            active <= 1'b0;
        end
    end

    // Combinational Read (to feed Cache on ALLOCATE)
    assign mem_rdata = {
        memory[word_idx+3],
        memory[word_idx+2],
        memory[word_idx+1],
        memory[word_idx]
    };

endmodule
