module song_reader(
input clk,
input reset,
input play,
input [1:0] song,
input note_done,
output reg song_done,
output reg [5:0] note,
output reg [5:0] duration,
output reg new_note
);
    localparam WAIT_PLAY = 2'b00;
    localparam FETCH_NOTE = 2'b01;
    localparam LATCH_NOTE = 2'b10;
    localparam WAIT_DONE = 2'b11;
    
    reg [1:0] state;
    reg [4:0] counter;
    wire [11:0] rom_out;
    
    song_rom init_rom (.clk(clk),.addr({song, counter}), .dout(rom_out));

    always @(posedge clk) begin
    
        if (reset) begin
            song_done <= 1'b0;
            state <= WAIT_PLAY;
            counter <= 5'b0;
            duration <= 6'b0;
            new_note <= 1'b0;
            note <= 6'b0;
     
        end else begin
            new_note <= 1'b0;
            
            case(state)
                WAIT_PLAY: begin
                    song_done <= 1'b0;
                    if(play) begin
                        state <= FETCH_NOTE;
                    end
                end
                FETCH_NOTE: begin
                    state <= LATCH_NOTE;
                end
                LATCH_NOTE: begin
                    note <= rom_out [11:6];
                    duration <= rom_out [5:0];
                    if(rom_out [5:0] == 6'b0) begin
                        song_done <= 1'b1;
                        state <= WAIT_PLAY;
                    end else begin
                        new_note <= 1'b1;
                        state <= WAIT_DONE;
                        $display("Playing note %d of song %d, which is note %d duration %d", 
                        counter, song, rom_out[11:6], rom_out[5:0]);
                    end
                end
                WAIT_DONE: begin
                    if(!play) begin
                        state <= WAIT_DONE;
                    end else if (note_done) begin
                        if(counter == 5'd31) begin
                            state <= WAIT_PLAY;
                            song_done <= 1'b1;
                        end else begin
                            counter <= counter + 1'b1;
                            state <= FETCH_NOTE;
                        end
                    end
                end
            endcase
        end
    end    
endmodule