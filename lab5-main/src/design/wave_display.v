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

    // Set up RAM reading address to keep x constant for 2 cycles (2 pixels) 
    // read_index indicates read/write half of ROM, x[9] distinguishes Quadrants 2 and 3
    assign read_address = {read_index, x[9], x[7:1]};

    // Translate y value to only draw in top half of screen
    wire [7:0] y_val = y[8:1];
    
    // Window to middle two quadrants
    // y[9] is 0 in top half, {x[9], x[8]} == 10 || 01 in Q2 and Q3
    wire in_bounds = (~y[9]) && (x[9] ^ x[8]);

    // Set up signal to enable acceptance of new sample when read_addr changes
    wire [8:0] last_addr;
    dffr #(9) addr_delay_reg (
        .clk(clk), .r(reset),
        .d(read_address), .q(last_addr)
    );

    // High once every 2 clock cycles
    wire addr_changed = (read_address != last_addr);

    // Pipelined delay for addr_changed by 1 cycle - enable fires exactly when RAM
    // output is valid for the new address (1-cycle RAM latency)
    wire addr_changed_d;
    dffr #(1) addr_changed_delay_reg (
        .clk(clk), .r(reset),
        .d(addr_changed), .q(addr_changed_d)
    );

    // Sample resigsters
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

    // Comparison of previous and current RAM addresses to determine pixel color
    //     uses CURRENT y, no pipeline
    wire [7:0] upper_bound = (cur_sample > prev_sample) ? cur_sample : prev_sample;
    wire [7:0] lower_bound = (cur_sample < prev_sample) ? cur_sample : prev_sample;
    // NOTE: Samples lag 1 address behind, causing a 2-pixel rightward shift.
    // This is imperceptible and keeps y self-consistent with the current pixel.
    
    assign valid_pixel = in_bounds  // maybe ff this instead of delaying addr
                      && (y_val >= lower_bound)
                      && (y_val <= upper_bound);

    assign {r, g, b} = valid_pixel ? 24'hFFFFFF : 24'h000000;

endmodule