module direct_mapped_cache #(
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

    // 1. Storage: 256 entries x 149 bits [148:21 Data | 20:1 Tag | 0 Valid]
    logic [148:0] cache [0:255];

    // 2. Address Breakdown (Combinational)
    logic [3:0]  offset;
    logic [7:0]  index;
    logic [19:0] address_tag;

    assign offset      = address[3:0];
    assign index       = address[11:4];
    assign address_tag = address[31:12];

    // 3. Extract Block Components (Combinational)
    logic [19:0]  block_tag;
    logic         block_valid_bit;
    logic [127:0] block_data;

    assign block_valid_bit = cache[index][0];
    assign block_tag       = cache[index][20:1];
    assign block_data      = cache[index][148:21];

    // 4. Hit Detection (Combinational)
    assign hit = cpu_req && block_valid_bit && (block_tag == address_tag);

    // 5. Word Selection Multiplexer based on Offset
    // offset[3:2] selects one of the four 32-bit words within the 128-bit block
    always_comb begin
        if (hit) begin
            case (offset[3:2])
                2'b00:   data_out = block_data[31:0];
                2'b01:   data_out = block_data[63:32];
                2'b10:   data_out = block_data[95:64];
                2'b11:   data_out = block_data[127:96];
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

    // FSM State Register (Sequential)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // FSM Next State & Output Logic (Combinational)
    always_comb begin
        next_state  = current_state;
        mem_valid = 1'b0;
        mem_addr = address;

        case (current_state)
            IDLE: begin
                // On a CPU request with a cache miss, initiate memory read
                if (cpu_req && !hit) begin
                    next_state  = MEM_READ;
                    mem_valid = 1'b1;
                end
            end

            MEM_READ: begin
                mem_valid = 1'b1;
                if (mem_resp_valid) begin
                    next_state = REFILL;
                end
            end

            REFILL: begin
                // Cache update occurs in the sequential block below, then return to IDLE
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // 7. Cache Refill and Reset Logic (Sequential)
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Invalidate all cache lines on reset
            for (i = 0; i < 256; i = i + 1) begin
                cache[i][0] <= 1'b0;
            end
        end else if (current_state == REFILL) begin
            // Write back {Data[127:0], Tag[19:0], Valid=1}
            cache[index] <= {mem_data, address_tag, 1'b1};
        end
    end

endmodule
