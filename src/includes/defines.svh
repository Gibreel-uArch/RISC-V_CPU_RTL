// defines.svh
`ifndef __DEFINES_SVH__
`define __DEFINES_SVH__

// عرض البيانات (32-bit RISC-V)
`define DATA_WIDTH 32
`define ADDR_WIDTH 32

// عمق الذاكرة (عدد الكلمات)
`define MEM_DEPTH 1024

// عمليات ALU (ستضيف عليها لاحقاً)
`define ALU_ADD  3'b000
`define ALU_SUB  3'b001
`define ALU_AND  3'b010
`define ALU_OR   3'b011
`define ALU_SLT  3'b100

`endif
