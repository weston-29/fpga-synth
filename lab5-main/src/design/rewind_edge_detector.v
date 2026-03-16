module rewind_edge_detector(
    input  wire clk,
    input  wire reset,
    input  wire sw,
    output wire pulse
);

    reg sw_d;

    always @(posedge clk) begin
        if (reset)
            sw_d <= 1'b0;
        else
            sw_d <= sw;
    end

    assign pulse = sw & ~sw_d;

endmodule