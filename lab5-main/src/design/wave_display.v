module wave_display (
    input clk,
    input reset,
    input [10:0] x,
    input [9:0]  y,
    input valid,
    input [7:0] read_value,
    input read_index,

    input [7:0] color_r,
    input [7:0] color_g,
    input [7:0] color_b,

    output wire [8:0] read_address,
    output wire valid_pixel,
    output wire [7:0] r,
    output wire [7:0] g,
    output wire [7:0] b
);

    assign read_address = {read_index, x[9], x[7:1]};

    wire [7:0] y_val = y[8:1];

    wire in_bounds = valid && (~y[9]) && (x[9] ^ x[8]) && (x > 11'b00100000010);

    wire [8:0] last_addr;
    dffr #(9) addr_delay_reg (
        .clk(clk), .r(reset),
        .d(read_address), .q(last_addr)
    );

    wire addr_changed = (read_address != last_addr);

    wire addr_changed_d;
    dffr #(1) addr_changed_delay_reg (
        .clk(clk), .r(reset),
        .d(addr_changed), .q(addr_changed_d)
    );

    wire [7:0] read_value_adjusted = {1'b0, read_value[7:1]} + 8'd32;
    wire [7:0] cur_sample, prev_sample;

    dffre #(8) cur_samp_reg (
        .clk(clk), .r(reset),
        .en(addr_changed_d),
        .d(read_value_adjusted),
        .q(cur_sample)
    );

    dffre #(8) prev_samp_reg (
        .clk(clk), .r(reset),
        .en(addr_changed_d),
        .d(cur_sample),
        .q(prev_sample)
    );

    // Combinational bounds from the two stored samples
    wire [7:0] upper_bound_comb = (cur_sample > prev_sample) ? cur_sample : prev_sample;
    wire [7:0] lower_bound_comb = (cur_sample < prev_sample) ? cur_sample : prev_sample;

    // Pipeline the expensive compare path by one stage
    wire [7:0] upper_bound;
    wire [7:0] lower_bound;
    wire [7:0] y_val_d;
    wire       in_bounds_d;

    dffr #(8) upper_bound_reg (
        .clk(clk), .r(reset),
        .d(upper_bound_comb), .q(upper_bound)
    );

    dffr #(8) lower_bound_reg (
        .clk(clk), .r(reset),
        .d(lower_bound_comb), .q(lower_bound)
    );

    dffr #(8) y_val_reg (
        .clk(clk), .r(reset),
        .d(y_val), .q(y_val_d)
    );

    dffr #(1) in_bounds_reg (
        .clk(clk), .r(reset),
        .d(in_bounds), .q(in_bounds_d)
    );

    assign valid_pixel = in_bounds_d &&
                         (y_val_d >= lower_bound) &&
                         (y_val_d <= upper_bound);

    assign r = valid_pixel ? color_r : 8'h00;
    assign g = valid_pixel ? color_g : 8'h00;
    assign b = valid_pixel ? color_b : 8'h00;

endmodule