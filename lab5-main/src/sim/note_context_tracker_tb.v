`timescale 1ns/1ps

module note_context_tracker_tb;

    reg clk;
    reg reset;
    reg [1:0] song_sel;

    reg [5:0] curr_note_0, curr_note_1, curr_note_2;
    reg       curr_valid_0, curr_valid_1, curr_valid_2;
    reg       load_note_0, load_note_1, load_note_2;

    reg       event_new_note;
    reg [5:0] event_note;
    reg [2:0] event_metadata;
    reg [6:0] event_index;

    wire [5:0] past_note_0, past_note_1, past_note_2;
    wire       past_valid_0, past_valid_1, past_valid_2;
    wire [5:0] now_note_0, now_note_1, now_note_2;
    wire       now_valid_0, now_valid_1, now_valid_2;
    wire [5:0] next_note_0, next_note_1, next_note_2;
    wire       next_valid_0, next_valid_1, next_valid_2;

    integer errors;
    integer i;

    note_context_tracker dut (
        .clk(clk),
        .reset(reset),
        .song_sel(song_sel),
        .curr_note_0(curr_note_0),
        .curr_note_1(curr_note_1),
        .curr_note_2(curr_note_2),
        .curr_valid_0(curr_valid_0),
        .curr_valid_1(curr_valid_1),
        .curr_valid_2(curr_valid_2),
        .load_note_0(load_note_0),
        .load_note_1(load_note_1),
        .load_note_2(load_note_2),
        .event_new_note(event_new_note),
        .event_note(event_note),
        .event_metadata(event_metadata),
        .event_index(event_index),
        .past_note_0(past_note_0),
        .past_note_1(past_note_1),
        .past_note_2(past_note_2),
        .past_valid_0(past_valid_0),
        .past_valid_1(past_valid_1),
        .past_valid_2(past_valid_2),
        .now_note_0(now_note_0),
        .now_note_1(now_note_1),
        .now_note_2(now_note_2),
        .now_valid_0(now_valid_0),
        .now_valid_1(now_valid_1),
        .now_valid_2(now_valid_2),
        .next_note_0(next_note_0),
        .next_note_1(next_note_1),
        .next_note_2(next_note_2),
        .next_valid_0(next_valid_0),
        .next_valid_1(next_valid_1),
        .next_valid_2(next_valid_2)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task check_equal_6;
        input [5:0] got;
        input [5:0] exp;
        input [255:0] label;
        begin
            if (got !== exp) begin
                $display("FAIL %0s got=%0d exp=%0d", label, got, exp);
                errors = errors + 1;
            end else begin
                $display("PASS %0s = %0d", label, got);
            end
        end
    endtask

    task check_equal_1;
        input got;
        input exp;
        input [255:0] label;
        begin
            if (got !== exp) begin
                $display("FAIL %0s got=%0b exp=%0b", label, got, exp);
                errors = errors + 1;
            end else begin
                $display("PASS %0s = %0b", label, got);
            end
        end
    endtask

    task wait_for_cycles;
        input integer cycles;
        integer k;
        begin
            for (k = 0; k < cycles; k = k + 1)
                tick;
        end
    endtask

    task trigger_event;
        input [6:0] idx;
        input [5:0] note;
        input [2:0] md;
        begin
            event_index    = idx;
            event_note     = note;
            event_metadata = md;
            event_new_note = 1'b1;
            tick;
            event_new_note = 1'b0;
        end
    endtask

    // Wait until the chosen next_valid bit asserts, or timeout.
    // This is more robust than hard-coding a cycle count because the
    // search distance depends on how far ahead the next same-voice note is.
    task wait_for_next_valid;
        input [1:0] voice;
        input integer timeout_cycles;
        reg seen;
        integer k;
        begin
            seen = 1'b0;
            for (k = 0; k < timeout_cycles; k = k + 1) begin
                if (((voice == 2'd0) && next_valid_0) ||
                    ((voice == 2'd1) && next_valid_1) ||
                    ((voice == 2'd2) && next_valid_2)) begin
                    seen = 1'b1;
                    k = timeout_cycles;
                end else begin
                    tick;
                end
            end

            if (!seen) begin
                $display("FAIL timeout waiting for next_valid_%0d", voice);
                errors = errors + 1;
            end
        end
    endtask

    task load_voice0;
        input [5:0] next_note;
        input       next_valid;
        begin
            load_note_0 = 1'b1;
            tick;
            load_note_0 = 1'b0;
            curr_note_0 = next_note;
            curr_valid_0 = next_valid;
            #1;
        end
    endtask

    task load_voice1;
        input [5:0] next_note;
        input       next_valid;
        begin
            load_note_1 = 1'b1;
            tick;
            load_note_1 = 1'b0;
            curr_note_1 = next_note;
            curr_valid_1 = next_valid;
            #1;
        end
    endtask

    task load_voice2;
        input [5:0] next_note;
        input       next_valid;
        begin
            load_note_2 = 1'b1;
            tick;
            load_note_2 = 1'b0;
            curr_note_2 = next_note;
            curr_valid_2 = next_valid;
            #1;
        end
    endtask

    initial begin
        errors = 0;

        song_sel       = 2'b00;
        curr_note_0    = 6'd0;
        curr_note_1    = 6'd0;
        curr_note_2    = 6'd0;
        curr_valid_0   = 1'b0;
        curr_valid_1   = 1'b0;
        curr_valid_2   = 1'b0;
        load_note_0    = 1'b0;
        load_note_1    = 1'b0;
        load_note_2    = 1'b0;
        event_new_note = 1'b0;
        event_note     = 6'd0;
        event_metadata = 3'd0;
        event_index    = 7'd0;
        reset          = 1'b1;

        tick;
        tick;
        reset = 1'b0;

        $display("\n=== TEST 1: reset initializes next-row lookahead from song start ===");
        wait_for_cycles(8);
        check_equal_6(next_note_0, 6'd40, "next voice0 after reset");
        check_equal_6(next_note_1, 6'd45, "next voice1 after reset");
        check_equal_6(next_note_2, 6'd47, "next voice2 after reset");
        check_equal_1(next_valid_0, 1'b1, "next_valid_0 after reset");
        check_equal_1(next_valid_1, 1'b1, "next_valid_1 after reset");
        check_equal_1(next_valid_2, 1'b1, "next_valid_2 after reset");

        $display("\n=== TEST 2: now-row mirrors live current note inputs ===");
        curr_note_0  = 6'd40; curr_valid_0 = 1'b1;
        curr_note_1  = 6'd45; curr_valid_1 = 1'b1;
        curr_note_2  = 6'd47; curr_valid_2 = 1'b1;
        #1;
        check_equal_6(now_note_0, 6'd40, "now_note_0 mirror");
        check_equal_6(now_note_1, 6'd45, "now_note_1 mirror");
        check_equal_6(now_note_2, 6'd47, "now_note_2 mirror");
        check_equal_1(now_valid_0, 1'b1, "now_valid_0 mirror");
        check_equal_1(now_valid_1, 1'b1, "now_valid_1 mirror");
        check_equal_1(now_valid_2, 1'b1, "now_valid_2 mirror");

        $display("\n=== TEST 3: past-row captures previous live voice on load pulse ===");
        load_voice0(6'd42, 1'b1);
        check_equal_6(past_note_0, 6'd40, "past_note_0 after second voice0 load");
        check_equal_1(past_valid_0, 1'b1, "past_valid_0 after second voice0 load");
        check_equal_6(now_note_0, 6'd42, "now_note_0 after second voice0 load");

        load_voice1(6'd49, 1'b1);
        check_equal_6(past_note_1, 6'd45, "past_note_1 after second voice1 load");
        check_equal_1(past_valid_1, 1'b1, "past_valid_1 after second voice1 load");
        check_equal_6(now_note_1, 6'd49, "now_note_1 after second voice1 load");

        load_voice2(6'd50, 1'b1);
        check_equal_6(past_note_2, 6'd47, "past_note_2 after second voice2 load");
        check_equal_1(past_valid_2, 1'b1, "past_valid_2 after second voice2 load");
        check_equal_6(now_note_2, 6'd50, "now_note_2 after second voice2 load");

        $display("\n=== TEST 4: event-driven lookahead finds next note for each voice ===");
        trigger_event(7'd0, 6'd40, 3'b000);
        wait_for_next_valid(2'd0, 20);
        check_equal_6(next_note_0, 6'd42, "next voice0 after event index 0");
        check_equal_1(next_valid_0, 1'b1, "next_valid_0 after event index 0");

        trigger_event(7'd1, 6'd45, 3'b001);
        wait_for_next_valid(2'd1, 20);
        check_equal_6(next_note_1, 6'd49, "next voice1 after event index 1");
        check_equal_1(next_valid_1, 1'b1, "next_valid_1 after event index 1");

        trigger_event(7'd2, 6'd47, 3'b010);
        wait_for_next_valid(2'd2, 24);
        check_equal_6(next_note_2, 6'd50, "next voice2 after event index 2");
        check_equal_1(next_valid_2, 1'b1, "next_valid_2 after event index 2");

        $display("\n=== TEST 5: alias metadata 2'b11 maps to voice0 ===");
        trigger_event(7'd4, 6'd42, 3'b011);
        wait_for_cycles(20);
        check_equal_6(next_note_0, 6'd0, "next voice0 after final note via alias metadata");
        check_equal_1(next_valid_0, 1'b0, "next_valid_0 after final note via alias metadata");

        $display("\n=== TEST 6: song change clears rows and restarts lookahead ===");
        song_sel = 2'b01;
        tick;
        wait_for_cycles(8);
        check_equal_6(past_note_0, 6'd0, "past_note_0 after song change");
        check_equal_6(past_note_1, 6'd0, "past_note_1 after song change");
        check_equal_6(past_note_2, 6'd0, "past_note_2 after song change");
        check_equal_1(past_valid_0, 1'b0, "past_valid_0 after song change");
        check_equal_1(past_valid_1, 1'b0, "past_valid_1 after song change");
        check_equal_1(past_valid_2, 1'b0, "past_valid_2 after song change");
        check_equal_6(next_note_0, 6'd52, "next voice0 at start of song1");
        check_equal_6(next_note_1, 6'd55, "next voice1 at start of song1");
        check_equal_6(next_note_2, 6'd57, "next voice2 at start of song1");

        $display("\n=== RESULTS: %0d error(s) ===", errors);
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TEST FAILED");

        $finish;
    end

endmodule

module song_rom(
    input  wire        clk,
    input  wire [8:0]  addr,
    output reg  [15:0] dout
);

    function [15:0] note_cmd;
        input [5:0] note;
        input [5:0] duration;
        input [2:0] md;
        begin
            note_cmd = {1'b0, note, duration, md};
        end
    endfunction

    function [15:0] wait_cmd;
        input [5:0] ticks;
        begin
            wait_cmd = {1'b1, 9'd0, ticks};
        end
    endfunction

    always @(*) begin
        case (addr)
            9'd0:   dout = note_cmd(6'd40, 6'd4, 3'b000);
            9'd1:   dout = note_cmd(6'd45, 6'd3, 3'b001);
            9'd2:   dout = note_cmd(6'd47, 6'd2, 3'b010);
            9'd3:   dout = wait_cmd(6'd2);
            9'd4:   dout = note_cmd(6'd42, 6'd5, 3'b000);
            9'd5:   dout = note_cmd(6'd49, 6'd4, 3'b001);
            9'd6:   dout = wait_cmd(6'd1);
            9'd7:   dout = note_cmd(6'd50, 6'd3, 3'b010);

            9'd128: dout = note_cmd(6'd52, 6'd4, 3'b000);
            9'd129: dout = note_cmd(6'd55, 6'd4, 3'b001);
            9'd130: dout = note_cmd(6'd57, 6'd4, 3'b010);
            9'd131: dout = wait_cmd(6'd2);
            9'd132: dout = note_cmd(6'd54, 6'd4, 3'b000);
            9'd133: dout = note_cmd(6'd59, 6'd4, 3'b001);
            9'd134: dout = note_cmd(6'd60, 6'd4, 3'b010);

            default: dout = wait_cmd(6'd0);
        endcase
    end

endmodule
