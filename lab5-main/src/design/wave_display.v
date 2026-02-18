module wave_display (
    input clk,
    input reset,
    input [10:0] x,  // [0..1279]
    input [9:0]  y,  // [0..1023]
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
    wire in_bounds = (~y[9] && (x[9] ^ x[8]));
    
    // Set up signal to enable acceptance of new sample when read_addr changes
    wire [8:0] last_addr;
    dffr #(9) addr_delay_reg (
        .clk(clk),
        .r(reset),
        .d(read_address),
        .q(last_addr)
    );
    
    // High once every 2 clock cycles
    wire addr_changed = (read_address != last_addr);
    
    
    // Shift Register for Sample Preservation
    wire [7:0] cur_sample, prev_sample;
    
    dffre #(8) cur_samp_reg (
        .clk(clk),
        .r(reset),
        .en(addr_changed), // ONLY grab RAM output when we go to a new addr
        .d(read_value),
        .q(cur_sample)
    );
    
    // Shift the old current sample into previous sample reg
    dffre #(8) prev_samp_reg (
        .clk(clk),
        .r(reset),
        .en(addr_changed),
        .d(cur_sample),
        .q(prev_sample)
    );
    
    // Pipelining to delay y and in_bounds to align with register updates above
    wire [7:0] y_delayed;
    wire in_bounds_delayed;
    
    dffr #(8) y_pipe ( .clk(clk), .r(reset), .d(y_val), .q(y_delayed) );
    dffr #(1) bounds_pipe ( .clk(clk), .r(reset), .d(in_bounds), .q(in_bounds_delayed) );
    
    // Comparison of previous and current RAM addresses to determine pixel color
    wire [7:0] upper_bound = (cur_sample > prev_sample) ? cur_sample : prev_sample;
    wire [7:0] lower_bound = (cur_sample < prev_sample) ? cur_sample : prev_sample;
    
    assign valid_pixel = in_bounds_delayed && (y_delayed >= lower_bound) && (y_delayed <= upper_bound);
    
    assign {r, g, b} = valid_pixel ? 24'hFFFFFF : 24'h000000;
    
endmodule
