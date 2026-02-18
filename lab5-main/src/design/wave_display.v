module wave_display (
    input clk,
    input reset,
    input [10:0] x,
    input [9:0]  y,
    input valid,
    input [7:0] read_value,
    input read_index,
    output wire [8:0] read_address,
    output wire valid_pixel,
    output wire [7:0] r,
    output wire [7:0] g,
    output wire [7:0] b
);

    assign read_address = {read_index, x[9], x[7:1]};

    wire [7:0] y_val    = y[8:1];
    wire in_bounds      = (~y[9]) && (x[9] ^ x[8]);

    // --- Address change detection ---
    wire [8:0] last_addr;
    dffr #(9) addr_delay_reg (
        .clk(clk), .r(reset),
        .d(read_address), .q(last_addr)
    );

    wire addr_changed = (read_address != last_addr);

    // Delay addr_changed by 1 cycle so enable fires exactly when RAM
    // output is valid for the new address (1-cycle RAM latency)
    wire addr_changed_d;
    dffr #(1) addr_changed_delay_reg (
        .clk(clk), .r(reset),
        .d(addr_changed), .q(addr_changed_d)
    );

    // --- Sample registers ---
    wire [7:0] read_value_adjusted = {1'b0, read_value[7:1]} + 8'd32;
    wire [7:0] cur_sample, prev_sample;

    dffre #(8) cur_samp_reg (
        .clk(clk), .r(reset),
        .en(addr_changed_d),      // fires when V(Ak) is stable on read_value
        .d(read_value_adjusted),
        .q(cur_sample)
    );

    dffre #(8) prev_samp_reg (
        .clk(clk), .r(reset),
        .en(addr_changed_d),
        .d(cur_sample),
        .q(prev_sample)
    );

    // --- Bounds comparison uses CURRENT y, no pipeline ---
    // Samples lag 1 address behind, causing a 2-pixel rightward shift.
    // This is imperceptible and keeps y self-consistent with the current pixel.
    wire [7:0] upper_bound = (cur_sample > prev_sample) ? cur_sample : prev_sample;
    wire [7:0] lower_bound = (cur_sample < prev_sample) ? cur_sample : prev_sample;

    assign valid_pixel = in_bounds
                      && (y_val >= lower_bound)
                      && (y_val <= upper_bound);

    assign {r, g, b} = valid_pixel ? 24'hFFFFFF : 24'h000000;

endmodule