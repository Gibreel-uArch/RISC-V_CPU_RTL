/**
 * @file memory.sv
 * @brief RISC-V Data Memory Unit (Data RAM)
 * @details Implements byte-, halfword-, and word-addressable data memory operations 
 *          supporting load (LB, LBU, LH, LHU, LW) with sign/zero extension 
 *          and store (SB, SH, SW) accesses.
 */

import rv32_types_pkg::*;

module memory (
    // Clock and Control Signals
    input  logic        clk,
    input  logic        MemRead,
    input  logic        MemWrite,
    input  logic [2:0]  func3,      // Size and extension specifier: [2] = zero/sign ext, [1:0] = size
    
    // Data and Address Ports
    input  logic [31:0] WriteData,  // Data input for store operations
    input  logic [31:0] address,    // Byte-level memory address
    output logic [31:0] MemoryData  // Data output for load operations
);

    // 16K 32-bit words data memory array (64 KB capacity)
    logic [31:0] memory [0:16383];
    
    // Address Parsing & Extraction Internal Signals
    logic [31:0] word_address;      // Word-aligned base index
    logic [ 1:0]  byte_offset;      // Byte offset inside the word
    logic [31:0] read_word;         // Raw 32-bit word read from memory
    logic [31:0] write_word;        // Processed word for partial writes
    logic [ 7:0]  read_byte;        // Extracted byte slice
    logic [15:0] read_half;         // Extracted halfword slice
    
    // Address alignment mappings
    assign word_address = address[31:2];
    assign byte_offset  = address[1:0];
    
    // Asynchronous raw word read
    assign read_word = memory[word_address];
    
    /**
     * @brief Combinational Load Formatting & Extension Logic
     * @details Extracts bytes or halfwords based on alignment offsets and applies 
     *          either sign-extension or zero-extension according to func3[2].
     */
    always_comb begin
        MemoryData = 32'b0; // Default output fallback
        
        if (address == 32'h40000000) begin
            MemoryData = 32'b0;  
        end 
        else if (MemRead) begin
            case (func3[1:0])
                2'b00: begin  // Byte operations (LB, LBU)
                    read_byte = read_word[byte_offset*8 +: 8];
                    
                    if (func3[2]) begin
                        MemoryData = {24'b0, read_byte};              // LBU: Zero extension
                    end else begin
                        MemoryData = {{24{read_byte[7]}}, read_byte}; // LB: Sign extension
                    end
                end
                
                2'b01: begin  // Halfword operations (LH, LHU)
                    read_half = address[1] ? read_word[31:16] : read_word[15:0];
                    
                    if (func3[2]) begin
                        MemoryData = {16'b0, read_half};               // LHU: Zero extension
                    end else begin
                        MemoryData = {{16{read_half[15]}}, read_half}; // LH: Sign extension
                    end
                end
                
                2'b10: begin  // Word operation (LW)
                    MemoryData = read_word;
                end
                
                default: begin
                    MemoryData = 32'b0;
                end
            endcase
        end
    end
    
    /**
     * @brief Synchronous Store (Write) Logic with Byte-Enable Masking
     * @details Performs read-modify-write for byte (SB) and halfword (SH) operations, 
     *          and direct full-word assignment for word (SW) operations.
     */
    always_ff @(posedge clk) begin
        if (MemWrite) begin
            if (address == 32'h40000000) begin
                
            end
            else begin
            case (func3[1:0])
                2'b00: begin  // Byte store (SB)
                    write_word = memory[word_address];
                    write_word[byte_offset*8 +: 8] = WriteData[7:0];
                    memory[word_address] <= write_word;
                end
                
                2'b01: begin  // Halfword store (SH)
                    write_word = memory[word_address];
                    if (address[1]) begin
                        write_word[31:16] = WriteData[15:0];
                    end else begin
                        write_word[15:0] = WriteData[15:0];
                    end
                    memory[word_address] <= write_word;
                end
                
                2'b10: begin  // Word store (SW)
                    memory[word_address] <= WriteData;
                end
                
                default: begin
                    // No operation for reserved configurations
                end
            endcase
            end
        end
    end

endmodule
