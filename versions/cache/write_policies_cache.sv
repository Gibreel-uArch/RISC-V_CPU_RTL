module write_policies_cache #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic        clk,
    input  logic        rst_n,

    // CPU Interface (Pipeline)
    input  logic [31:0] address,
    input  logic        MemRead,
    input  logic        MemWrite,
    input  logic [2:0]  func3,      // [2]=Sign/Zero Ext, [1:0]=Size (00:Byte, 01:Half, 10:Word)
    input  logic [31:0] WriteData,
    output logic [31:0] MemoryData, // Data out to Pipeline
    output logic        stall,      // Hazard unit stall signal

    // Main Memory Interface (Block Level)
    output logic        mem_req,    // 1 = Request memory access
    output logic        mem_rnw,    // 1 = Read (Allocate), 0 = Write (Write-Back)
    output logic [31:0] mem_addr,   // Block aligned address
    output logic [127:0]mem_wdata,  // 128-bit data to write back
    input  logic [127:0]mem_rdata,  // 128-bit data from memory
    input  logic        mem_ready   // 1 = Memory transaction complete
);

    // =========================================================================
    // 1. Storage Layout: 64 Sets x 2 Ways x 152 bits [127:0 Data, 21:0 Tag, Dirty, Valid]
    // =========================================================================
    logic [151:0] way0 [0:63];
    logic [151:0] way1 [0:63];
    logic         lru  [0:63]; // 0 = Way 0 is LRU, 1 = Way 1 is LRU

    // =========================================================================
    // 2. Address Breakdown
    // =========================================================================
    logic [3:0]  offset;     // 16 bytes per block
    logic [5:0]  index;      // 64 sets
    logic [21:0] tag;        // 32 - 4 - 6 = 22 bits

    assign offset = address[3:0];
    assign index  = address[9:4];
    assign tag    = address[31:10];

    // =========================================================================
    // 3. Extract Block Components from Storage
    // =========================================================================
    logic        v0, v1, d0, d1;
    logic [21:0] t0, t1;
    logic [127:0] data0, data1;

    assign {data0, t0, d0, v0} = way0[index];
    assign {data1, t1, d1, v1} = way1[index];

    // =========================================================================
    // 4. Hit Detection & Stall Logic
    // =========================================================================
    logic hit0, hit1, hit;
    assign hit0 = v0 && (t0 == tag);
    assign hit1 = v1 && (t1 == tag);
    
    assign hit   = (MemRead || MemWrite) && (hit0 || hit1);
    assign stall = (MemRead || MemWrite) && !hit;

    // Selected block on Hit
    logic [127:0] hit_block;
    assign hit_block = hit0 ? data0 : data1;

    // =========================================================================
    // 5. Data Formatting Logic (CPU Read / Write Modifications)
    // =========================================================================
    
    // --- Word / Half / Byte Extraction for Read ---
    logic [31:0] read_word;
    logic [15:0] read_half;
    logic [7:0]  read_byte;

    assign read_word = hit_block[offset[3:2]*32 +: 32];
    
    always_comb begin
        MemoryData = 32'b0;
        read_byte  = 8'b0;
        read_half  = 16'b0;
        
        if (hit && MemRead) begin
            case (func3[1:0])
                2'b00: begin // LB / LBU
                    case (offset[1:0])
                        2'b00: read_byte = read_word[7:0];
                        2'b01: read_byte = read_word[15:8];
                        2'b10: read_byte = read_word[23:16];
                        2'b11: read_byte = read_word[31:24];
                    endcase
                    MemoryData = func3[2] ? {24'b0, read_byte} : {{24{read_byte[7]}}, read_byte};
                end
                2'b01: begin // LH / LHU
                    read_half  = offset[1] ? read_word[31:16] : read_word[15:0];
                    MemoryData = func3[2] ? {16'b0, read_half} : {{16{read_half[15]}}, read_half};
                end
                2'b10: MemoryData = read_word; // LW
                default: MemoryData = read_word;
            endcase
        end
    end

    // --- Data Modification Logic for Write (Hit Modification & Allocation Merge) ---
    logic [31:0] target_word_in;
    logic [31:0] mod_word;
    logic [127:0] base_block_for_write;
    logic [127:0] modified_block;

    // Base block selection: uses hit_block during HIT, or mem_rdata during REFILL (ALLOCATE)
    assign base_block_for_write = hit ? hit_block : mem_rdata;
    assign target_word_in       = base_block_for_write[offset[3:2]*32 +: 32];

    always_comb begin
        modified_block = base_block_for_write;
        mod_word       = target_word_in;
        
        if (MemWrite) begin
            case (func3[1:0])
                2'b00: begin // SB
                    case (offset[1:0])
                        2'b00: mod_word[7:0]   = WriteData[7:0];
                        2'b01: mod_word[15:8]  = WriteData[7:0];
                        2'b10: mod_word[23:16] = WriteData[7:0];
                        2'b11: mod_word[31:24] = WriteData[7:0];
                    endcase
                end
                2'b01: begin // SH
                    if (offset[1]) mod_word[31:16] = WriteData[15:0];
                    else           mod_word[15:0]  = WriteData[15:0];
                end
                2'b10: mod_word = WriteData; // SW
                default: mod_word = WriteData;
            endcase
            modified_block[offset[3:2]*32 +: 32] = mod_word;
        end
    end

    // =========================================================================
    // 6. FSM Controller & Victim Selection Logic
    // =========================================================================
    typedef enum logic [1:0] {
        IDLE       = 2'b00,
        WRITE_BACK = 2'b01,
        ALLOCATE   = 2'b10
    } state_t;

    state_t state, next_state;

    // Victim Way & Tag Selection
    logic        victim_way;
    logic        victim_dirty;
    logic [21:0]  victim_tag;
    logic [127:0] victim_data;

    always_comb begin
        if (!v0)      victim_way = 1'b0;
        else if (!v1) victim_way = 1'b1;
        else          victim_way = lru[index];

        if (victim_way == 1'b0) begin
            victim_dirty = v0 && d0; // Mask with Valid
            victim_tag   = t0; 
            victim_data  = data0;
        end else begin
            victim_dirty = v1 && d1; // Mask with Valid
            victim_tag   = t1; 
            victim_data  = data1;
        end
    end

    // FSM State Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // FSM Next-State & Output Logic
    always_comb begin
        next_state = state;
        mem_req    = 1'b0;
        mem_rnw    = 1'b1;
        mem_addr   = {tag, index, 4'b0000};
        mem_wdata  = victim_data;

        case (state)
            IDLE: begin
                if ((MemRead || MemWrite) && !hit) begin
                    if (victim_dirty) next_state = WRITE_BACK;
                    else              next_state = ALLOCATE;
                end
            end

            WRITE_BACK: begin
                mem_req  = 1'b1;
                mem_rnw  = 1'b0; // Write Back
                mem_addr = {victim_tag, index, 4'b0000};
                if (mem_ready) next_state = ALLOCATE;
            end

            ALLOCATE: begin
                mem_req  = 1'b1;
                mem_rnw  = 1'b1; // Refill Read
                if (mem_ready) next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // =========================================================================
    // 7. Sequential State Update (Cache Refill, Hits & LRU Updates)
    // =========================================================================
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0; i<64; i++) begin
                way0[i] <= '0;
                way1[i] <= '0;
                lru[i]  <= 1'b0;
            end
        end else begin
            if (hit) begin
                // Update LRU on Hit
                lru[index] <= hit0 ? 1'b1 : 1'b0; 
                
                // On Write Hit: Update Data & Set Dirty=1
                if (MemWrite) begin
                    if (hit0) way0[index] <= {modified_block, t0, 1'b1, 1'b1};
                    else      way1[index] <= {modified_block, t1, 1'b1, 1'b1};
                end
            end 
            else if (state == ALLOCATE && mem_ready) begin
                // REFILL & WRITE ALLOCATE FIX:
                // If this refill was caused by a MemWrite, store modified_block and set dirty=1.
                // If it was caused by a MemRead, store mem_rdata as is and set dirty=0.
                if (victim_way == 1'b0) begin
                    way0[index] <= {modified_block, tag, MemWrite, 1'b1};
                    lru[index]  <= 1'b1; // Way 0 was just filled -> Way 1 is now LRU
                end else begin
                    way1[index] <= {modified_block, tag, MemWrite, 1'b1};
                    lru[index]  <= 1'b0; // Way 1 was just filled -> Way 0 is now LRU
                end
            end
        end
    end

endmodule
