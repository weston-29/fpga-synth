`define SWIDTH 2
`define ARMED  2'b00
`define ACTIVE 2'b01
`define WAIT   2'b10

module wave_capture (
    input clk,
    input reset,
    input new_sample_ready,
    input [15:0] new_sample_in,
    input wave_display_idle,
    output wire [8:0] write_address,
    output wire write_enable,
    output wire [7:0] write_sample,
    output wire read_index
);

    // State and Internal Registers
    wire [`SWIDTH-1:0] state;
    reg  [`SWIDTH-1:0] next_state;

    wire [7:0] counter, next_counter;
    wire [15:0] prev_sample;
    wire curr_read_index, next_read_index;

    // FSM State Register
    dffr #(`SWIDTH) state_reg (
        .clk(clk), .r(reset), .d(next_state), .q(state)
    );

    // 8-bit Counter for RAM addresses (0-255)
    dffr #(8) counter_reg (
        .clk(clk), .r(reset), .d(next_counter), .q(counter)
    );

    // Read Index Register (toggles to support double buffering)
    dffr #(1) read_index_reg (
        .clk(clk), .r(reset), .d(next_read_index), .q(curr_read_index)
    );

    // Register to store the previous sample to detect zero-crossing
    // Uses dffre from library
    dffre #(16) prev_sample_reg (
        .clk(clk), .r(reset), .en(new_sample_ready), 
        .d(new_sample_in), .q(prev_sample)
    );

    // Trigger Logic 
    // Positive zero crossing: Prev was Neg (1), Current is Pos (0)
    wire positive_zero_crossing = prev_sample[15] && ~new_sample_in[15];
    
    // Logic to detect if we are triggering THIS CYCLE
    wire triggering = (state == `ARMED && new_sample_ready && positive_zero_crossing);

    // Convert signed 2's complement to unsigned 8-bit [0, 255]
    assign write_sample = {~new_sample_in[15], new_sample_in[14:8]};

    // FSM Logic
    always @(*) begin
        next_state = state; // Default stay in current state
        case (state)
            `ARMED:  begin
                if (triggering) 
                    next_state = `ACTIVE;
            end
            
            `ACTIVE: begin
                if (new_sample_ready && counter == 8'd255) 
                    next_state = `WAIT;
            end
            
            `WAIT:   begin
                if (wave_display_idle) 
                    next_state = `ARMED;
            end
            
            default: next_state = `ARMED;
        endcase
    end

    // Datapath Logic

    // Counter logic:
    // 1. If ARMED and NOT triggering, hold at 0.
    // 2. If ACTIVE (and ready) OR Triggering, increment.
    assign next_counter = (state == `ARMED && !triggering) ? 8'd0 :
                          ((state == `ACTIVE && new_sample_ready) || triggering) ? counter + 8'd1 : 
                          counter;

    // Toggle read_index only when transitioning from WAIT back to ARMED
    assign next_read_index = (state == `WAIT && wave_display_idle) ? ~curr_read_index : curr_read_index;

    // RAM signals
    assign write_address = {~curr_read_index, counter};
    
    // Enable write if we are ACTIVE *OR* if we are currently triggering
    assign write_enable  = ((state == `ACTIVE) || triggering) && new_sample_ready;
    
    assign read_index    = curr_read_index;

endmodule