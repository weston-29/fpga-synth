module enhanced_wave_display_top(
    input clk,
    input reset,
    input new_sample,
    input scaling_button, // New input

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

    // -------------------------------------------------------------------------
    // 1. ZOOM STATE MACHINE (Cycles 0 -> 1 -> 2 -> 0)
    // -------------------------------------------------------------------------
    wire [1:0] zoom_mode;
    wire [1:0] next_zoom = (zoom_mode == 2'd2) ? 2'd0 : (zoom_mode + 1'b1);

    dffre #(.WIDTH(2)) zoom_reg (
        .clk(clk),
        .r(reset),
        .en(scaling_button),
        .d(next_zoom),
        .q(zoom_mode)
    );

    // -------------------------------------------------------------------------
    // 2. SCALING FUNCTION (Write-Side)
    // -------------------------------------------------------------------------
    // Mode 0: 1x (Window [14:8])
    // Mode 1: 2x (Window [13:7])
    // Mode 2: 4x (Window [12:6]) - Usually better for shifts than 3x
    function [7:0] scale_sample;
        input [15:0] sample;
        input [1:0]  mode;
        begin
            case (mode)
                2'd1: begin // 2x Zoom
                    if (~sample[15] && sample[14])           scale_sample = 8'hFF; // Saturation
                    else if (sample[15] && !sample[14])      scale_sample = 8'h00; 
                    else scale_sample = {~sample[15], sample[13:7]};
                end
                2'd2: begin // 4x Zoom
                    if (~sample[15] && |sample[14:13])       scale_sample = 8'hFF;
                    else if (sample[15] && !(&sample[14:13])) scale_sample = 8'h00;
                    else scale_sample = {~sample[15], sample[12:6]};
                end
                default: begin // 1x Zoom
                    scale_sample = {~sample[15], sample[14:8]};
                end
            endcase
        end
    endfunction

    // Apply scaling to data BEFORE it is written to RAM
    wire [7:0] write_sum = scale_sample(sum_sample,    zoom_mode);
    wire [7:0] write_v0  = scale_sample(voice0_sample, zoom_mode);
    wire [7:0] write_v1  = scale_sample(voice1_sample, zoom_mode);
    wire [7:0] write_v2  = scale_sample(voice2_sample, zoom_mode);

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
    
    wire [7:0] read_sum;
    wire [7:0] read_v0;
    wire [7:0] read_v1;
    wire [7:0] read_v2;

    wire [8:0] read_address_sum;
    wire [8:0] read_address_v0;
    wire [8:0] read_address_v1;
    wire [8:0] read_address_v2;

    // RAM Instantiations (Ping-Pong Buffers)
    // sum_ram
    ram_1w2r #(.WIDTH(8), .DEPTH(9)) sum_ram(
        .clka(clk), .wea(write_enable), .addra(write_address), .dina(write_sum),
        .clkb(clk), .addrb({read_index, read_address_sum[7:0]}), .doutb(read_sum),
        .douta() 
    );
    
    // v0_ram dina connection
    ram_1w2r #(.WIDTH(8), .DEPTH(9)) voice0_ram(
        .clka(clk), .wea(write_enable), .addra(write_address), .dina(write_v0),
        .clkb(clk), .addrb({read_index, read_address_v0[7:0]}), .doutb(read_v0),
        .douta()
    );
    
    // v1_ram dina connection
    ram_1w2r #(.WIDTH(8), .DEPTH(9)) voice1_ram(
        .clka(clk), .wea(write_enable), .addra(write_address), .dina(write_v1),
        .clkb(clk), .addrb({read_index, read_address_v1[7:0]}), .doutb(read_v1),
        .douta()
    );
    
    // v2_ram dina connection
    ram_1w2r #(.WIDTH(8), .DEPTH(9)) voice2_ram(
        .clka(clk), .wea(write_enable), .addra(write_address), .dina(write_v2),
        .clkb(clk), .addrb({read_index, read_address_v2[7:0]}), .doutb(read_v2),
        .douta()
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