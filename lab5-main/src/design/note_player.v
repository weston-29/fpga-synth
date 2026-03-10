module note_player(
    input clk,
    input reset,
    input play_enable,  // When high we play, when low we don't.
    input [5:0] note_to_load,  // The note to play
    input [5:0] duration_to_load,  // The duration of the note to play
    input [2:0] note_metadata,  // Metadata from song format; [1:0] selects voice
    input load_new_note,  // Tells us when we have a new note to load
    output done_with_note,  // When we are done with the note this stays high.
    input beat,  // This is our 1/48th second beat
    input generate_next_sample,  // Tells us when the codec wants a new sample
    output [15:0] sample_out,  // Our sample output
    output new_sample_ready  // Tells the codec when we've got a sample
);
    wire [1:0] requested_voice = note_metadata[1:0];
    wire [1:0] selected_voice = (requested_voice == 2'b11) ? 2'b00 : requested_voice;

    wire load_v0 = load_new_note && (selected_voice == 2'b00);
    wire load_v1 = load_new_note && (selected_voice == 2'b01);
    wire load_v2 = load_new_note && (selected_voice == 2'b10);

    reg [5:0] dur_0, dur_1, dur_2;
    always @(posedge clk) begin
        if (reset) begin
            dur_0 <= 6'd0;
            dur_1 <= 6'd0;
            dur_2 <= 6'd0;
        end else begin
            if (load_v0) dur_0 <= duration_to_load;
            else if (beat && play_enable && (dur_0 > 0)) dur_0 <= dur_0 - 1'b1;

            if (load_v1) dur_1 <= duration_to_load;
            else if (beat && play_enable && (dur_1 > 0)) dur_1 <= dur_1 - 1'b1;

            if (load_v2) dur_2 <= duration_to_load;
            else if (beat && play_enable && (dur_2 > 0)) dur_2 <= dur_2 - 1'b1;
        end
    end

    wire [5:0] freq_in_0, freq_in_1, freq_in_2;
    wire [19:0] step_size_0, step_size_1, step_size_2;
    wire [19:0] step_size2_0 = step_size_0 << 1;
    wire [19:0] step_size2_1 = step_size_1 << 1;
    wire [19:0] step_size2_2 = step_size_2 << 1;
    wire [19:0] step_size3_0 = step_size_0 + step_size2_0;
    wire [19:0] step_size3_1 = step_size_1 + step_size2_1;
    wire [19:0] step_size3_2 = step_size_2 + step_size2_2;

    wire signed [15:0] sample_0, sample_1, sample_2;
    wire signed [15:0] sample2_0, sample2_1, sample2_2;
    wire signed [15:0] sample3_0, sample3_1, sample3_2;

    dffre #(.WIDTH(6)) freq_reg_0 (
        .clk(clk), .r(reset), .en(load_v0), .d(note_to_load), .q(freq_in_0)
    );
    dffre #(.WIDTH(6)) freq_reg_1 (
        .clk(clk), .r(reset), .en(load_v1), .d(note_to_load), .q(freq_in_1)
    );
    dffre #(.WIDTH(6)) freq_reg_2 (
        .clk(clk), .r(reset), .en(load_v2), .d(note_to_load), .q(freq_in_2)
    );

    frequency_rom freq_rom_0 (.clk(clk), .addr(freq_in_0), .dout(step_size_0));
    frequency_rom freq_rom_1 (.clk(clk), .addr(freq_in_1), .dout(step_size_1));
    frequency_rom freq_rom_2 (.clk(clk), .addr(freq_in_2), .dout(step_size_2));

    wire voice_generate_next = play_enable && generate_next_sample;
    wire ready_0_unused, ready_1_unused, ready_2_unused;
    wire ready2_0_unused, ready2_1_unused, ready2_2_unused;
    wire ready3_0_unused, ready3_1_unused, ready3_2_unused;

    sine_reader sine_read_0 (
        .clk(clk),
        .reset(reset),
        .step_size(step_size_0),
        .generate_next(voice_generate_next),
        .sample_ready(ready_0_unused),
        .sample(sample_0)
    );
    sine_reader sine_read_1 (
        .clk(clk),
        .reset(reset),
        .step_size(step_size_1),
        .generate_next(voice_generate_next),
        .sample_ready(ready_1_unused),
        .sample(sample_1)
    );
    sine_reader sine_read_2 (
        .clk(clk),
        .reset(reset),
        .step_size(step_size_2),
        .generate_next(voice_generate_next),
        .sample_ready(ready_2_unused),
        .sample(sample_2)
    );
    sine_reader sine_read2_0 (
        .clk(clk),
        .reset(reset),
        .step_size(step_size2_0),
        .generate_next(voice_generate_next),
        .sample_ready(ready2_0_unused),
        .sample(sample2_0)
    );
    sine_reader sine_read2_1 (
        .clk(clk),
        .reset(reset),
        .step_size(step_size2_1),
        .generate_next(voice_generate_next),
        .sample_ready(ready2_1_unused),
        .sample(sample2_1)
    );
    sine_reader sine_read2_2 (
        .clk(clk),
        .reset(reset),
        .step_size(step_size2_2),
        .generate_next(voice_generate_next),
        .sample_ready(ready2_2_unused),
        .sample(sample2_2)
    );
    sine_reader sine_read3_0 (
        .clk(clk),
        .reset(reset),
        .step_size(step_size3_0),
        .generate_next(voice_generate_next),
        .sample_ready(ready3_0_unused),
        .sample(sample3_0)
    );
    sine_reader sine_read3_1 (
        .clk(clk),
        .reset(reset),
        .step_size(step_size3_1),
        .generate_next(voice_generate_next),
        .sample_ready(ready3_1_unused),
        .sample(sample3_1)
    );
    sine_reader sine_read3_2 (
        .clk(clk),
        .reset(reset),
        .step_size(step_size3_2),
        .generate_next(voice_generate_next),
        .sample_ready(ready3_2_unused),
        .sample(sample3_2)
    );

    wire signed [15:0] active_sample_0 = (dur_0 > 0) ? sample_0 : 16'sd0;
    wire signed [15:0] active_sample_1 = (dur_1 > 0) ? sample_1 : 16'sd0;
    wire signed [15:0] active_sample_2 = (dur_2 > 0) ? sample_2 : 16'sd0;
    // Simple anti-alias guard for upper notes:
    // disable higher harmonics when fundamentals are already high.
    wire use_h2_0 = (freq_in_0 <= 6'd43);
    wire use_h2_1 = (freq_in_1 <= 6'd43);
    wire use_h2_2 = (freq_in_2 <= 6'd43);
    wire use_h3_0 = (freq_in_0 <= 6'd31);
    wire use_h3_1 = (freq_in_1 <= 6'd31);
    wire use_h3_2 = (freq_in_2 <= 6'd31);

    wire signed [15:0] active_sample2_0 = (dur_0 > 0 && use_h2_0) ? sample2_0 : 16'sd0;
    wire signed [15:0] active_sample2_1 = (dur_1 > 0 && use_h2_1) ? sample2_1 : 16'sd0;
    wire signed [15:0] active_sample2_2 = (dur_2 > 0 && use_h2_2) ? sample2_2 : 16'sd0;
    wire signed [15:0] active_sample3_0 = (dur_0 > 0 && use_h3_0) ? sample3_0 : 16'sd0;
    wire signed [15:0] active_sample3_1 = (dur_1 > 0 && use_h3_1) ? sample3_1 : 16'sd0;
    wire signed [15:0] active_sample3_2 = (dur_2 > 0 && use_h3_2) ? sample3_2 : 16'sd0;

    // Instrument-style harmonic blend:
    // fundamental + 1/4*(2nd harmonic) + 1/8*(3rd harmonic)
    wire signed [17:0] voice_mix_0 = $signed(active_sample_0)
                                   + ($signed(active_sample2_0) >>> 2)
                                   + ($signed(active_sample3_0) >>> 3);
    wire signed [17:0] voice_mix_1 = $signed(active_sample_1)
                                   + ($signed(active_sample2_1) >>> 2)
                                   + ($signed(active_sample3_1) >>> 3);
    wire signed [17:0] voice_mix_2 = $signed(active_sample_2)
                                   + ($signed(active_sample2_2) >>> 2)
                                   + ($signed(active_sample3_2) >>> 3);

    wire signed [19:0] mixed_sum = $signed(voice_mix_0)
                                 + $signed(voice_mix_1)
                                 + $signed(voice_mix_2);
    assign sample_out = mixed_sum >>> 3;

    wire sample_valid_d1;
    dff sample_ready_ff1 (.clk(clk), .d(voice_generate_next), .q(sample_valid_d1));
    dff sample_ready_ff2 (.clk(clk), .d(sample_valid_d1), .q(new_sample_ready));

    // Song timing is now command-driven (WAIT commands in song_reader).
    assign done_with_note = 1'b1;

endmodule