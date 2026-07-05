// ============================================
// Top Module - Simple Counter for Testing
// File: src/rtl/top.sv
// ============================================
// Description: 4-bit up-counter with reset
// Used as initial DUT to verify toolchain
// ============================================

module top (
    input  logic        clk,        // Clock input
    input  logic        rst_n,      // Active-low reset
    input  logic        test_mode,  // Test mode (unused)
    output logic [3:0]  count,      // 4-bit counter output
    output logic [31:0] pc,         // Program counter (dummy)
    output logic [31:0] instruction // Instruction (dummy)
);
    
    // Counter logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 4'b0000;
        end else begin
            count <= count + 1'b1;
        end
    end
    
    // Dummy outputs
    assign pc = 32'h0000_0000;
    assign instruction = 32'h0000_0013;  // NOP instruction
    
endmodule
