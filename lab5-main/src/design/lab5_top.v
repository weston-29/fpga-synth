module lab5_top(
    /*
    `define H_SYNC_PULSE 112
    `define H_BACK_PORCH 248
    `define H_FRONT_PORCH 48
    `define V_SYNC_PULSE 3
    `define V_BACK_PORCH 38
    `define V_FRONT_PORCH 1
    */

    // System Clock (125MHz)
    input sysclk,

    // ADAU_1761 interface
    output  AC_ADR0,
    output  AC_ADR1,

    output  AC_DOUT,
    input   AC_DIN,
    input   AC_BCLK,
    input   AC_WCLK,

    output  AC_MCLK,
    output  AC_SCK,
    inout   AC_SDA,

    // LEDs
    output wire [3:0] led,
    output wire [2:0] leds_rgb_0,
    output wire [2:0] leds_rgb_1,

    // Buttons
    input [2:0] btn,

    // HDMI output
    output TMDS_Clk_p,
    output TMDS_Clk_n,
    output [2:0] TMDS_Data_p,
    output [2:0] TMDS_Data_n
);

    // ------------------------------------------------------------
    // Button mapping
    // btn[2] = reset
    // btn[1] = play/pause
    // btn[0] = transport
    // ------------------------------------------------------------
    wire reset, play_button, next_button;
    assign {reset, play_button, next_button} = btn;

    // ------------------------------------------------------------
    // Clock generation
    // ------------------------------------------------------------
    wire clk_100, display_clk, serial_clk;
    wire LED0;

    clk_wiz_0 U2 (
        .clk_out1(clk_100),
        .clk_out2(display_clk),
        .clk_out3(serial_clk),
        .reset(reset),
        .locked(LED0),
        .clk_in1(sysclk)
    );

    parameter BPU_WIDTH  = 20;
    parameter BEAT_COUNT = 1000;

    // ------------------------------------------------------------
    // VGA / HDMI scan signals
    // ------------------------------------------------------------
    wire [11:0] x;
    wire [11:0] y;

    wire [31:0] pix_data;
    wire [3:0] r, g, b;
    wire [7:0] r_1, g_1, b_1;

    wire vde, hsync, vsync, blank;

    // ------------------------------------------------------------
    // Debounced one-pulse buttons
    // ------------------------------------------------------------
    wire play;
    button_press_unit #(.WIDTH(BPU_WIDTH)) play_button_press_unit(
        .clk(clk_100),
        .reset(reset),
        .in(play_button),
        .out(play)
    );

    wire next;
    button_press_unit #(.WIDTH(BPU_WIDTH)) next_button_press_unit(
        .clk(clk_100),
        .reset(reset),
        .in(next_button),
        .out(next)
    );

    // ------------------------------------------------------------
    // Music player signals
    // ------------------------------------------------------------
    wire new_frame;
    wire [15:0] codec_sample;
    wire [15:0] flopped_sample;
    wire new_sample;
    wire flopped_new_sample;

    // New enhanced-waveform signals
    wire [15:0] voice_wave_0;
    wire [15:0] voice_wave_1;
    wire [15:0] voice_wave_2;
    wire [15:0] sum_wave;

    music_player #(.BEAT_COUNT(BEAT_COUNT)) music_player(
        .clk(clk_100),
        .reset(reset),
        .play_button(play),
        .next_button(next),
        .new_frame(new_frame),
        .sample_out(codec_sample),
        .new_sample_generated(new_sample),
        .voice_wave_0(voice_wave_0),
        .voice_wave_1(voice_wave_1),
        .voice_wave_2(voice_wave_2),
        .sum_wave(sum_wave)
    );

    dff #(.WIDTH(17)) sample_reg (
        .clk(clk_100),
        .d({new_sample, codec_sample}),
        .q({flopped_new_sample, flopped_sample})
    );

    // ------------------------------------------------------------
    // Codec interface
    // ------------------------------------------------------------
    wire [23:0] hphone_r  = 24'd0;
    wire [23:0] line_in_l = 24'd0;
    wire [23:0] line_in_r = 24'd0;

    // LED debug from audio sample
    assign leds_rgb_0 = codec_sample[15:13];
    assign leds_rgb_1 = codec_sample[11:9];
    assign led        = codec_sample[15:12];

    adau1761_codec adau1761_codec(
        .clk_100(clk_100),
        .reset(reset),
        .AC_ADR0(AC_ADR0),
        .AC_ADR1(AC_ADR1),
        .I2S_MISO(AC_DOUT),
        .I2S_MOSI(AC_DIN),
        .I2S_bclk(AC_BCLK),
        .I2S_LR(AC_WCLK),
        .AC_MCLK(AC_MCLK),
        .AC_SCK(AC_SCK),
        .AC_SDA(AC_SDA),
        .hphone_l({codec_sample, 8'h00}),
        .hphone_r(hphone_r),
        .line_in_l(line_in_l),
        .line_in_r(line_in_r),
        .new_sample(new_frame)
    );

    // ------------------------------------------------------------
    // VGA timing
    // ------------------------------------------------------------
    vga_controller_800x480_60 vga_control (
        .pixel_clk(display_clk),
        .rst(reset),
        .HS(hsync),
        .VS(vsync),
        .VDE(vde),
        .hcount(x),
        .vcount(y),
        .blank(blank)
    );

    // ------------------------------------------------------------
    // Enhanced waveform display
    // ------------------------------------------------------------
    enhanced_wave_display_top ewd_top (
        .clk(clk_100),
        .reset(reset),
        .new_sample(new_sample),
        .sum_sample(sum_wave),
        .voice0_sample(voice_wave_0),
        .voice1_sample(voice_wave_1),
        .voice2_sample(voice_wave_2),
        .x(x[10:0]),
        .y(y[9:0]),
        .valid(vde),
        .vsync(vsync),
        .r(r_1),
        .g(g_1),
        .b(b_1)
    );

    // ------------------------------------------------------------
    // Pack RGB for HDMI
    // ------------------------------------------------------------
    assign r = r_1[7:4];
    assign g = g_1[7:4];
    assign b = b_1[7:4];

    assign pix_data = {
        8'b0,
        r[3], r[3], r[2], r[2], r[1], r[1], r[0], r[0],
        g[3], g[3], g[2], g[2], g[1], g[1], g[0], g[0],
        b[3], b[3], b[2], b[2], b[1], b[1], b[0], b[0]
    };

    // ------------------------------------------------------------
    // HDMI TX
    // ------------------------------------------------------------
    hdmi_tx_0 U3 (
        .pix_clk(display_clk),
        .pix_clkx5(serial_clk),
        .pix_clk_locked(LED0),
        .rst(reset),
        .pix_data(pix_data),
        .hsync(hsync),
        .vsync(vsync),
        .vde(vde),
        .TMDS_CLK_P(TMDS_Clk_p),
        .TMDS_CLK_N(TMDS_Clk_n),
        .TMDS_DATA_P(TMDS_Data_p),
        .TMDS_DATA_N(TMDS_Data_n)
    );

endmodule