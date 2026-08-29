/**
 * @file pc_unit.sv
 * @brief Program Counter (PC) Generation and Control Unit
 * @details Handles PC updates based on stalls, branches, and jumps (JAL, JALR).
 *          Applies asynchronous active-low reset.
 */

import rv32_types_pkg::*;

module pc_unit (
    // Clock and Reset
    input  logic        clk, 
    input  logic        rst_n,
    
    // Control Signals
    input  logic        stall_pc,
    output logic        trap_jump,
    output logic        mret_jump,
    input  logic        take_branch,
    input  logic        JumpImm,
    input  logic        JumpReg,
    
    // Target Addresses & Operands
    input  logic [31:0] trap_next_pc,
    input  logic [31:0] instruction_address,
    input  logic [31:0] ReadData1,
    input  logic [31:0] imm,
    
    // Outputs
    output logic [31:0] pc_current,   
    output logic [31:0] pc_plus_4     
);

    logic [31:0] pc_next;

    // Calculate sequential next PC address (PC + 4)
    assign pc_plus_4 = pc_current + 32'd4;
    
    /**
     * @brief Combinational next-PC selection logic
     * @details Priority: Stall > Branch/Jump-Immediate > Jump-Register > Sequential (PC + 4)
     */
    always_comb begin
        if (stall_pc) begin 
            pc_next = pc_current;                // Hold current PC on pipeline stall
        end
        else if (trap_jump) begin 
            pc_next = trap_next_pc;              // jump to trap handling address
        end
        else if (mret_jump) begin
            pc_next = trap_next_pc;              // jump to main program where it stops
        end
        else if (take_branch || JumpImm) begin
            pc_next = instruction_address + imm; // Branch or JAL target address
        end
        else if (JumpReg) begin
            pc_next = ReadData1 + imm;           // JALR target address
        end
        else begin
            pc_next = pc_plus_4;                 // Default sequential execution
        end
    end

    /**
     * @brief Sequential PC Register
     * @details Updates pc_current on clock edge or clears to 0 on active-low reset.
     */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_current <= 32'b0;
        end else begin
            pc_current <= pc_next;
        end
    end

endmodule
