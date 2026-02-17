module mcu(
    input clk,
    input reset,
    input play_button,
    input next_button,
    output reg play,
    output reg reset_player,
    output reg [1:0] song,
    input song_done
);

    always @(posedge clk) begin
    
        if (reset) begin
            song <= 2'b00;
            reset_player <= 1'b1;
            play <= 1'b0;
            
        end else begin
            reset_player <= 1'b0;
            
            if(next_button) begin
                song <= song + 1'b1;
                play <= 1'b0;
                reset_player <= 1'b1;
            end
            else if(song_done) begin
                song <= song + 1'b1;
                play <= 1'b0;
                reset_player <= 1'b1;
            end
            else if(play_button) begin
                play <= ~play;
            end
        end
    end
    
endmodule