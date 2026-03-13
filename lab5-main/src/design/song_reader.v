`define SONG_WIDTH 7
`define NOTE_WIDTH 6
`define DURATION_WIDTH 6

// ----------------------------------------------
// Define State Assignments
// ----------------------------------------------
`define SWIDTH 3
`define PAUSED             3'b000
`define LOAD_WAIT          3'b001
`define INCREMENT_ADDRESS  3'b010
`define RETRIEVE_CMD       3'b011
`define NEW_NOTE_READY     3'b100
`define WAIT               3'b101


module song_reader(
    input clk,
    input reset,
    input play,
    input [1:0] song,
    input beat,
    output wire song_done,
    output wire [5:0] note,
    output wire [5:0] duration,
    output wire [2:0] note_metadata,
    output wire new_note,
    output wire [6:0] event_index
);
    wire [`SONG_WIDTH-1:0] curr_note_num, next_note_num;
    wire [15:0] command_word;
    wire [`SONG_WIDTH + 1:0] rom_addr = {song, curr_note_num};

    wire [`SWIDTH-1:0] state;
    reg  [`SWIDTH-1:0] next;

    // For identifying when we reach the end of a song
    wire overflow;
    wire command_is_wait = command_word[15];
    wire [5:0] wait_ticks = command_word[5:0];
    wire [5:0] command_note = command_word[14:9];
    wire [5:0] command_duration = command_word[8:3];
    wire [2:0] command_metadata = command_word[2:0];

    wire [5:0] wait_counter, next_wait_counter;
    wire load_wait_counter = (state == `LOAD_WAIT);
    wire decrement_wait_counter = (state == `WAIT) && beat && (wait_counter > 0);

    dffr #(`SONG_WIDTH) note_counter (
        .clk(clk),
        .r(reset),
        .d(next_note_num),
        .q(curr_note_num)
    );
    dffr #(.WIDTH(6)) wait_counter_reg (
        .clk(clk),
        .r(reset),
        .d(next_wait_counter),
        .q(wait_counter)
    );
    dffr #(`SWIDTH) fsm (
        .clk(clk),
        .r(reset),
        .d(next),
        .q(state)
    );

    song_rom rom(.clk(clk), .addr(rom_addr), .dout(command_word));

    always @(*) begin
        case (state)
            `PAUSED:            next = play ? `RETRIEVE_CMD : `PAUSED;
            `RETRIEVE_CMD:      next = play ? `NEW_NOTE_READY : `PAUSED;
            `NEW_NOTE_READY:    next = !play ? `PAUSED
                                             : (command_is_wait ? `LOAD_WAIT : `INCREMENT_ADDRESS);
            // Treat WAIT 0 as an end-of-song hold marker to avoid racing through
            // padded ROM entries and abruptly changing songs/tempo perception.
            `LOAD_WAIT:         next = !play ? `PAUSED : `WAIT;
            `WAIT:              next = !play ? `PAUSED
                                             : ((beat && (wait_counter == 1)) ? `INCREMENT_ADDRESS : `WAIT);
            `INCREMENT_ADDRESS: next = (play && ~overflow) ? `RETRIEVE_CMD
                                                           : `PAUSED;
            default:            next = `PAUSED;
        endcase
    end

    assign {overflow, next_note_num} =
        (state == `INCREMENT_ADDRESS) ? {1'b0, curr_note_num} + 1
                                      : {1'b0, curr_note_num};
    assign next_wait_counter =
        load_wait_counter ? wait_ticks :
        (decrement_wait_counter ? (wait_counter - 1'b1) : wait_counter);
    assign new_note = (state == `NEW_NOTE_READY) && !command_is_wait;
    assign note = command_note;
    assign duration = command_duration;
    assign note_metadata = command_metadata;
    assign song_done = overflow;
    assign event_index = curr_note_num;

endmodule