module hud (
    input  wire [10:0] x,
    input  wire [9:0]  y,
    input  wire        valid,

    output wire        pixel_on,
    output wire [7:0]  r,
    output wire [7:0]  g,
    output wire [7:0]  b
);

    wire txt1_on, txt2_on, txt3_on;
    wire [11:0] txt1_rgb, txt2_rgb, txt3_rgb;

    // Small line near upper-left
    text_renderer #(
        .TEXT_LEN(8)
    ) text_line_1 (
        .pixel_x(x),
        .pixel_y(y),
        .origin_x(11'd40),
        .origin_y(10'd40),
        .scale_sel(2'b01), // 2x
        .text_ascii({
            8'h45, // E
            8'h45, // E
            8'h31, // 1
            8'h30, // 0
            8'h38, // 8
            8'h20, // space
            8'h54, // T
            8'h45  // E
        }), // "EE108 TE"
        .text_rgb(12'h0FF), // cyan
        .enable(valid),
        .pixel_on(txt1_on),
        .pixel_rgb(txt1_rgb)
    );

    // Large title more toward center
    text_renderer #(
        .TEXT_LEN(6)
    ) text_line_2 (
        .pixel_x(x),
        .pixel_y(y),
        .origin_x(11'd220),
        .origin_y(10'd140),
        .scale_sel(2'b10), // 4x
        .text_ascii({
            8'h4C, // L
            8'h41, // A
            8'h42, // B
            8'h20, // space
            8'h35, // 5
            8'h21  // !
        }), // "LAB 5!"
        .text_rgb(12'hF00), // red
        .enable(valid),
        .pixel_on(txt2_on),
        .pixel_rgb(txt2_rgb)
    );

    // Medium line lower on screen
    text_renderer #(
        .TEXT_LEN(10)
    ) text_line_3 (
        .pixel_x(x),
        .pixel_y(y),
        .origin_x(11'd120),
        .origin_y(10'd300),
        .scale_sel(2'b01), // 2x
        .text_ascii({
            8'h43, // C
            8'h23, // #
            8'h34, // 4
            8'h20, // space
            8'h45, // E
            8'h34, // 4
            8'h20, // space
            8'h47, // G
            8'h34, // 4
            8'h20  // space
        }), // "C#4 E4 G4 "
        .text_rgb(12'h0F0), // green
        .enable(valid),
        .pixel_on(txt3_on),
        .pixel_rgb(txt3_rgb)
    );

    wire [11:0] hud_rgb;
    assign hud_rgb =
        txt2_on ? txt2_rgb :
        txt1_on ? txt1_rgb :
        txt3_on ? txt3_rgb :
        12'h000;

    assign pixel_on = txt1_on | txt2_on | txt3_on;

    assign r = {hud_rgb[11:8], hud_rgb[11:8]};
    assign g = {hud_rgb[7:4],  hud_rgb[7:4]};
    assign b = {hud_rgb[3:0],  hud_rgb[3:0]};

endmodule