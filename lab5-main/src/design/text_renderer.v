module text_renderer #(
    parameter TEXT_LEN = 4
)(
    input  wire [10:0] pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire [10:0] origin_x,
    input  wire [9:0]  origin_y,
    input  wire [1:0]  scale_sel,   // 00=1x, 01=2x, 10=4x, 11=8x
    input  wire [8*TEXT_LEN-1:0] text_ascii,
    input  wire [11:0] text_rgb,
    input  wire        enable,

    output wire        pixel_on,
    output wire [11:0] pixel_rgb
);

    localparam CHAR_W = 8;
    localparam CHAR_H = 8;

    wire [1:0] scale_shift;
    assign scale_shift = scale_sel;

    wire [10:0] scaled_char_w = (CHAR_W << scale_shift);
    wire [9:0]  scaled_char_h = (CHAR_H << scale_shift);
    wire [10:0] total_w       = TEXT_LEN * scaled_char_w;
    wire [9:0]  total_h       = scaled_char_h;

    wire in_box =
        enable &&
        (pixel_x >= origin_x) &&
        (pixel_x <  origin_x + total_w) &&
        (pixel_y >= origin_y) &&
        (pixel_y <  origin_y + total_h);

    wire [10:0] rel_x = pixel_x - origin_x;
    wire [9:0]  rel_y = pixel_y - origin_y;

    wire [10:0] font_x = rel_x >> scale_shift;
    wire [9:0]  font_y = rel_y >> scale_shift;

    wire [7:0] char_index = font_x[10:3];
    wire [2:0] char_col   = font_x[2:0];
    wire [2:0] char_row   = font_y[2:0];

    function [7:0] get_char;
        input [8*TEXT_LEN-1:0] packed_text;
        input [7:0] idx;
        integer base;
        begin
            if (idx < TEXT_LEN) begin
                base = 8 * (TEXT_LEN - 1 - idx);
                get_char = packed_text[base +: 8];
            end else begin
                get_char = 8'h20;
            end
        end
    endfunction

    wire [7:0] ascii_char;
    assign ascii_char = get_char(text_ascii, char_index);

    wire [7:0] glyph_bits;

    char_row_rom row_lookup (
        .ascii(ascii_char),
        .row(char_row),
        .bits(glyph_bits)
    );

    wire glyph_pixel;
    assign glyph_pixel = glyph_bits[7 - char_col];

    assign pixel_on  = in_box && glyph_pixel;
    assign pixel_rgb = pixel_on ? text_rgb : 12'h000;

endmodule