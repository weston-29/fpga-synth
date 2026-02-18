// Define State Assignments
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
    // Updates only when a new sample is actually ready
    dffre #(16) prev_sample_reg (
        .clk(clk), .r(reset), .en(new_sample_ready), 
        .d(new_sample_in), .q(prev_sample)
    );

    // Trigger Logic & Sample Adjustment

    // Positive zero crossing: previous sample was negative (MSB=1), 
    // current sample is positive or zero (MSB=0).
    wire positive_zero_crossing = prev_sample[15] && ~new_sample_in[15];

    // Convert signed 2's complement to unsigned 8-bit [0, 255]
    // Inverting the MSB translates the range -128...127 to 0...255
    assign write_sample = {~new_sample_in[15], new_sample_in[14:8]};

    // FSM Logic
    always @(*) begin
        case (state)
            // Wait for a positive zero crossing to trigger capture
            `ARMED:  next_state = (new_sample_ready && positive_zero_crossing) ? `ACTIVE : `ARMED;
            
            // Capture 256 samples into RAM
            `ACTIVE: next_state = (new_sample_ready && counter == 8'd255) ? `WAIT : `ACTIVE;
            
            // Wait until the display is idle before switching buffers
            `WAIT:   next_state = wave_display_idle ? `ARMED : `WAIT;
            
            default: next_state = `ARMED;
        endcase
    end

    // Datapath Logic

    // Counter logic: Reset to 0 when entering/staying in ARMED; increment in ACTIVE
    assign next_counter = (state == `ARMED)  ? 8'd0 :
                          (state == `ACTIVE && new_sample_ready) ? counter + 8'd1 : 
                          counter;

    // Toggle read_index only when transitioning from WAIT back to ARMED
    assign next_read_index = (state == `WAIT && wave_display_idle) ? ~curr_read_index : curr_read_index;

    // RAM signals
    // Write to the half of RAM currently NOT being read by the display (~curr_read_index)
    assign write_address = {~curr_read_index, counter};
    assign write_enable  = (state == `ACTIVE) && new_sample_ready;
    assign read_index    = curr_read_index;

endmodule