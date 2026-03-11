`define EW_SWIDTH 2
`define EW_ARMED  2'b00
`define EW_ACTIVE 2'b01
`define EW_WAIT   2'b10

module enhanced_wave_capture (
    input clk,
    input reset,
    input new_sample_ready,
    input [15:0] trigger_sample_in,
    input wave_display_idle,

    output wire [8:0] write_address,
    output wire write_enable,
    output wire read_index
);

    wire [`EW_SWIDTH-1:0] state;
    reg  [`EW_SWIDTH-1:0] next_state;

    wire [7:0] counter;
    wire [7:0] next_counter;

    wire [15:0] prev_sample;
    wire curr_read_index;
    wire next_read_index;

    dffr #(`EW_SWIDTH) state_reg (
        .clk(clk), .r(reset), .d(next_state), .q(state)
    );

    dffr #(8) counter_reg (
        .clk(clk), .r(reset), .d(next_counter), .q(counter)
    );

    dffr #(1) read_index_reg (
        .clk(clk), .r(reset), .d(next_read_index), .q(curr_read_index)
    );

    dffre #(16) prev_sample_reg (
        .clk(clk), .r(reset), .en(new_sample_ready),
        .d(trigger_sample_in), .q(prev_sample)
    );

    wire positive_zero_crossing = prev_sample[15] && ~trigger_sample_in[15];
    wire triggering = (state == `EW_ARMED) && new_sample_ready && positive_zero_crossing;

    always @(*) begin
        next_state = state;
        case (state)
            `EW_ARMED:  begin
                if (triggering)
                    next_state = `EW_ACTIVE;
            end

            `EW_ACTIVE: begin
                if (new_sample_ready && (counter == 8'd255))
                    next_state = `EW_WAIT;
            end

            `EW_WAIT: begin
                if (wave_display_idle)
                    next_state = `EW_ARMED;
            end

            default: begin
                next_state = `EW_ARMED;
            end
        endcase
    end

    assign next_counter =
        (state == `EW_ARMED && !triggering) ? 8'd0 :
        (((state == `EW_ACTIVE) && new_sample_ready) || triggering) ? (counter + 8'd1) :
        counter;

    assign next_read_index =
        (state == `EW_WAIT && wave_display_idle) ? ~curr_read_index : curr_read_index;

    assign write_address = {~curr_read_index, counter};
    assign write_enable  = ((state == `EW_ACTIVE) || triggering) && new_sample_ready;
    assign read_index    = curr_read_index;

endmodule