`timescale 1ns/1ps

module note_player_tb;
    reg clk = 1'b0;
    reg reset = 1'b1;
    reg play_enable = 1'b0;
    reg [5:0] note_to_load = 6'd0;
    reg [5:0] duration_to_load = 6'd0;
    reg [2:0] note_metadata = 3'd0;
    reg load_new_note = 1'b0;
    reg beat = 1'b0;
    reg generate_next_sample = 1'b0;

    wire done_with_note;
    wire [15:0] sample_out;
    wire new_sample_ready;

    note_player dut (
        .clk(clk),
        .reset(reset),
        .play_enable(play_enable),
        .note_to_load(note_to_load),
        .duration_to_load(duration_to_load),
        .note_metadata(note_metadata),
        .load_new_note(load_new_note),
        .done_with_note(done_with_note),
        .beat(beat),
        .generate_next_sample(generate_next_sample),
        .sample_out(sample_out),
        .new_sample_ready(new_sample_ready)
    );

    always #5 clk = ~clk;

    integer cycles;
    integer nonzero_samples;
    integer ready_pulses;

    task load_voice;
        input [5:0] n;
        input [5:0] d;
        input [1:0] v;
        begin
            @(posedge clk);
            note_to_load <= n;
            duration_to_load <= d;
            note_metadata <= {1'b0, v};
            load_new_note <= 1'b1;
            @(posedge clk);
            load_new_note <= 1'b0;
        end
    endtask

    initial begin
        // Reset and start audio stepping.
        repeat (4) @(posedge clk);
        reset <= 1'b0;
        play_enable <= 1'b1;
        generate_next_sample <= 1'b1;

        // Load a triad across 3 voices.
        load_voice(6'd40, 6'd3, 2'd0); // C-ish
        load_voice(6'd44, 6'd3, 2'd1); // E-ish
        load_voice(6'd47, 6'd3, 2'd2); // G-ish

        // During active duration, expect non-zero samples.
        nonzero_samples = 0;
        ready_pulses = 0;
        for (cycles = 0; cycles < 60; cycles = cycles + 1) begin
            @(posedge clk);
            beat <= ((cycles % 10) == 0); // 6 beat pulses over loop
            if (new_sample_ready) ready_pulses = ready_pulses + 1;
            if (sample_out !== 16'd0) nonzero_samples = nonzero_samples + 1;
        end

        if (ready_pulses == 0) begin
            $display("ERROR: no sample-ready pulses observed");
            $finish;
        end
        if (nonzero_samples == 0) begin
            $display("ERROR: no non-zero mixed output samples observed");
            $finish;
        end

        // After enough beats, all durations should expire and output should return to silence.
        repeat (40) begin
            @(posedge clk);
            beat <= 1'b1;
        end
        @(posedge clk);
        beat <= 1'b0;

        // Internal visibility check for voice duration counters.
        if (dut.dur_0 != 0 || dut.dur_1 != 0 || dut.dur_2 != 0) begin
            $display("ERROR: expected all voices expired, got dur_0=%0d dur_1=%0d dur_2=%0d",
                     dut.dur_0, dut.dur_1, dut.dur_2);
            $finish;
        end

        // Give pipeline a moment; sample should settle to zero.
        repeat (6) @(posedge clk);
        if (sample_out !== 16'd0) begin
            $display("ERROR: expected silence after durations expired, sample_out=%0d", $signed(sample_out));
            $finish;
        end

        $display("PASS: note_player 3-voice chord/mix behavior looks correct.");
        $finish;
    end
endmodule
