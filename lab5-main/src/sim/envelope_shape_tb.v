`timescale 1ns/1ps

module envelope_shape_tb;
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

    // Runtime-configurable sim controls
    integer SAMPLE_PERIOD_CLKS;   // clocks between generated samples
    integer TOTAL_SAMPLES;        // captured sample count target
    integer BEAT_EVERY_SAMPLES;   // beat pulse cadence in sample domain
    integer PROGRESS_EVERY;       // terminal progress print cadence
    integer CSV_DECIM;            // write every Nth valid sample
    integer vcd_en;

    integer vis_fd;
    integer vis_samples;
    integer gen_samples;
    integer k;

    task vis_sample_tick;
        begin
            generate_next_sample = 1'b1;
            @(posedge clk);
            generate_next_sample = 1'b0;

            // align with DUT sample_ready pipeline
            @(posedge clk);
            @(posedge clk);

            if (new_sample_ready && (^sample_out !== 1'bx)) begin
                gen_samples = gen_samples + 1;

                if ((gen_samples % CSV_DECIM) == 0) begin
                    vis_samples = vis_samples + 1;
                    $fwrite(vis_fd, "%0t,%0d\n", $time, $signed(sample_out));
                end

                if ((gen_samples % PROGRESS_EVERY) == 0)
                    $display("[%0t] generated=%0d logged=%0d", $time, gen_samples, vis_samples);
            end

            for (k = 0; k < (SAMPLE_PERIOD_CLKS-3); k = k + 1)
                @(posedge clk);
        end
    endtask

    always #5 clk = ~clk;

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

    initial begin : visual_envelope_section
        if (!$test$plusargs("VIS_ENVELOPE")) disable visual_envelope_section;

        // Fast defaults: "1 second of samples" in fast sim time
        SAMPLE_PERIOD_CLKS = 8;
        TOTAL_SAMPLES      = 48000; // 1 sec @ 48kHz equivalent
        BEAT_EVERY_SAMPLES = 1000;
        PROGRESS_EVERY     = 2000;
        CSV_DECIM          = 1;
        vcd_en             = 1;

        // Optional modes/overrides
        if ($test$plusargs("VIS_REALTIME")) SAMPLE_PERIOD_CLKS = 2083;
        if ($test$plusargs("NO_VCD"))       vcd_en = 0;
        if ($value$plusargs("VIS_PERIOD=%d", SAMPLE_PERIOD_CLKS)) ;
        if ($value$plusargs("VIS_SAMPLES=%d", TOTAL_SAMPLES)) ;
        if ($value$plusargs("VIS_BEAT=%d", BEAT_EVERY_SAMPLES)) ;
        if ($value$plusargs("VIS_DECIM=%d", CSV_DECIM)) ;
        if ($value$plusargs("VIS_PROGRESS=%d", PROGRESS_EVERY)) ;

        $display("VIS cfg: period=%0d total=%0d beat=%0d decim=%0d vcd=%0d",
                 SAMPLE_PERIOD_CLKS, TOTAL_SAMPLES, BEAT_EVERY_SAMPLES, CSV_DECIM, vcd_en);

        if (vcd_en) begin
            $dumpfile("note_player_env.vcd");

            // Keep top-level controls
            $dumpvars(0, note_player_tb.clk);
            $dumpvars(0, note_player_tb.reset);
            $dumpvars(0, note_player_tb.play_enable);
            $dumpvars(0, note_player_tb.load_new_note);
            $dumpvars(0, note_player_tb.generate_next_sample);
            $dumpvars(0, note_player_tb.beat);
            $dumpvars(0, note_player_tb.new_sample_ready);
            $dumpvars(0, note_player_tb.sample_out);

            // Explicit DUT internals (useful in GTKWave)
            $dumpvars(0, note_player_tb.dut.voice_generate_next);
            $dumpvars(0, note_player_tb.dut.sample_valid_d1);
            $dumpvars(0, note_player_tb.dut.sample_valid_d2);

            // Envelope visibility
            $dumpvars(0, note_player_tb.dut.env_state_0);
            $dumpvars(0, note_player_tb.dut.env_ctr_0);
            $dumpvars(0, note_player_tb.dut.env_gain_0);

            // Audio path visibility
            $dumpvars(0, note_player_tb.dut.voice_mix_0);
            $dumpvars(0, note_player_tb.dut.env_voice_0);
            $dumpvars(0, note_player_tb.dut.mixed_sum);
            $dumpvars(0, note_player_tb.dut.sample_sat);

            // Raw sine before envelope (compare directly with sample_out)
            $dumpvars(0, note_player_tb.dut.sample_0);      // fundamental sine voice 0
            $dumpvars(0, note_player_tb.dut.active_sample_0); // after harmonic gate, before env
            $dumpvars(0, note_player_tb.dut.voice_mix_0);   // after harmonic blend, before env
            $dumpvars(0, note_player_tb.dut.env_voice_0);   // after envelope multiply
        end

        $display("TIP: In GTKWave, add signals from SST manually (sample_out, env_gain_0, env_state_0).");

        vis_fd = $fopen("note_player_env.csv", "w");
        if (vis_fd == 0) begin
            $display("ERROR: could not open note_player_env.csv");
            $finish;
        end
        $fwrite(vis_fd, "time_ns,sample\n");
        vis_samples = 0;
        gen_samples = 0;

        // Drive reset ourselves
        reset = 1'b1;
        repeat (4) @(posedge clk);
        reset = 1'b0;

        // Load a single sustained note on voice 0
        play_enable      = 1'b1;
        beat             = 1'b0;
        note_to_load     = 6'd24;
        duration_to_load = 6'd12;
        note_metadata    = 3'b000;
        load_new_note    = 1'b1;
        @(posedge clk);
        load_new_note    = 1'b0;

        while (gen_samples < TOTAL_SAMPLES) begin
            vis_sample_tick();

            if ((gen_samples > 0) && ((gen_samples % BEAT_EVERY_SAMPLES) == 0)) begin
                beat = 1'b1;
                @(posedge clk);
                beat = 1'b0;
            end
        end

        $fclose(vis_fd);
        $display("VIS_ENVELOPE complete: generated=%0d logged=%0d", gen_samples, vis_samples);
        $finish;
    end
endmodule
