module note_code_to_ascii (
    input  wire       note_valid,
    input  wire [5:0] note_code,
    output reg [31:0] text_ascii
);

    always @(*) begin
        if (!note_valid || (note_code == 6'd0)) begin
            text_ascii = {8'h52, 8'h45, 8'h53, 8'h54}; // "REST"
        end else begin
            case (note_code)

                6'd1:  text_ascii = {8'h31, 8'h41, 8'h20, 8'h20}; // 1A
                6'd2:  text_ascii = {8'h31, 8'h41, 8'h23, 8'h20}; // 1A#
                6'd3:  text_ascii = {8'h31, 8'h42, 8'h20, 8'h20}; // 1B
                6'd4:  text_ascii = {8'h31, 8'h43, 8'h20, 8'h20}; // 1C
                6'd5:  text_ascii = {8'h31, 8'h43, 8'h23, 8'h20}; // 1C#
                6'd6:  text_ascii = {8'h31, 8'h44, 8'h20, 8'h20}; // 1D
                6'd7:  text_ascii = {8'h31, 8'h44, 8'h23, 8'h20}; // 1D#
                6'd8:  text_ascii = {8'h31, 8'h45, 8'h20, 8'h20}; // 1E
                6'd9:  text_ascii = {8'h31, 8'h46, 8'h20, 8'h20}; // 1F
                6'd10: text_ascii = {8'h31, 8'h46, 8'h23, 8'h20}; // 1F#
                6'd11: text_ascii = {8'h31, 8'h47, 8'h20, 8'h20}; // 1G
                6'd12: text_ascii = {8'h31, 8'h47, 8'h23, 8'h20}; // 1G#

                6'd13: text_ascii = {8'h32, 8'h41, 8'h20, 8'h20}; // 2A
                6'd14: text_ascii = {8'h32, 8'h41, 8'h23, 8'h20}; // 2A#
                6'd15: text_ascii = {8'h32, 8'h42, 8'h20, 8'h20}; // 2B
                6'd16: text_ascii = {8'h32, 8'h43, 8'h20, 8'h20}; // 2C
                6'd17: text_ascii = {8'h32, 8'h43, 8'h23, 8'h20}; // 2C#
                6'd18: text_ascii = {8'h32, 8'h44, 8'h20, 8'h20}; // 2D
                6'd19: text_ascii = {8'h32, 8'h44, 8'h23, 8'h20}; // 2D#
                6'd20: text_ascii = {8'h32, 8'h45, 8'h20, 8'h20}; // 2E
                6'd21: text_ascii = {8'h32, 8'h46, 8'h20, 8'h20}; // 2F
                6'd22: text_ascii = {8'h32, 8'h46, 8'h23, 8'h20}; // 2F#
                6'd23: text_ascii = {8'h32, 8'h47, 8'h20, 8'h20}; // 2G
                6'd24: text_ascii = {8'h32, 8'h47, 8'h23, 8'h20}; // 2G#

                6'd25: text_ascii = {8'h33, 8'h41, 8'h20, 8'h20}; // 3A
                6'd26: text_ascii = {8'h33, 8'h41, 8'h23, 8'h20}; // 3A#
                6'd27: text_ascii = {8'h33, 8'h42, 8'h20, 8'h20}; // 3B
                6'd28: text_ascii = {8'h33, 8'h43, 8'h20, 8'h20}; // 3C
                6'd29: text_ascii = {8'h33, 8'h43, 8'h23, 8'h20}; // 3C#
                6'd30: text_ascii = {8'h33, 8'h44, 8'h20, 8'h20}; // 3D
                6'd31: text_ascii = {8'h33, 8'h44, 8'h23, 8'h20}; // 3D#
                6'd32: text_ascii = {8'h33, 8'h45, 8'h20, 8'h20}; // 3E
                6'd33: text_ascii = {8'h33, 8'h46, 8'h20, 8'h20}; // 3F
                6'd34: text_ascii = {8'h33, 8'h46, 8'h23, 8'h20}; // 3F#
                6'd35: text_ascii = {8'h33, 8'h47, 8'h20, 8'h20}; // 3G
                6'd36: text_ascii = {8'h33, 8'h47, 8'h23, 8'h20}; // 3G#

                6'd37: text_ascii = {8'h34, 8'h41, 8'h20, 8'h20}; // 4A
                6'd38: text_ascii = {8'h34, 8'h41, 8'h23, 8'h20}; // 4A#
                6'd39: text_ascii = {8'h34, 8'h42, 8'h20, 8'h20}; // 4B
                6'd40: text_ascii = {8'h34, 8'h43, 8'h20, 8'h20}; // 4C
                6'd41: text_ascii = {8'h34, 8'h43, 8'h23, 8'h20}; // 4C#
                6'd42: text_ascii = {8'h34, 8'h44, 8'h20, 8'h20}; // 4D
                6'd43: text_ascii = {8'h34, 8'h44, 8'h23, 8'h20}; // 4D#
                6'd44: text_ascii = {8'h34, 8'h45, 8'h20, 8'h20}; // 4E
                6'd45: text_ascii = {8'h34, 8'h46, 8'h20, 8'h20}; // 4F
                6'd46: text_ascii = {8'h34, 8'h46, 8'h23, 8'h20}; // 4F#
                6'd47: text_ascii = {8'h34, 8'h47, 8'h20, 8'h20}; // 4G
                6'd48: text_ascii = {8'h34, 8'h47, 8'h23, 8'h20}; // 4G#

                6'd49: text_ascii = {8'h35, 8'h41, 8'h20, 8'h20}; // 5A
                6'd50: text_ascii = {8'h35, 8'h41, 8'h23, 8'h20}; // 5A#
                6'd51: text_ascii = {8'h35, 8'h42, 8'h20, 8'h20}; // 5B
                6'd52: text_ascii = {8'h35, 8'h43, 8'h20, 8'h20}; // 5C
                6'd53: text_ascii = {8'h35, 8'h43, 8'h23, 8'h20}; // 5C#
                6'd54: text_ascii = {8'h35, 8'h44, 8'h20, 8'h20}; // 5D
                6'd55: text_ascii = {8'h35, 8'h44, 8'h23, 8'h20}; // 5D#
                6'd56: text_ascii = {8'h35, 8'h45, 8'h20, 8'h20}; // 5E
                6'd57: text_ascii = {8'h35, 8'h46, 8'h20, 8'h20}; // 5F
                6'd58: text_ascii = {8'h35, 8'h46, 8'h23, 8'h20}; // 5F#
                6'd59: text_ascii = {8'h35, 8'h47, 8'h20, 8'h20}; // 5G
                6'd60: text_ascii = {8'h35, 8'h47, 8'h23, 8'h20}; // 5G#

                6'd61: text_ascii = {8'h36, 8'h41, 8'h20, 8'h20}; // 6A
                6'd62: text_ascii = {8'h36, 8'h41, 8'h23, 8'h20}; // 6A#
                6'd63: text_ascii = {8'h36, 8'h42, 8'h20, 8'h20}; // 6B

                default: text_ascii = {8'h52, 8'h45, 8'h53, 8'h54}; // REST
            endcase
        end
    end

endmodule