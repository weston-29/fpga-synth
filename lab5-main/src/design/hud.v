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

    // ------------------------------------------------------------
    // Convert note codes to ASCII
    // ------------------------------------------------------------
    wire [31:0] past_ascii_0, past_ascii_1, past_ascii_2;
    wire [31:0] now_ascii_0,  now_ascii_1,  now_ascii_2;
    wire [31:0] next_ascii_0, next_ascii_1, next_ascii_2;

    // Display-side fix:
    // Show past note if tracker marks it valid OR if a nonzero note code
    // is already stored in the past slot.
    wire past_disp_valid_0, past_disp_valid_1, past_disp_valid_2;
    assign past_disp_valid_0 = past_valid_0 | (past_note_0 != 6'd0);
    assign past_disp_valid_1 = past_valid_1 | (past_note_1 != 6'd0);
    assign past_disp_valid_2 = past_valid_2 | (past_note_2 != 6'd0);

    note_code_to_ascii p0 (.note_valid(past_disp_valid_0), .note_code(past_note_0), .text_ascii(past_ascii_0));
    note_code_to_ascii p1 (.note_valid(past_disp_valid_1), .note_code(past_note_1), .text_ascii(past_ascii_1));
    note_code_to_ascii p2 (.note_valid(past_disp_valid_2), .note_code(past_note_2), .text_ascii(past_ascii_2));

    note_code_to_ascii n0 (.note_valid(now_valid_0),  .note_code(now_note_0),  .text_ascii(now_ascii_0));
    note_code_to_ascii n1 (.note_valid(now_valid_1),  .note_code(now_note_1),  .text_ascii(now_ascii_1));
    note_code_to_ascii n2 (.note_valid(now_valid_2),  .note_code(now_note_2),  .text_ascii(now_ascii_2));

    note_code_to_ascii f0 (.note_valid(next_valid_0), .note_code(next_note_0), .text_ascii(next_ascii_0));
    note_code_to_ascii f1 (.note_valid(next_valid_1), .note_code(next_note_1), .text_ascii(next_ascii_1));
    note_code_to_ascii f2 (.note_valid(next_valid_2), .note_code(next_note_2), .text_ascii(next_ascii_2));

    // ------------------------------------------------------------
    // Layout tuned for lab-kit visible region:
    // visible starts at x=88, y=32
    // place rows near bottom, closer together, pushed right
    // ------------------------------------------------------------
    localparam LABEL_X  = 11'd120;
    localparam V0_X     = 11'd270;
    localparam V1_X     = 11'd430;
    localparam V2_X     = 11'd590;

    localparam PAST_Y   = 10'd360;
    localparam NOW_Y    = 10'd398;
    localparam NEXT_Y   = 10'd436;

    // labels
    wire lbl_past_on, lbl_now_on, lbl_next_on;
    wire [11:0] lbl_past_rgb, lbl_now_rgb, lbl_next_rgb;

    text_renderer #(.TEXT_LEN(4)) past_label (
        .pixel_x(x),
        .pixel_y(y),
        .origin_x(LABEL_X),
        .origin_y(PAST_Y),
        .scale_sel(2'b01),
        .text_ascii({8'h50,8'h41,8'h53,8'h54}),
        .text_rgb(12'hFFF),
        .enable(valid),
        .pixel_on(lbl_past_on),
        .pixel_rgb(lbl_past_rgb)
    );

    text_renderer #(.TEXT_LEN(3)) now_label (
        .pixel_x(x),
        .pixel_y(y),
        .origin_x(LABEL_X),
        .origin_y(NOW_Y),
        .scale_sel(2'b01),
        .text_ascii({8'h4E,8'h4F,8'h57}),
        .text_rgb(12'hFFF),
        .enable(valid),
        .pixel_on(lbl_now_on),
        .pixel_rgb(lbl_now_rgb)
    );

    text_renderer #(.TEXT_LEN(4)) next_label (
        .pixel_x(x),
        .pixel_y(y),
        .origin_x(LABEL_X),
        .origin_y(NEXT_Y),
        .scale_sel(2'b01),
        .text_ascii({8'h4E,8'h45,8'h58,8'h54}),
        .text_rgb(12'hFFF),
        .enable(valid),
        .pixel_on(lbl_next_on),
        .pixel_rgb(lbl_next_rgb)
    );

    wire [8:0]  note_on;
    wire [11:0] note_rgb [0:8];

    text_renderer #(.TEXT_LEN(4)) past_v0 (
        .pixel_x(x), .pixel_y(y),
        .origin_x(V0_X), .origin_y(PAST_Y + 10'd4),
        .scale_sel(2'b00),
        .text_ascii(past_ascii_0),
        .text_rgb(12'hF00),
        .enable(valid),
        .pixel_on(note_on[0]),
        .pixel_rgb(note_rgb[0])
    );

    text_renderer #(.TEXT_LEN(4)) past_v1 (
        .pixel_x(x), .pixel_y(y),
        .origin_x(V1_X), .origin_y(PAST_Y + 10'd4),
        .scale_sel(2'b00),
        .text_ascii(past_ascii_1),
        .text_rgb(12'h0F0),
        .enable(valid),
        .pixel_on(note_on[1]),
        .pixel_rgb(note_rgb[1])
    );

    text_renderer #(.TEXT_LEN(4)) past_v2 (
        .pixel_x(x), .pixel_y(y),
        .origin_x(V2_X), .origin_y(PAST_Y + 10'd4),
        .scale_sel(2'b00),
        .text_ascii(past_ascii_2),
        .text_rgb(12'h00F),
        .enable(valid),
        .pixel_on(note_on[2]),
        .pixel_rgb(note_rgb[2])
    );

    text_renderer #(.TEXT_LEN(4)) now_v0 (
        .pixel_x(x), .pixel_y(y),
        .origin_x(V0_X), .origin_y(NOW_Y),
        .scale_sel(2'b01),
        .text_ascii(now_ascii_0),
        .text_rgb(12'hF00),
        .enable(valid),
        .pixel_on(note_on[3]),
        .pixel_rgb(note_rgb[3])
    );

    text_renderer #(.TEXT_LEN(4)) now_v1 (
        .pixel_x(x), .pixel_y(y),
        .origin_x(V1_X), .origin_y(NOW_Y),
        .scale_sel(2'b01),
        .text_ascii(now_ascii_1),
        .text_rgb(12'h0F0),
        .enable(valid),
        .pixel_on(note_on[4]),
        .pixel_rgb(note_rgb[4])
    );

    text_renderer #(.TEXT_LEN(4)) now_v2 (
        .pixel_x(x), .pixel_y(y),
        .origin_x(V2_X), .origin_y(NOW_Y),
        .scale_sel(2'b01),
        .text_ascii(now_ascii_2),
        .text_rgb(12'h00F),
        .enable(valid),
        .pixel_on(note_on[5]),
        .pixel_rgb(note_rgb[5])
    );

    text_renderer #(.TEXT_LEN(4)) next_v0 (
        .pixel_x(x), .pixel_y(y),
        .origin_x(V0_X), .origin_y(NEXT_Y + 10'd4),
        .scale_sel(2'b00),
        .text_ascii(next_ascii_0),
        .text_rgb(12'hF00),
        .enable(valid),
        .pixel_on(note_on[6]),
        .pixel_rgb(note_rgb[6])
    );

    text_renderer #(.TEXT_LEN(4)) next_v1 (
        .pixel_x(x), .pixel_y(y),
        .origin_x(V1_X), .origin_y(NEXT_Y + 10'd4),
        .scale_sel(2'b00),
        .text_ascii(next_ascii_1),
        .text_rgb(12'h0F0),
        .enable(valid),
        .pixel_on(note_on[7]),
        .pixel_rgb(note_rgb[7])
    );

    text_renderer #(.TEXT_LEN(4)) next_v2 (
        .pixel_x(x), .pixel_y(y),
        .origin_x(V2_X), .origin_y(NEXT_Y + 10'd4),
        .scale_sel(2'b00),
        .text_ascii(next_ascii_2),
        .text_rgb(12'h00F),
        .enable(valid),
        .pixel_on(note_on[8]),
        .pixel_rgb(note_rgb[8])
    );

    wire [11:0] hud_rgb =
        lbl_now_on  ? lbl_now_rgb  :
        lbl_past_on ? lbl_past_rgb :
        lbl_next_on ? lbl_next_rgb :
        note_on[0]  ? note_rgb[0]  :
        note_on[1]  ? note_rgb[1]  :
        note_on[2]  ? note_rgb[2]  :
        note_on[3]  ? note_rgb[3]  :
        note_on[4]  ? note_rgb[4]  :
        note_on[5]  ? note_rgb[5]  :
        note_on[6]  ? note_rgb[6]  :
        note_on[7]  ? note_rgb[7]  :
        note_on[8]  ? note_rgb[8]  :
                      12'h000;

    assign pixel_on = lbl_past_on | lbl_now_on | lbl_next_on | (|note_on);

    assign r = {hud_rgb[11:8], hud_rgb[11:8]};
    assign g = {hud_rgb[7:4],  hud_rgb[7:4]};
    assign b = {hud_rgb[3:0],  hud_rgb[3:0]};

endmodule