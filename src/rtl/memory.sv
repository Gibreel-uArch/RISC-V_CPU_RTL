module memory (
    input  logic         clk,
    input  logic         MemRead,
    input  logic         MemWrite,
    input  logic [2:0]   func3,        // bits: [2]=sign/zero ext, [1:0]=size (00=byte, 01=half, 10=word)
    input  logic [31:0]  WriteData,    // Data to write (for stores)
    input  logic [31:0]  address,      // Byte address
    output logic [31:0]  MemoryData    // Data read (for loads)
);

    logic [31:0] memory [0:16383];
    
    logic [31:0] word_address;         // Word-aligned address
    logic [1:0]  byte_offset;          // Byte offset within word
    logic [31:0] read_word;            // Full word read from memory
    logic [31:0] write_word;           // Full word to write to memory
    logic [7:0]  read_byte;            // Extracted byte for LB/LBU
    logic [15:0] read_half;            // Extracted halfword for LH/LHU
    
    assign word_address = address[31:2];
    assign byte_offset  = address[1:0];
    
    assign read_word = memory[word_address];
    
    always_comb begin
        MemoryData = 32'b0;  // Default value
        
        if (MemRead) begin
            case (func3[1:0])
                2'b00: begin  // Byte operations (LB, LBU)
                    // Extract the correct byte based on byte_offset
                    read_byte = read_word[byte_offset*8 +: 8];
                    // Sign or zero extend based on func3[2]
                    if (func3[2]) begin
                        // LBU: Zero extend
                        MemoryData = {24'b0, read_byte};
                    end else begin
                        // LB: Sign extend
                        MemoryData = {{24{read_byte[7]}}, read_byte};
                    end
                end
                
                2'b01: begin  // Halfword operations (LH, LHU)
                    // Extract the correct halfword based on address[1]
                    if (address[1]) begin
                        // Upper halfword
                        read_half = read_word[31:16];
                    end else begin
                        // Lower halfword
                        read_half = read_word[15:0];
                    end
                    // Sign or zero extend based on func3[2]
                    if (func3[2]) begin
                        // LHU: Zero extend
                        MemoryData = {16'b0, read_half};
                    end else begin
                        // LH: Sign extend
                        MemoryData = {{16{read_half[15]}}, read_half};
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
    
    always_ff @(posedge clk) begin
        if (MemWrite) begin
            case (func3[1:0])
                2'b00: begin  // Byte store (SB)
                    // Read current word
                    write_word = memory[word_address];
                    // Modify only the target byte
                    write_word[byte_offset*8 +: 8] = WriteData[7:0];
                    // Write back the modified word
                    memory[word_address] <= write_word;
                end
                
                2'b01: begin  // Halfword store (SH)
                    // Read current word
                    write_word = memory[word_address];
                    // Modify the target halfword
                    if (address[1]) begin
                        write_word[31:16] = WriteData[15:0];
                    end else begin
                        write_word[15:0] = WriteData[15:0];
                    end
                    // Write back the modified word
                    memory[word_address] <= write_word;
                end
                
                2'b10: begin  // Word store (SW)
                    // Direct word write (no read needed)
                    memory[word_address] <= WriteData;
                end
                
                default: begin
                    // No operation for reserved encodings
                end
            endcase
        end
    end

endmodule
