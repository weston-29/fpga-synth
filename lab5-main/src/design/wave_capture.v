module wave_capture (
    input  wire        clk,
    input  wire        reset,
    input  wire        new_sample_ready,
    input  wire [15:0] new_sample_in,
    input  wire        wave_display_idle,

    output wire [8:0]  write_address,
    output wire        write_enable,
    output wire [7:0]  write_sample,
    output wire        read_index
);

    localparam [1:0]
        S_ARMED  = 2'd0,
        S_ACTIVE = 2'd1,
        S_WAIT   = 2'd2;

    reg [1:0] state, state_next;

    reg [7:0] count, count_next;

    reg read_index_r, read_index_next;

    reg [15:0] prev_sample, prev_sample_next;

    reg        we_r;
    reg [8:0]  waddr_r;
    reg [7:0]  wdata_r;

    assign write_enable  = we_r;
    assign write_address = waddr_r;
    assign write_sample  = wdata_r;
    assign read_index    = read_index_r;

    wire [15:0] biased_sample;
    assign biased_sample = new_sample_in + 16'h8000;
    
    wire [7:0] sample_u8;
    assign sample_u8 = biased_sample[15:8];


    wire signed [15:0] cur_s  = $signed(new_sample_in);
    wire signed [15:0] prev_s = $signed(prev_sample);

    wire pos_zero_cross = (prev_s < 0) && (cur_s > 0);

    always @* begin
        state_next      = state;
        count_next      = count;
        read_index_next = read_index_r;
        prev_sample_next= prev_sample;

        we_r    = 1'b0;
        waddr_r = 9'd0;
        wdata_r = 8'd0;

        case (state)
            S_ARMED: begin
                count_next = 8'd0;

                if (new_sample_ready) begin
                    if (pos_zero_cross) begin
                        we_r    = 1'b1;
                        waddr_r = {~read_index_r, 8'd0};
                        wdata_r = sample_u8;

                        count_next = 8'd1;
                        state_next = S_ACTIVE;
                    end

                    prev_sample_next = new_sample_in;
                end
            end

            S_ACTIVE: begin
                if (new_sample_ready) begin
                    we_r    = 1'b1;
                    waddr_r = {~read_index_r, count};
                    wdata_r = sample_u8;

                    if (count == 8'd255) begin
                        state_next = S_WAIT;
                    end else begin
                        count_next = count + 8'd1;
                    end
                end
            end

            S_WAIT: begin
                if (wave_display_idle) begin
                    read_index_next = ~read_index_r;
                    state_next      = S_ARMED;
                    count_next      = 8'd0;
                    prev_sample_next = 16'd0;
                end
            end

            default: begin
                state_next = S_ARMED;
                count_next = 8'd0;
            end
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            state        <= S_ARMED;
            count        <= 8'd0;
            read_index_r <= 1'b0;
            prev_sample  <= 16'd0;
        end else begin
            state        <= state_next;
            count        <= count_next;
            read_index_r <= read_index_next;
            prev_sample  <= prev_sample_next;
        end
    end

endmodule
