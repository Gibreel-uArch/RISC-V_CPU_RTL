/**
 * @file instruction_memory.sv
 * @brief Instruction Memory (ROM)
 * @details Asynchronous read memory block initialized via a hex program file.
 *          Word-aligned addressing (ignores lower 2 bits).
 */

import rv32_types_pkg::*;

module instruction_memory (
    input  logic [31:0] address,
    output logic [31:0] instruction
);

    // 16K 32-bit words instruction memory array (64 KB capacity)
    logic [31:0] mem [0:16383];

    initial begin
        $readmemh("program.hex", mem);
    end

    // Asynchronous read with word alignment (discarding byte offsets bits [1:0])
    assign instruction = mem[address[31:2]];

endmodule
