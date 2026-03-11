module enhanced_wave_compositor #(
    parameter NUM_VOICES = 3
)(
    input wave_sum_on,
    input [NUM_VOICES-1:0] wave_voice_on,

    output wire out_on,
    output wire [7:0] out_r,
    output wire [7:0] out_g,
    output wire [7:0] out_b
);

    wire voice0_on = wave_voice_on[0];
    wire voice1_on = wave_voice_on[1];
    wire voice2_on = wave_voice_on[2];

    assign out_on = wave_sum_on | (|wave_voice_on);

    assign out_r = wave_sum_on ? 8'hFF :
                   voice0_on   ? 8'hFF :
                   8'h00;

    assign out_g = wave_sum_on ? 8'hFF :
                   voice1_on   ? 8'hFF :
                   8'h00;

    assign out_b = wave_sum_on ? 8'hFF :
                   voice2_on   ? 8'hFF :
                   8'h00;

endmodule