/**
 * @file instruction_memory.sv
 * @brief Instruction Memory (ROM)
 * @details Asynchronous read memory block initialized via a hex program file.
 *          Word-aligned addressing (ignores lower 2 bits).
 */

import rv32_types_pkg::*;

module instruction_memory (
    input  logic         clk,
    input  logic [31:0]  mem_addr,
    input  logic         mem_valid,

    output logic [127:0] mem_data,
    output logic         mem_resp_valid
);

    // 16K 32-bit words instruction memory array (64 KB capacity)
    logic [31:0] mem [0:16383];

    string hex_file;
    initial begin
        if ($value$plusargs("HEX_FILE=%s", hex_file)) begin
            $readmemh(hex_file, mem);
        end else begin
            $display("Error: No HEX file specified!");
            $finish;
        end
    end

    // 1. Calculate base block word index (14 bits)
    logic [13:0] base_block_idx;
    assign base_block_idx = mem_addr[15:4];

    // 2. Extract 4 words (32-bit each) for the 128-bit block
    logic [31:0] word1, word2, word3, word4;

    assign word1 = mem[{base_block_idx, 2'b00}];
    assign word2 = mem[{base_block_idx, 2'b01}];
    assign word3 = mem[{base_block_idx, 2'b10}];
    assign word4 = mem[{base_block_idx, 2'b11}];

    // 3. Sequential response logic
    always_ff @(posedge clk) begin
        if (mem_valid) begin
            mem_data       <= {word4, word3, word2, word1};
            mem_resp_valid <= 1'b1;
        end else begin
            mem_resp_valid <= 1'b0;
        end
    end

endmodule
