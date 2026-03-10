`timescale 1ns/1ps

module song_reader_tb;
    reg clk = 1'b0;
    reg reset = 1'b1;
    reg play = 1'b0;
    reg [1:0] song = 2'b00;
    reg beat = 1'b0;

    wire song_done;
    wire [5:0] note;
    wire [5:0] duration;
    wire [2:0] note_metadata;
    wire new_note;

    // DUT
    song_reader dut (
        .clk(clk),
        .reset(reset),
        .play(play),
        .song(song),
        .beat(beat),
        .song_done(song_done),
        .note(note),
        .duration(duration),
        .note_metadata(note_metadata),
        .new_note(new_note)
    );

    // 100MHz-ish sim clock
    always #5 clk = ~clk;

    integer seen_idx = 0;
    integer i;
    reg [5:0] exp_note [0:3];
    reg [5:0] exp_dur [0:3];
    reg [2:0] exp_meta [0:3];

    initial begin
        // Expected schedule sequence from mocked ROM below.
        exp_note[0] = 6'd10; exp_dur[0] = 6'd4; exp_meta[0] = 3'd0;
        exp_note[1] = 6'd14; exp_dur[1] = 6'd4; exp_meta[1] = 3'd1;
        exp_note[2] = 6'd17; exp_dur[2] = 6'd4; exp_meta[2] = 3'd2;
        exp_note[3] = 6'd22; exp_dur[3] = 6'd8; exp_meta[3] = 3'd0;

        // Reset
        repeat (4) @(posedge clk);
        reset <= 1'b0;
        play <= 1'b1;

        // Run and periodically pulse beat so WAIT commands advance.
        for (i = 0; i < 220; i = i + 1) begin
            @(posedge clk);
            beat <= ((i % 4) == 0);

            if (new_note) begin
                if (seen_idx > 3) begin
                    $display("ERROR: saw unexpected extra new_note at t=%0t", $time);
                    $finish;
                end

                if (note !== exp_note[seen_idx] ||
                    duration !== exp_dur[seen_idx] ||
                    note_metadata !== exp_meta[seen_idx]) begin
                    $display("ERROR: schedule mismatch idx=%0d got n=%0d d=%0d m=%0d expected n=%0d d=%0d m=%0d",
                             seen_idx, note, duration, note_metadata,
                             exp_note[seen_idx], exp_dur[seen_idx], exp_meta[seen_idx]);
                    $finish;
                end
                seen_idx = seen_idx + 1;
            end
        end

        if (seen_idx != 4) begin
            $display("ERROR: expected 4 scheduled notes, saw %0d", seen_idx);
            $finish;
        end

        $display("PASS: song_reader schedule/wait behavior looks correct.");
        $finish;
    end
endmodule

// -----------------------------------------------------------------------------
// Mock song ROM used only for this testbench.
// -----------------------------------------------------------------------------
module song_rom (
    input clk,
    input [8:0] addr,
    output reg [15:0] dout
);
    reg [15:0] memory [0:511];
    integer k;

    initial begin
        for (k = 0; k < 512; k = k + 1) memory[k] = 16'h8000; // wait 0

        // song 0 program:
        // S 10 dur4 voice0
        // S 14 dur4 voice1
        // S 17 dur4 voice2
        // W 4
        // S 22 dur8 voice0
        // W 8
        memory[0] = {1'b0, 6'd10, 6'd4, 3'd0};
        memory[1] = {1'b0, 6'd14, 6'd4, 3'd1};
        memory[2] = {1'b0, 6'd17, 6'd4, 3'd2};
        memory[3] = {1'b1, 9'd0, 6'd4};
        memory[4] = {1'b0, 6'd22, 6'd8, 3'd0};
        memory[5] = {1'b1, 9'd0, 6'd8};
    end

    always @(posedge clk) begin
        dout <= memory[addr];
    end
endmodule
