module 2way_associative_cache #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic         clk,
    input  logic         rst_n,

    // CPU Interface
    input  logic [31:0]  address,
    input  logic         cpu_req,
    output logic [31:0]  data_out,
    output logic         hit,        

    // Memory Interface
    input  logic [127:0] mem_data,
    input  logic         mem_resp_valid,
    output logic         mem_valid,
    output logic [31:0]  mem_addr
);

    // 1. Storage Configuration (128 Sets x 2 Ways)
    // Way Structure: [149:22 Data (128b) | 21:1 Tag (21b) | 0 Valid (1b)] = 150 bits
    logic [149:0] way0 [0:127];
    logic [149:0] way1 [0:127];
    
    // LRU Register Bit per Set: 0 -> Way 0 was LRU, 1 -> Way 1 was LRU
    logic lru [0:127];

    // 2. Address Breakdown
    logic [3:0]  offset;       // address[3:0]   - 16-byte block
    logic [6:0]  index;        // address[10:4]  - 128 sets
    logic [20:0] address_tag;  // address[31:11] - 21-bit tag

    assign offset      = address[3:0];
    assign index       = address[10:4];
    assign address_tag = address[31:11];

    // 3. Extract Block Components
    logic         valid_w0, valid_w1;
    logic [20:0]  tag_w0,   tag_w1;
    logic [127:0] data_w0,  data_w1;

    assign valid_w0 = way0[index][0];
    assign tag_w0   = way0[index][21:1];
    assign data_w0  = way0[index][149:22];

    assign valid_w1 = way1[index][0];
    assign tag_w1   = way1[index][21:1];
    assign data_w1  = way1[index][149:22];

    // 4. Hit Detection
    logic hit_w0, hit_w1;
    assign hit_w0 = cpu_req && valid_w0 && (tag_w0 == address_tag);
    assign hit_w1 = cpu_req && valid_w1 && (tag_w1 == address_tag);
    
    assign hit = hit_w0 || hit_w1;

    // 5. Data Selection Multiplexer
    logic [127:0] selected_block;

    always_comb begin
        if (hit_w0)
            selected_block = data_w0;
        else if (hit_w1)
            selected_block = data_w1;
        else
            selected_block = '0;
    end

    // Word Selection based on Offset[3:2]
    always_comb begin
        if (hit) begin
            case (offset[3:2])
                2'b00:   data_out = selected_block[31:0];
                2'b01:   data_out = selected_block[63:32];
                2'b10:   data_out = selected_block[95:64];
                2'b11:   data_out = selected_block[127:96];
                default: data_out = 32'b0;
            endcase
        end else begin
            data_out = 32'b0;
        end
    end

    // 6. FSM States for Miss Handling
    typedef enum logic [1:0] {
        IDLE     = 2'b00,
        MEM_READ = 2'b01,
        REFILL   = 2'b10
    } state_t;

    state_t current_state, next_state;

    // FSM State Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // FSM Next State & Output Logic
    always_comb begin
        next_state = current_state;
        mem_valid  = 1'b0;
        // aligned address to start of block
        mem_addr   = {address[31:4], 4'b0000}; 

        case (current_state)
            IDLE: begin
                if (cpu_req && !hit) begin
                    next_state = MEM_READ;
                    mem_valid  = 1'b1;
                end
            end

            MEM_READ: begin
                mem_valid = 1'b1;
                if (mem_resp_valid) begin
                    next_state = REFILL;
                end
            end

            REFILL: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // 7. Cache Refill, LRU Update, and Reset Logic
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 128; i = i + 1) begin
                way0[i][0] <= 1'b0;
                way1[i][0] <= 1'b0;
                lru[i]     <= 1'b0;
            end
        end else begin
            // Update LRU on Cache Hit
            if (hit_w0)
                lru[index] <= 1'b1; // Way 1 is now LRU
            else if (hit_w1)
                lru[index] <= 1'b0; // Way 0 is now LRU

            // Refill Cache Line on Miss
            if (current_state == REFILL) begin
                // Replacement policy: Check invalid ways first, then LRU bit
                if (!valid_w0) begin
                    way0[index] <= {mem_data, address_tag, 1'b1};
                    lru[index]  <= 1'b1;
                end else if (!valid_w1) begin
                    way1[index] <= {mem_data, address_tag, 1'b1};
                    lru[index]  <= 1'b0;
                end else if (lru[index] == 1'b0) begin
                    way0[index] <= {mem_data, address_tag, 1'b1};
                    lru[index]  <= 1'b1;
                end else begin
                    way1[index] <= {mem_data, address_tag, 1'b1};
                    lru[index]  <= 1'b0;
                end
            end
        end
    end

endmodule
