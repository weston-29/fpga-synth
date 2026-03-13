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
    output new_sample_ready,  // Tells the codec when we've got a sample

    output wire [5:0] current_note_0,
    output wire [5:0] current_note_1,
    output wire [5:0] current_note_2,
    output wire       current_valid_0,
    output wire       current_valid_1,
    output wire       current_valid_2,
    output wire       load_note_0,
    output wire       load_note_1,
    output wire       load_note_2,

    // Display-facing outputs
    output wire [15:0] voice_wave_0,
    output wire [15:0] voice_wave_1,
    output wire [15:0] voice_wave_2,
    output wire [15:0] sum_wave,
    output wire [15:0] total_env_vol // to be passed up to PWM
);

    // -----------------------------------------------------------------------
    // Voice selection
    // -----------------------------------------------------------------------
    wire [1:0] requested_voice = note_metadata[1:0];
    wire [1:0] selected_voice  = (requested_voice == 2'b11) ? 2'b00 : requested_voice;

    wire load_v0 = load_new_note && (selected_voice == 2'b00);
    wire load_v1 = load_new_note && (selected_voice == 2'b01);
    wire load_v2 = load_new_note && (selected_voice == 2'b10);

    // -----------------------------------------------------------------------
    // Duration counters
    // -----------------------------------------------------------------------
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

    // -----------------------------------------------------------------------
    // Frequency registers and step sizes
    // -----------------------------------------------------------------------
    wire [5:0]  freq_in_0, freq_in_1, freq_in_2;
    wire [19:0] step_size_0,  step_size_1,  step_size_2;
    wire [19:0] step_size2_0 = step_size_0 << 1;
    wire [19:0] step_size2_1 = step_size_1 << 1;
    wire [19:0] step_size2_2 = step_size_2 << 1;
    wire [19:0] step_size3_0 = step_size_0 + step_size2_0;
    wire [19:0] step_size3_1 = step_size_1 + step_size2_1;
    wire [19:0] step_size3_2 = step_size_2 + step_size2_2;

    dffre #(.WIDTH(6)) freq_reg_0 (.clk(clk), .r(reset), .en(load_v0), .d(note_to_load), .q(freq_in_0));
    dffre #(.WIDTH(6)) freq_reg_1 (.clk(clk), .r(reset), .en(load_v1), .d(note_to_load), .q(freq_in_1));
    dffre #(.WIDTH(6)) freq_reg_2 (.clk(clk), .r(reset), .en(load_v2), .d(note_to_load), .q(freq_in_2));

    frequency_rom freq_rom_0 (.clk(clk), .addr(freq_in_0), .dout(step_size_0));
    frequency_rom freq_rom_1 (.clk(clk), .addr(freq_in_1), .dout(step_size_1));
    frequency_rom freq_rom_2 (.clk(clk), .addr(freq_in_2), .dout(step_size_2));

    // -----------------------------------------------------------------------
    // Sine readers - fundamental + 2nd and 3rd harmonics per voice
    // -----------------------------------------------------------------------
    wire voice_generate_next = play_enable && generate_next_sample;

    wire signed [15:0] sample_0,  sample_1,  sample_2;
    wire signed [15:0] sample2_0, sample2_1, sample2_2;
    wire signed [15:0] sample3_0, sample3_1, sample3_2;

    wire ready_0_unused,  ready_1_unused,  ready_2_unused;
    wire ready2_0_unused, ready2_1_unused, ready2_2_unused;
    wire ready3_0_unused, ready3_1_unused, ready3_2_unused;

    sine_reader sine_read_0  (.clk(clk), .reset(reset), .step_size(step_size_0),  .generate_next(voice_generate_next), .sample_ready(ready_0_unused),  .sample(sample_0));
    sine_reader sine_read_1  (.clk(clk), .reset(reset), .step_size(step_size_1),  .generate_next(voice_generate_next), .sample_ready(ready_1_unused),  .sample(sample_1));
    sine_reader sine_read_2  (.clk(clk), .reset(reset), .step_size(step_size_2),  .generate_next(voice_generate_next), .sample_ready(ready_2_unused),  .sample(sample_2));
    sine_reader sine_read2_0 (.clk(clk), .reset(reset), .step_size(step_size2_0), .generate_next(voice_generate_next), .sample_ready(ready2_0_unused), .sample(sample2_0));
    sine_reader sine_read2_1 (.clk(clk), .reset(reset), .step_size(step_size2_1), .generate_next(voice_generate_next), .sample_ready(ready2_1_unused), .sample(sample2_1));
    sine_reader sine_read2_2 (.clk(clk), .reset(reset), .step_size(step_size2_2), .generate_next(voice_generate_next), .sample_ready(ready2_2_unused), .sample(sample2_2));
    sine_reader sine_read3_0 (.clk(clk), .reset(reset), .step_size(step_size3_0), .generate_next(voice_generate_next), .sample_ready(ready3_0_unused), .sample(sample3_0));
    sine_reader sine_read3_1 (.clk(clk), .reset(reset), .step_size(step_size3_1), .generate_next(voice_generate_next), .sample_ready(ready3_1_unused), .sample(sample3_1));
    sine_reader sine_read3_2 (.clk(clk), .reset(reset), .step_size(step_size3_2), .generate_next(voice_generate_next), .sample_ready(ready3_2_unused), .sample(sample3_2));

    // -----------------------------------------------------------------------
    // Anti-alias harmonic enable (frequency-based only; envelope silences idle voices)
    // -----------------------------------------------------------------------
    wire use_h2_0 = (freq_in_0 <= 6'd43);
    wire use_h2_1 = (freq_in_1 <= 6'd43);
    wire use_h2_2 = (freq_in_2 <= 6'd43);
    wire use_h3_0 = (freq_in_0 <= 6'd31);
    wire use_h3_1 = (freq_in_1 <= 6'd31);
    wire use_h3_2 = (freq_in_2 <= 6'd31);

    wire signed [15:0] active_sample2_0 = use_h2_0 ? sample2_0 : 16'sd0;
    wire signed [15:0] active_sample2_1 = use_h2_1 ? sample2_1 : 16'sd0;
    wire signed [15:0] active_sample2_2 = use_h2_2 ? sample2_2 : 16'sd0;
    wire signed [15:0] active_sample3_0 = use_h3_0 ? sample3_0 : 16'sd0;
    wire signed [15:0] active_sample3_1 = use_h3_1 ? sample3_1 : 16'sd0;
    wire signed [15:0] active_sample3_2 = use_h3_2 ? sample3_2 : 16'sd0;

    // -----------------------------------------------------------------------
    // Per-voice harmonic mix
    // -----------------------------------------------------------------------
    wire signed [17:0] voice_mix_0 = $signed(sample_0) + ($signed(active_sample2_0) >>> 2) + ($signed(active_sample3_0) >>> 3);
    wire signed [17:0] voice_mix_1 = $signed(sample_1) + ($signed(active_sample2_1) >>> 2) + ($signed(active_sample3_1) >>> 3);
    wire signed [17:0] voice_mix_2 = $signed(sample_2) + ($signed(active_sample2_2) >>> 2) + ($signed(active_sample3_2) >>> 3);

    // -----------------------------------------------------------------------
    // ADSR envelope
    // -----------------------------------------------------------------------
    localparam [2:0] ENV_IDLE    = 3'd0;
    localparam [2:0] ENV_ATTACK  = 3'd1;
    localparam [2:0] ENV_DECAY   = 3'd2;
    localparam [2:0] ENV_SUSTAIN = 3'd3;
    localparam [2:0] ENV_RELEASE = 3'd4;

    localparam [15:0] SUSTAIN_LEVEL = 16'd9830;  // Q1.15 ~0.30

    // 4-step exponential from 32767 to SUSTAIN_LEVEL (9830), ratio ~0.740 per step
    function [15:0] decay_lut;
        input [3:0] idx;
        begin
            case (idx)
                4'd1:    decay_lut = 16'd24248;
                4'd2:    decay_lut = 16'd17943;
                4'd3:    decay_lut = 16'd13278;
                default: decay_lut = SUSTAIN_LEVEL;
            endcase
        end
    endfunction

    wire env_tick = beat && play_enable;

    // note_off fires one beat before dur hits zero, triggering release
    wire note_off_0 = beat && play_enable && (dur_0 == 6'd1);
    wire note_off_1 = beat && play_enable && (dur_1 == 6'd1);
    wire note_off_2 = beat && play_enable && (dur_2 == 6'd1);

    reg [2:0]  env_state_0, env_state_1, env_state_2;
    reg [3:0]  env_ctr_0,   env_ctr_1,   env_ctr_2;
    reg [15:0] env_gain_0,  env_gain_1,  env_gain_2;
    reg [15:0] rel_step_0,  rel_step_1,  rel_step_2;

    always @(posedge clk) begin
        if (reset) begin
            env_state_0 <= ENV_IDLE; env_ctr_0 <= 4'd0; env_gain_0 <= 16'd0; rel_step_0 <= 16'd1;
            env_state_1 <= ENV_IDLE; env_ctr_1 <= 4'd0; env_gain_1 <= 16'd0; rel_step_1 <= 16'd1;
            env_state_2 <= ENV_IDLE; env_ctr_2 <= 4'd0; env_gain_2 <= 16'd0; rel_step_2 <= 16'd1;
        end else begin

            // --- Voice 0 ---
            if (load_v0) begin
                env_state_0 <= ENV_ATTACK; env_ctr_0 <= 4'd0; env_gain_0 <= 16'd0;
            end else if (env_tick) begin
                case (env_state_0)
                    ENV_IDLE: begin
                        env_gain_0 <= 16'd0;
                    end
                    ENV_ATTACK: begin
                        if (note_off_0) begin
                            env_state_0 <= ENV_RELEASE;
                            rel_step_0  <= (env_gain_0 >> 5) + 16'd1;
                        end else if (env_ctr_0 == 4'd3) begin
                            env_state_0 <= ENV_DECAY; env_ctr_0 <= 4'd0; env_gain_0 <= 16'd32767;
                        end else begin
                            env_ctr_0 <= env_ctr_0 + 1'b1;
                            env_gain_0 <= {1'b0, (env_ctr_0[1:0] + 2'b01), 13'b0};
                        end
                    end
                    ENV_DECAY: begin
                        if (note_off_0) begin
                            env_state_0 <= ENV_RELEASE;
                            rel_step_0  <= (env_gain_0 >> 5) + 16'd1;
                        end else if (env_ctr_0 == 4'd3) begin
                            env_state_0 <= ENV_SUSTAIN; env_gain_0 <= SUSTAIN_LEVEL;
                        end else begin
                            env_ctr_0 <= env_ctr_0 + 1'b1;
                            env_gain_0 <= decay_lut(env_ctr_0 + 1'b1);
                        end
                    end
                    ENV_SUSTAIN: begin
                        env_gain_0 <= SUSTAIN_LEVEL;
                        if (dur_0 == 6'd0) begin
                            env_state_0 <= ENV_RELEASE;
                            rel_step_0  <= (env_gain_0 >> 5) + 16'd1;
                        end
                    end
                    ENV_RELEASE: begin
                        if (env_gain_0 <= rel_step_0) begin
                            env_gain_0 <= 16'd0; env_state_0 <= ENV_IDLE;
                        end else begin
                            env_gain_0 <= env_gain_0 - rel_step_0;
                        end
                    end
                    default: begin env_state_0 <= ENV_IDLE; env_gain_0 <= 16'd0; end
                endcase
            end

            // --- Voice 1 ---
            if (load_v1) begin
                env_state_1 <= ENV_ATTACK; env_ctr_1 <= 4'd0; env_gain_1 <= 16'd0;
            end else if (env_tick) begin
                case (env_state_1)
                    ENV_IDLE: begin
                        env_gain_1 <= 16'd0;
                    end
                    ENV_ATTACK: begin
                        if (note_off_1) begin
                            env_state_1 <= ENV_RELEASE;
                            rel_step_1  <= (env_gain_1 >> 5) + 16'd1;
                        end else if (env_ctr_1 == 4'd3) begin
                            env_state_1 <= ENV_DECAY; env_ctr_1 <= 4'd0; env_gain_1 <= 16'd32767;
                        end else begin
                            env_ctr_1 <= env_ctr_1 + 1'b1;
                            env_gain_1 <= {1'b0, (env_ctr_1[1:0] + 2'b01), 13'b0};
                        end
                    end
                    ENV_DECAY: begin
                        if (note_off_1) begin
                            env_state_1 <= ENV_RELEASE;
                            rel_step_1  <= (env_gain_1 >> 5) + 16'd1;
                        end else if (env_ctr_1 == 4'd3) begin
                            env_state_1 <= ENV_SUSTAIN; env_gain_1 <= SUSTAIN_LEVEL;
                        end else begin
                            env_ctr_1 <= env_ctr_1 + 1'b1;
                            env_gain_1 <= decay_lut(env_ctr_1 + 1'b1);
                        end
                    end
                    ENV_SUSTAIN: begin
                        env_gain_1 <= SUSTAIN_LEVEL;
                        if (dur_1 == 6'd0) begin
                            env_state_1 <= ENV_RELEASE;
                            rel_step_1  <= (env_gain_1 >> 5) + 16'd1;
                        end
                    end
                    ENV_RELEASE: begin
                        if (env_gain_1 <= rel_step_1) begin
                            env_gain_1 <= 16'd0; env_state_1 <= ENV_IDLE;
                        end else begin
                            env_gain_1 <= env_gain_1 - rel_step_1;
                        end
                    end
                    default: begin env_state_1 <= ENV_IDLE; env_gain_1 <= 16'd0; end
                endcase
            end

            // --- Voice 2 ---
            if (load_v2) begin
                env_state_2 <= ENV_ATTACK; env_ctr_2 <= 4'd0; env_gain_2 <= 16'd0;
            end else if (env_tick) begin
                case (env_state_2)
                    ENV_IDLE: begin
                        env_gain_2 <= 16'd0;
                    end
                    ENV_ATTACK: begin
                        if (note_off_2) begin
                            env_state_2 <= ENV_RELEASE;
                            rel_step_2  <= (env_gain_2 >> 5) + 16'd1;
                        end else if (env_ctr_2 == 4'd3) begin
                            env_state_2 <= ENV_DECAY; env_ctr_2 <= 4'd0; env_gain_2 <= 16'd32767;
                        end else begin
                            env_ctr_2 <= env_ctr_2 + 1'b1;
                            env_gain_2 <= {1'b0, (env_ctr_2[1:0] + 2'b01), 13'b0};
                        end
                    end
                    ENV_DECAY: begin
                        if (note_off_2) begin
                            env_state_2 <= ENV_RELEASE;
                            rel_step_2  <= (env_gain_2 >> 5) + 16'd1;
                        end else if (env_ctr_2 == 4'd3) begin
                            env_state_2 <= ENV_SUSTAIN; env_gain_2 <= SUSTAIN_LEVEL;
                        end else begin
                            env_ctr_2 <= env_ctr_2 + 1'b1;
                            env_gain_2 <= decay_lut(env_ctr_2 + 1'b1);
                        end
                    end
                    ENV_SUSTAIN: begin
                        env_gain_2 <= SUSTAIN_LEVEL;
                        if (dur_2 == 6'd0) begin
                            env_state_2 <= ENV_RELEASE;
                            rel_step_2  <= (env_gain_2 >> 5) + 16'd1;
                        end
                    end
                    ENV_RELEASE: begin
                        if (env_gain_2 <= rel_step_2) begin
                            env_gain_2 <= 16'd0; env_state_2 <= ENV_IDLE;
                        end else begin
                            env_gain_2 <= env_gain_2 - rel_step_2;
                        end
                    end
                    default: begin env_state_2 <= ENV_IDLE; env_gain_2 <= 16'd0; end
                endcase
            end

        end
    end

    // -----------------------------------------------------------------------
    // Apply envelope gain to each voice (Q1.15 multiply, shift back)
    // -----------------------------------------------------------------------
    wire signed [33:0] env_mul_0 = $signed(voice_mix_0) * $signed({1'b0, env_gain_0});
    wire signed [33:0] env_mul_1 = $signed(voice_mix_1) * $signed({1'b0, env_gain_1});
    wire signed [33:0] env_mul_2 = $signed(voice_mix_2) * $signed({1'b0, env_gain_2});

    wire signed [17:0] env_voice_0 = env_mul_0 >>> 15;
    wire signed [17:0] env_voice_1 = env_mul_1 >>> 15;
    wire signed [17:0] env_voice_2 = env_mul_2 >>> 15;

    // -----------------------------------------------------------------------
    // Final mix and output
    // -----------------------------------------------------------------------
    wire signed [19:0] mixed_sum = $signed(env_voice_0) + $signed(env_voice_1) + $signed(env_voice_2);

    assign sample_out = mixed_sum >>> 3;

    // Display taps - show enveloped per-voice signals, scaled to match final output domain
    assign voice_wave_0 = $signed(env_voice_0 >>> 3);
    assign voice_wave_1 = $signed(env_voice_1 >>> 3);
    assign voice_wave_2 = $signed(env_voice_2 >>> 3);
    assign sum_wave     = sample_out;

    // -----------------------------------------------------------------------
    // Sample-ready pipeline (plain dff, matching V2)
    // -----------------------------------------------------------------------
    wire sample_valid_d1;
    dff sample_ready_ff1 (.clk(clk), .d(voice_generate_next), .q(sample_valid_d1));
    dff sample_ready_ff2 (.clk(clk), .d(sample_valid_d1),     .q(new_sample_ready));

    assign done_with_note = 1'b1;

    // Envelope PWM signal for passing up to top
    // Sum the gains of all 3 voices
    // Each is 16-bit, so the sum is 18-bit to prevent overflow.
    wire [17:0] combined_gain = {2'b0, env_gain_0} + {2'b0, env_gain_1} + {2'b0, env_gain_2};

    // Scale back to 16-bit for the PWM logic. 
    // If all 3 are at max (32767), the sum is 98301. Shifting >> 2 gives ~24575.
    assign total_env_vol = combined_gain[17:2];

    // -----------------------------------------------------------------------
    // Display-facing note context outputs
    // -----------------------------------------------------------------------
    assign current_note_0  = freq_in_0;
    assign current_note_1  = freq_in_1;
    assign current_note_2  = freq_in_2;

    assign current_valid_0 = (dur_0 != 6'd0);
    assign current_valid_1 = (dur_1 != 6'd0);
    assign current_valid_2 = (dur_2 != 6'd0);

    assign load_note_0 = load_v0;
    assign load_note_1 = load_v1;
    assign load_note_2 = load_v2;

endmodule