module note_context_tracker(
    input  wire       clk,
    input  wire       reset,
    input  wire [1:0] song_sel,

    // Current live voice state from note_player
    input  wire [5:0] curr_note_0,
    input  wire [5:0] curr_note_1,
    input  wire [5:0] curr_note_2,
    input  wire       curr_valid_0,
    input  wire       curr_valid_1,
    input  wire       curr_valid_2,

    // Pulses when note_player loads a new note
    input  wire       load_note_0,
    input  wire       load_note_1,
    input  wire       load_note_2,

    // Current song-reader event stream
    input  wire       event_new_note,
    input  wire [5:0] event_note,
    input  wire [2:0] event_metadata,
    input  wire [6:0] event_index,

    // Past row
    output reg  [5:0] past_note_0,
    output reg  [5:0] past_note_1,
    output reg  [5:0] past_note_2,
    output reg        past_valid_0,
    output reg        past_valid_1,
    output reg        past_valid_2,

    // Current row
    output wire [5:0] now_note_0,
    output wire [5:0] now_note_1,
    output wire [5:0] now_note_2,
    output wire       now_valid_0,
    output wire       now_valid_1,
    output wire       now_valid_2,

    // Future row
    output reg  [5:0] next_note_0,
    output reg  [5:0] next_note_1,
    output reg  [5:0] next_note_2,
    output reg        next_valid_0,
    output reg        next_valid_1,
    output reg        next_valid_2
);

    assign now_note_0  = curr_note_0;
    assign now_note_1  = curr_note_1;
    assign now_note_2  = curr_note_2;

    assign now_valid_0 = curr_valid_0;
    assign now_valid_1 = curr_valid_1;
    assign now_valid_2 = curr_valid_2;

    reg [1:0] song_sel_d;
    wire song_changed = (song_sel != song_sel_d);

    always @(posedge clk) begin
        if (reset)
            song_sel_d <= 2'b00;
        else
            song_sel_d <= song_sel;
    end

    wire [1:0] event_voice;
    assign event_voice = (event_metadata[1:0] == 2'b11) ? 2'b00 : event_metadata[1:0];

    // ------------------------------------------------------------
    // PAST row
    // Capture the voice state that was live immediately before the
    // new note is applied by the note_player.
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (reset || song_changed) begin
            past_note_0  <= 6'd0;
            past_note_1  <= 6'd0;
            past_note_2  <= 6'd0;
            past_valid_0 <= 1'b0;
            past_valid_1 <= 1'b0;
            past_valid_2 <= 1'b0;
        end else begin
            if (load_note_0) begin
                past_note_0  <= curr_note_0;
                past_valid_0 <= curr_valid_0;
            end

            if (load_note_1) begin
                past_note_1  <= curr_note_1;
                past_valid_1 <= curr_valid_1;
            end

            if (load_note_2) begin
                past_note_2  <= curr_note_2;
                past_valid_2 <= curr_valid_2;
            end
        end
    end

    localparam SEARCH_IDLE  = 2'd0;
    localparam SEARCH_PRIME = 2'd1;
    localparam SEARCH_EVAL  = 2'd2;

    reg [1:0] search_state_0, search_state_1, search_state_2;
    reg [8:0] search_addr_0,  search_addr_1,  search_addr_2;

    reg       skip_current_0, skip_current_1, skip_current_2;
    reg [8:0] base_addr_0,    base_addr_1,    base_addr_2;

    wire [15:0] rom_word_0;
    wire [15:0] rom_word_1;
    wire [15:0] rom_word_2;

    song_rom next_rom_0 (
        .clk(clk),
        .addr(search_addr_0),
        .dout(rom_word_0)
    );

    song_rom next_rom_1 (
        .clk(clk),
        .addr(search_addr_1),
        .dout(rom_word_1)
    );

    song_rom next_rom_2 (
        .clk(clk),
        .addr(search_addr_2),
        .dout(rom_word_2)
    );

    wire rom0_is_note = ~rom_word_0[15];
    wire rom1_is_note = ~rom_word_1[15];
    wire rom2_is_note = ~rom_word_2[15];

    wire [5:0] rom0_note = rom_word_0[14:9];
    wire [5:0] rom1_note = rom_word_1[14:9];
    wire [5:0] rom2_note = rom_word_2[14:9];

    wire [1:0] rom0_voice = (rom_word_0[1:0] == 2'b11) ? 2'b00 : rom_word_0[1:0];
    wire [1:0] rom1_voice = (rom_word_1[1:0] == 2'b11) ? 2'b00 : rom_word_1[1:0];
    wire [1:0] rom2_voice = (rom_word_2[1:0] == 2'b11) ? 2'b00 : rom_word_2[1:0];

    wire rom0_last = (search_addr_0[6:0] == 7'd127);
    wire rom1_last = (search_addr_1[6:0] == 7'd127);
    wire rom2_last = (search_addr_2[6:0] == 7'd127);

    wire rom0_matches_trigger = rom0_is_note && (search_addr_0 == base_addr_0);
    wire rom1_matches_trigger = rom1_is_note && (search_addr_1 == base_addr_1);
    wire rom2_matches_trigger = rom2_is_note && (search_addr_2 == base_addr_2);

    always @(posedge clk) begin
        if (reset || song_changed) begin
            search_state_0 <= SEARCH_PRIME;
            search_state_1 <= SEARCH_PRIME;
            search_state_2 <= SEARCH_PRIME;

            search_addr_0  <= {song_sel, 7'd0};
            search_addr_1  <= {song_sel, 7'd0};
            search_addr_2  <= {song_sel, 7'd0};

            skip_current_0 <= 1'b0;
            skip_current_1 <= 1'b0;
            skip_current_2 <= 1'b0;

            base_addr_0    <= {song_sel, 7'd0};
            base_addr_1    <= {song_sel, 7'd0};
            base_addr_2    <= {song_sel, 7'd0};

            next_note_0    <= 6'd0;
            next_note_1    <= 6'd0;
            next_note_2    <= 6'd0;

            next_valid_0   <= 1'b0;
            next_valid_1   <= 1'b0;
            next_valid_2   <= 1'b0;
        end else begin
            // -------------------------
            // Voice 0 search / restart
            // -------------------------
            if (event_new_note && (event_voice == 2'b00)) begin
                next_note_0    <= 6'd0;
                next_valid_0   <= 1'b0;
                search_addr_0  <= {song_sel, event_index};
                search_state_0 <= SEARCH_PRIME;
                skip_current_0 <= 1'b1;
                base_addr_0    <= {song_sel, event_index};
            end else begin
                case (search_state_0)
                    SEARCH_IDLE: begin
                        search_state_0 <= SEARCH_IDLE;
                    end

                    SEARCH_PRIME: begin
                        search_state_0 <= SEARCH_EVAL;
                    end

                    SEARCH_EVAL: begin
                        if (skip_current_0 && rom0_matches_trigger) begin
                            skip_current_0 <= 1'b0;
                            if (rom0_last) begin
                                next_note_0    <= 6'd0;
                                next_valid_0   <= 1'b0;
                                search_state_0 <= SEARCH_IDLE;
                            end else begin
                                search_addr_0  <= search_addr_0 + 9'd1;
                                search_state_0 <= SEARCH_PRIME;
                            end
                        end else if (rom0_is_note && (rom0_voice == 2'b00)) begin
                            next_note_0    <= rom0_note;
                            next_valid_0   <= (rom0_note != 6'd0);
                            search_state_0 <= SEARCH_IDLE;
                        end else if (rom0_last) begin
                            next_note_0    <= 6'd0;
                            next_valid_0   <= 1'b0;
                            search_state_0 <= SEARCH_IDLE;
                        end else begin
                            search_addr_0  <= search_addr_0 + 9'd1;
                            search_state_0 <= SEARCH_PRIME;
                        end
                    end

                    default: begin
                        search_state_0 <= SEARCH_IDLE;
                    end
                endcase
            end

            // -------------------------
            // Voice 1 search / restart
            // -------------------------
            if (event_new_note && (event_voice == 2'b01)) begin
                next_note_1    <= 6'd0;
                next_valid_1   <= 1'b0;
                search_addr_1  <= {song_sel, event_index};
                search_state_1 <= SEARCH_PRIME;
                skip_current_1 <= 1'b1;
                base_addr_1    <= {song_sel, event_index};
            end else begin
                case (search_state_1)
                    SEARCH_IDLE: begin
                        search_state_1 <= SEARCH_IDLE;
                    end

                    SEARCH_PRIME: begin
                        search_state_1 <= SEARCH_EVAL;
                    end

                    SEARCH_EVAL: begin
                        if (skip_current_1 && rom1_matches_trigger) begin
                            skip_current_1 <= 1'b0;
                            if (rom1_last) begin
                                next_note_1    <= 6'd0;
                                next_valid_1   <= 1'b0;
                                search_state_1 <= SEARCH_IDLE;
                            end else begin
                                search_addr_1  <= search_addr_1 + 9'd1;
                                search_state_1 <= SEARCH_PRIME;
                            end
                        end else if (rom1_is_note && (rom1_voice == 2'b01)) begin
                            next_note_1    <= rom1_note;
                            next_valid_1   <= (rom1_note != 6'd0);
                            search_state_1 <= SEARCH_IDLE;
                        end else if (rom1_last) begin
                            next_note_1    <= 6'd0;
                            next_valid_1   <= 1'b0;
                            search_state_1 <= SEARCH_IDLE;
                        end else begin
                            search_addr_1  <= search_addr_1 + 9'd1;
                            search_state_1 <= SEARCH_PRIME;
                        end
                    end

                    default: begin
                        search_state_1 <= SEARCH_IDLE;
                    end
                endcase
            end

            // -------------------------
            // Voice 2 search / restart
            // -------------------------
            if (event_new_note && (event_voice == 2'b10)) begin
                next_note_2    <= 6'd0;
                next_valid_2   <= 1'b0;
                search_addr_2  <= {song_sel, event_index};
                search_state_2 <= SEARCH_PRIME;
                skip_current_2 <= 1'b1;
                base_addr_2    <= {song_sel, event_index};
            end else begin
                case (search_state_2)
                    SEARCH_IDLE: begin
                        search_state_2 <= SEARCH_IDLE;
                    end

                    SEARCH_PRIME: begin
                        search_state_2 <= SEARCH_EVAL;
                    end

                    SEARCH_EVAL: begin
                        if (skip_current_2 && rom2_matches_trigger) begin
                            skip_current_2 <= 1'b0;
                            if (rom2_last) begin
                                next_note_2    <= 6'd0;
                                next_valid_2   <= 1'b0;
                                search_state_2 <= SEARCH_IDLE;
                            end else begin
                                search_addr_2  <= search_addr_2 + 9'd1;
                                search_state_2 <= SEARCH_PRIME;
                            end
                        end else if (rom2_is_note && (rom2_voice == 2'b10)) begin
                            next_note_2    <= rom2_note;
                            next_valid_2   <= (rom2_note != 6'd0);
                            search_state_2 <= SEARCH_IDLE;
                        end else if (rom2_last) begin
                            next_note_2    <= 6'd0;
                            next_valid_2   <= 1'b0;
                            search_state_2 <= SEARCH_IDLE;
                        end else begin
                            search_addr_2  <= search_addr_2 + 9'd1;
                            search_state_2 <= SEARCH_PRIME;
                        end
                    end

                    default: begin
                        search_state_2 <= SEARCH_IDLE;
                    end
                endcase
            end
        end
    end

endmodule
