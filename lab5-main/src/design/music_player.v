module music_player(
    input clk,
    input reset,

    input play_button,
    input next_button,

    input new_frame,

    output wire new_sample_generated,
    output wire [15:0] sample_out,

    // New display-facing outputs
    output wire [15:0] voice_wave_0,
    output wire [15:0] voice_wave_1,
    output wire [15:0] voice_wave_2,
    output wire [15:0] sum_wave,
    output wire [15:0] envelope_vol_out // to pass to top PWM
);
    parameter BEAT_COUNT = 1000;

    wire play;
    wire reset_player;
    wire [1:0] current_song;
    wire song_done;

    mcu mcu(
        .clk(clk),
        .reset(reset),
        .play_button(play_button),
        .next_button(next_button),
        .play(play),
        .reset_player(reset_player),
        .song(current_song),
        .song_done(song_done)
    );

    wire beat;
    wire [5:0] note_to_play;
    wire [5:0] duration_for_note;
    wire [2:0] note_metadata;
    wire new_note;
    wire note_done_unused;

    song_reader song_reader(
        .clk(clk),
        .reset(reset | reset_player),
        .play(play),
        .song(current_song),
        .beat(beat),
        .song_done(song_done),
        .note(note_to_play),
        .duration(duration_for_note),
        .note_metadata(note_metadata),
        .new_note(new_note)
    );

    wire generate_next_sample, generate_next_sample0;
    wire [15:0] note_sample, note_sample0;
    wire note_sample_ready, note_sample_ready0;

    // New display wave pipeline
    wire [15:0] voice_wave_0_0, voice_wave_1_0, voice_wave_2_0, sum_wave_0;

    dffr pipeline_ff_gen_next_sample (
        .clk(clk), .r(reset), .d(generate_next_sample0), .q(generate_next_sample)
    );
    dffr #(.WIDTH(16)) pipeline_ff_note_sample (
        .clk(clk), .r(reset), .d(note_sample0), .q(note_sample)
    );
    dffr pipeline_ff_new_sample_ready (
        .clk(clk), .r(reset), .d(note_sample_ready0), .q(note_sample_ready)
    );

    dffr #(.WIDTH(16)) pipeline_ff_voice0 (
        .clk(clk), .r(reset), .d(voice_wave_0_0), .q(voice_wave_0)
    );
    dffr #(.WIDTH(16)) pipeline_ff_voice1 (
        .clk(clk), .r(reset), .d(voice_wave_1_0), .q(voice_wave_1)
    );
    dffr #(.WIDTH(16)) pipeline_ff_voice2 (
        .clk(clk), .r(reset), .d(voice_wave_2_0), .q(voice_wave_2)
    );
    dffr #(.WIDTH(16)) pipeline_ff_sumwave (
        .clk(clk), .r(reset), .d(sum_wave_0), .q(sum_wave)
    );

    note_player note_player(
        .clk(clk),
        .reset(reset),
        .play_enable(play),
        .note_to_load(note_to_play),
        .duration_to_load(duration_for_note),
        .note_metadata(note_metadata),
        .load_new_note(new_note),
        .done_with_note(note_done_unused),
        .beat(beat),
        .generate_next_sample(generate_next_sample),
        .sample_out(note_sample0),
        .new_sample_ready(note_sample_ready0),
        .voice_wave_0(voice_wave_0_0),
        .voice_wave_1(voice_wave_1_0),
        .voice_wave_2(voice_wave_2_0),
        .sum_wave(sum_wave_0),
        .total_env_vol(envelope_vol_out)
    );

    beat_generator #(.WIDTH(10), .STOP(BEAT_COUNT)) beat_generator(
        .clk(clk),
        .reset(reset),
        .en(generate_next_sample),
        .beat(beat)
    );

    wire new_sample_generated0;
    wire [15:0] sample_out0;

    dffr pipeline_ff_nsg (
        .clk(clk), .r(reset), .d(new_sample_generated0), .q(new_sample_generated)
    );

    assign sample_out = sample_out0;
    assign new_sample_generated0 = generate_next_sample;

    codec_conditioner codec_conditioner(
        .clk(clk),
        .reset(reset),
        .new_sample_in(note_sample),
        .latch_new_sample_in(note_sample_ready),
        .generate_next_sample(generate_next_sample0),
        .new_frame(new_frame),
        .valid_sample(sample_out0)
    );

endmodule
