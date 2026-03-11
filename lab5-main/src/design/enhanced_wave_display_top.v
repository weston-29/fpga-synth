module enhanced_wave_display_top(
    input clk,
    input reset,
    input new_sample,

    input [15:0] sum_sample,
    input [15:0] voice0_sample,
    input [15:0] voice1_sample,
    input [15:0] voice2_sample,

    input [10:0] x,
    input [9:0]  y,
    input valid,
    input vsync,

    output wire pixel_on,
    output wire [7:0] r,
    output wire [7:0] g,
    output wire [7:0] b
);

    wire wave_display_idle = ~vsync;

    wire [8:0] write_address;
    wire write_enable;
    wire read_index;

    enhanced_wave_capture ewc(
        .clk(clk),
        .reset(reset),
        .new_sample_ready(new_sample),
        .trigger_sample_in(sum_sample),
        .wave_display_idle(wave_display_idle),
        .write_address(write_address),
        .write_enable(write_enable),
        .read_index(read_index)
    );

    // Same signed->unsigned packing used by original wave_capture
    wire [7:0] write_sum   = {~sum_sample[15],    sum_sample[14:8]};
    wire [7:0] write_v0    = {~voice0_sample[15], voice0_sample[14:8]};
    wire [7:0] write_v1    = {~voice1_sample[15], voice1_sample[14:8]};
    wire [7:0] write_v2    = {~voice2_sample[15], voice2_sample[14:8]};

    wire [7:0] read_sum;
    wire [7:0] read_v0;
    wire [7:0] read_v1;
    wire [7:0] read_v2;

    wire [8:0] read_address_sum;
    wire [8:0] read_address_v0;
    wire [8:0] read_address_v1;
    wire [8:0] read_address_v2;

    ram_1w2r #(.WIDTH(8), .DEPTH(9)) sum_ram(
        .clka(clk),
        .clkb(clk),
        .wea(write_enable),
        .addra(write_address),
        .dina(write_sum),
        .douta(),
        .addrb(read_address_sum),
        .doutb(read_sum)
    );

    ram_1w2r #(.WIDTH(8), .DEPTH(9)) voice0_ram(
        .clka(clk),
        .clkb(clk),
        .wea(write_enable),
        .addra(write_address),
        .dina(write_v0),
        .douta(),
        .addrb(read_address_v0),
        .doutb(read_v0)
    );

    ram_1w2r #(.WIDTH(8), .DEPTH(9)) voice1_ram(
        .clka(clk),
        .clkb(clk),
        .wea(write_enable),
        .addra(write_address),
        .dina(write_v1),
        .douta(),
        .addrb(read_address_v1),
        .doutb(read_v1)
    );

    ram_1w2r #(.WIDTH(8), .DEPTH(9)) voice2_ram(
        .clka(clk),
        .clkb(clk),
        .wea(write_enable),
        .addra(write_address),
        .dina(write_v2),
        .douta(),
        .addrb(read_address_v2),
        .doutb(read_v2)
    );

    wire sum_on, v0_on, v1_on, v2_on;
    wire [7:0] sum_r_unused, sum_g_unused, sum_b_unused;
    wire [7:0] v0_r_unused, v0_g_unused, v0_b_unused;
    wire [7:0] v1_r_unused, v1_g_unused, v1_b_unused;
    wire [7:0] v2_r_unused, v2_g_unused, v2_b_unused;

    wave_display sum_trace(
        .clk(clk),
        .reset(reset),
        .x(x),
        .y(y),
        .valid(valid),
        .read_value(read_sum),
        .read_index(read_index),
        .color_r(8'hFF),
        .color_g(8'hFF),
        .color_b(8'hFF),
        .read_address(read_address_sum),
        .valid_pixel(sum_on),
        .r(sum_r_unused),
        .g(sum_g_unused),
        .b(sum_b_unused)
    );

    wave_display voice0_trace(
        .clk(clk),
        .reset(reset),
        .x(x),
        .y(y),
        .valid(valid),
        .read_value(read_v0),
        .read_index(read_index),
        .color_r(8'hFF),
        .color_g(8'h00),
        .color_b(8'h00),
        .read_address(read_address_v0),
        .valid_pixel(v0_on),
        .r(v0_r_unused),
        .g(v0_g_unused),
        .b(v0_b_unused)
    );

    wave_display voice1_trace(
        .clk(clk),
        .reset(reset),
        .x(x),
        .y(y),
        .valid(valid),
        .read_value(read_v1),
        .read_index(read_index),
        .color_r(8'h00),
        .color_g(8'hFF),
        .color_b(8'h00),
        .read_address(read_address_v1),
        .valid_pixel(v1_on),
        .r(v1_r_unused),
        .g(v1_g_unused),
        .b(v1_b_unused)
    );

    wave_display voice2_trace(
        .clk(clk),
        .reset(reset),
        .x(x),
        .y(y),
        .valid(valid),
        .read_value(read_v2),
        .read_index(read_index),
        .color_r(8'h00),
        .color_g(8'h00),
        .color_b(8'hFF),
        .read_address(read_address_v2),
        .valid_pixel(v2_on),
        .r(v2_r_unused),
        .g(v2_g_unused),
        .b(v2_b_unused)
    );

    enhanced_wave_compositor #(.NUM_VOICES(3)) compositor(
        .wave_sum_on(sum_on),
        .wave_voice_on({v2_on, v1_on, v0_on}),
        .out_on(pixel_on),
        .out_r(r),
        .out_g(g),
        .out_b(b)
    );

endmodule