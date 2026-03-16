module hud (
    input  wire [10:0] x,
    input  wire [9:0]  y,
    input  wire        valid,

    // Past row
    input  wire [5:0] past_note_0,
    input  wire [5:0] past_note_1,
    input  wire [5:0] past_note_2,
    input  wire       past_valid_0,
    input  wire       past_valid_1,
    input  wire       past_valid_2,

    // Current row
    input  wire [5:0] now_note_0,
    input  wire [5:0] now_note_1,
    input  wire [5:0] now_note_2,
    input  wire       now_valid_0,
    input  wire       now_valid_1,
    input  wire       now_valid_2,

    // Future row
    input  wire [5:0] next_note_0,
    input  wire [5:0] next_note_1,
    input  wire [5:0] next_note_2,
    input  wire       next_valid_0,
    input  wire       next_valid_1,
    input  wire       next_valid_2,

    output wire       pixel_on,
    output wire [7:0] r,
    output wire [7:0] g,
    output wire [7:0] b
);

    localparam [7:0] CH_SP = 8'h20;

    // ------------------------------------------------------------
    // Convert note codes to ASCII
    // Keep the reduced 4-renderer structure that was helping timing.
    // Minimal fix: NEXT uses a display-side valid fallback, because the
    // tracker appears to be providing note codes while next_valid drops.
    // ------------------------------------------------------------
    wire [31:0] past_ascii_0, past_ascii_1, past_ascii_2;
    wire [31:0] now_ascii_0,  now_ascii_1,  now_ascii_2;
    wire [31:0] next_ascii_0, next_ascii_1, next_ascii_2;

    wire past_disp_valid_0, past_disp_valid_1, past_disp_valid_2;
    assign past_disp_valid_0 = past_valid_0 | (past_note_0 != 6'd0);
    assign past_disp_valid_1 = past_valid_1 | (past_note_1 != 6'd0);
    assign past_disp_valid_2 = past_valid_2 | (past_note_2 != 6'd0);

    wire next_disp_valid_0, next_disp_valid_1, next_disp_valid_2;
    assign next_disp_valid_0 = next_valid_0 | (next_note_0 != 6'd0);
    assign next_disp_valid_1 = next_valid_1 | (next_note_1 != 6'd0);
    assign next_disp_valid_2 = next_valid_2 | (next_note_2 != 6'd0);

    note_code_to_ascii p0 (.note_valid(past_disp_valid_0), .note_code(past_note_0), .text_ascii(past_ascii_0));
    note_code_to_ascii p1 (.note_valid(past_disp_valid_1), .note_code(past_note_1), .text_ascii(past_ascii_1));
    note_code_to_ascii p2 (.note_valid(past_disp_valid_2), .note_code(past_note_2), .text_ascii(past_ascii_2));

    note_code_to_ascii n0 (.note_valid(now_valid_0),  .note_code(now_note_0),  .text_ascii(now_ascii_0));
    note_code_to_ascii n1 (.note_valid(now_valid_1),  .note_code(now_note_1),  .text_ascii(now_ascii_1));
    note_code_to_ascii n2 (.note_valid(now_valid_2),  .note_code(now_note_2),  .text_ascii(now_ascii_2));

    note_code_to_ascii f0 (.note_valid(next_disp_valid_0), .note_code(next_note_0), .text_ascii(next_ascii_0));
    note_code_to_ascii f1 (.note_valid(next_disp_valid_1), .note_code(next_note_1), .text_ascii(next_ascii_1));
    note_code_to_ascii f2 (.note_valid(next_disp_valid_2), .note_code(next_note_2), .text_ascii(next_ascii_2));

    // ------------------------------------------------------------
    // Reduced-renderer layout
    // 17 chars wide, explicitly matched across all rows.
    // Character positions:
    //  0..3   PAST
    //  4..6   spaces
    //  7..10  NOW
    // 11..12  spaces
    // 13..16  NEXT
    // ------------------------------------------------------------
    localparam HUD_X    = 11'd170;
    localparam LABEL_Y  = 10'd352;
    localparam V0_Y     = 10'd384;
    localparam V1_Y     = 10'd416;
    localparam V2_Y     = 10'd448;

    localparam [8*17-1:0] LABEL_TEXT = {
        8'h50,8'h41,8'h53,8'h54,
        CH_SP,CH_SP,CH_SP,
        8'h4E,8'h4F,8'h57,CH_SP,
        CH_SP,CH_SP,
        8'h4E,8'h45,8'h58,8'h54
    };

    wire [8*17-1:0] voice0_text = {
        past_ascii_0,
        CH_SP,CH_SP,CH_SP,
        now_ascii_0,
        CH_SP,CH_SP,
        next_ascii_0
    };

    wire [8*17-1:0] voice1_text = {
        past_ascii_1,
        CH_SP,CH_SP,CH_SP,
        now_ascii_1,
        CH_SP,CH_SP,
        next_ascii_1
    };

    wire [8*17-1:0] voice2_text = {
        past_ascii_2,
        CH_SP,CH_SP,CH_SP,
        now_ascii_2,
        CH_SP,CH_SP,
        next_ascii_2
    };

    wire        label_on, v0_on, v1_on, v2_on;
    wire [11:0] label_rgb, v0_rgb, v1_rgb, v2_rgb;

    text_renderer #(.TEXT_LEN(17)) labels_row (
        .pixel_x(x),
        .pixel_y(y),
        .origin_x(HUD_X),
        .origin_y(LABEL_Y),
        .scale_sel(2'b00),
        .text_ascii(LABEL_TEXT),
        .text_rgb(12'hFFF),
        .enable(valid),
        .pixel_on(label_on),
        .pixel_rgb(label_rgb)
    );

    text_renderer #(.TEXT_LEN(17)) voice0_row (
        .pixel_x(x),
        .pixel_y(y),
        .origin_x(HUD_X),
        .origin_y(V0_Y),
        .scale_sel(2'b00),
        .text_ascii(voice0_text),
        .text_rgb(12'hF00),
        .enable(valid),
        .pixel_on(v0_on),
        .pixel_rgb(v0_rgb)
    );

    text_renderer #(.TEXT_LEN(17)) voice1_row (
        .pixel_x(x),
        .pixel_y(y),
        .origin_x(HUD_X),
        .origin_y(V1_Y),
        .scale_sel(2'b00),
        .text_ascii(voice1_text),
        .text_rgb(12'h0F0),
        .enable(valid),
        .pixel_on(v1_on),
        .pixel_rgb(v1_rgb)
    );

    text_renderer #(.TEXT_LEN(17)) voice2_row (
        .pixel_x(x),
        .pixel_y(y),
        .origin_x(HUD_X),
        .origin_y(V2_Y),
        .scale_sel(2'b00),
        .text_ascii(voice2_text),
        .text_rgb(12'h00F),
        .enable(valid),
        .pixel_on(v2_on),
        .pixel_rgb(v2_rgb)
    );

    wire [11:0] hud_rgb =
        label_on ? label_rgb :
        v0_on    ? v0_rgb    :
        v1_on    ? v1_rgb    :
        v2_on    ? v2_rgb    :
                   12'h000;

    assign pixel_on = label_on | v0_on | v1_on | v2_on;

    assign r = {hud_rgb[11:8], hud_rgb[11:8]};
    assign g = {hud_rgb[7:4],  hud_rgb[7:4]};
    assign b = {hud_rgb[3:0],  hud_rgb[3:0]};

endmodule
