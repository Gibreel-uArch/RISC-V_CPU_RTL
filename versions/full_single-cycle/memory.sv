module memory (
    // Clock and Control Signals
    input  logic        clk,
    input  logic        MemRead,
    input  logic        MemWrite,
    input  logic [2:0]  func3,      // [2]=Zero/Sign Ext, [1:0]=Size (00:Byte, 01:Half, 10:Word)
    
    // Data and Address Ports
    input  logic [31:0] WriteData,  
    input  logic [31:0] address,    
    output logic [31:0] MemoryData  
);

    // Memory array: 16384 words (32-bit each) = 64 KB capacity
    logic [31:0] memory [0:16383];
    
    // Internal signals for readability
    logic [13:0] word_index;   // Word index in memory
    logic [ 1:0] byte_offset;  // Byte offset inside the word
    logic [31:0] read_word;    // Full raw word read from memory
    logic [ 7:0] read_byte;    // Extracted byte slice
    logic [15:0] read_half;    // Extracted halfword slice

    // ---------------------------------------------------------
    // Address Decoding
    // ---------------------------------------------------------
    assign word_index  = address[15:2]; // Extract word index bits
    assign byte_offset = address[1:0];  // Extract byte offset bits
    
    // Always read the full word from memory
    assign read_word = memory[word_index];
    
    // =========================================================
    // 1. Load Logic (Load Instructions) - Combinational Logic
    // =========================================================
    always_comb begin
        MemoryData = 32'b0; // Default output fallback to avoid latches
        read_byte  = 8'b0;
        read_half  = 16'b0;
        
        // Exclude I/O address
        if (address == 32'h40000000) begin
            MemoryData = 32'b0;  
        end 
        else if (MemRead) begin
            case (func3[1:0])
                // --- Byte Operations (LB / LBU) ---
                2'b00: begin  
                    // 1. Explicitly extract the byte based on offset
                    case (byte_offset)
                        2'b00: read_byte = read_word[7:0];
                        2'b01: read_byte = read_word[15:8];
                        2'b10: read_byte = read_word[23:16];
                        2'b11: read_byte = read_word[31:24];
                    endcase
                    
                    // 2. Sign or Zero Extension
                    if (func3[2] == 1'b1) 
                        MemoryData = {24'b0, read_byte};             // LBU
                    else 
                        MemoryData = {{24{read_byte[7]}}, read_byte}; // LB
                end
                
                // --- Halfword Operations (LH / LHU) ---
                2'b01: begin  
                    // 1. Explicitly extract the halfword
                    if (byte_offset[1] == 1'b0)
                        read_half = read_word[15:0];
                    else
                        read_half = read_word[31:16];
                    
                    // 2. Sign or Zero Extension
                    if (func3[2] == 1'b1) 
                        MemoryData = {16'b0, read_half};               // LHU
                    else 
                        MemoryData = {{16{read_half[15]}}, read_half}; // LH
                end
                
                // --- Word Operation (LW) ---
                2'b10: begin  
                    MemoryData = read_word;
                end
            endcase
        end
    end
    
    // =========================================================
    // 2. Store Logic (Store Instructions) - Synchronous Logic
    // =========================================================
    always_ff @(posedge clk) begin
        // Write occurs only if MemWrite is asserted and address is not reserved
        if (MemWrite && address != 32'h40000000) begin
            case (func3[1:0])
                // --- Byte Store (SB) ---
                2'b00: begin  
                    // Write directly to the specific byte slice in memory
                    case (byte_offset)
                        2'b00: memory[word_index][7:0]   <= WriteData[7:0];
                        2'b01: memory[word_index][15:8]  <= WriteData[7:0];
                        2'b10: memory[word_index][23:16] <= WriteData[7:0];
                        2'b11: memory[word_index][31:24] <= WriteData[7:0];
                    endcase
                end
                
                // --- Halfword Store (SH) ---
                2'b01: begin  
                    if (byte_offset[1] == 1'b0)
                        memory[word_index][15:0]  <= WriteData[15:0];
                    else
                        memory[word_index][31:16] <= WriteData[15:0];
                end
                
                // --- Word Store (SW) ---
                2'b10: begin  
                    memory[word_index] <= WriteData;
                end
            endcase
        end
    end

endmodule
