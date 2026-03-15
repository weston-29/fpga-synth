module playback_beat_generator #(
    parameter WIDTH       = 10,
    parameter NORMAL_STOP = 1000,
    parameter FAST_STOP   = 500
)(
    input  wire clk,
    input  wire reset,
    input  wire en,
    input  wire fast_forward,
    output wire beat
);

    reg [WIDTH-1:0] count;
    reg             fast_forward_d;

    wire [WIDTH-1:0] stop_value;
    wire             mode_changed;
    wire             terminal_count;

    assign stop_value     = fast_forward ? FAST_STOP[WIDTH-1:0] : NORMAL_STOP[WIDTH-1:0];
    assign mode_changed   = (fast_forward != fast_forward_d);
    assign terminal_count = (count == stop_value);
    assign beat           = en && terminal_count;

    always @(posedge clk) begin
        if (reset) begin
            count          <= {WIDTH{1'b0}};
            fast_forward_d <= 1'b0;
        end else begin
            fast_forward_d <= fast_forward;

            if (mode_changed) begin
                count <= {WIDTH{1'b0}};
            end else if (en) begin
                if (terminal_count)
                    count <= {WIDTH{1'b0}};
                else
                    count <= count + 1'b1;
            end
        end
    end

endmodule
