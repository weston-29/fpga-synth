`timescale 1ns / 1ps

module wave_display_tb();

    reg clk, reset, valid, read_index;
    reg [10:0] x;
    reg [9:0]  y;
    wire [8:0] read_address;
    wire [7:0] read_value;
    wire valid_pixel;
    wire [7:0] r, g, b;

    // --- Pipelining X and Y in the TB to match DUT Latency (2 cycles) ---
    reg [10:0] x_pipe1, x_pipe2;
    reg [9:0]  y_pipe1, y_pipe2;
    reg        val_pipe1, val_pipe2;

    always @(posedge clk) begin
        x_pipe1 <= x; x_pipe2 <= x_pipe1;
        y_pipe1 <= y; y_pipe2 <= y_pipe1;
        val_pipe1 <= valid; val_pipe2 <= val_pipe1;
    end

    // --- Connections ---
    fake_sample_ram fake_ram (
        .clk(clk),
        .addr(read_address[7:0]), 
        .dout(read_value)
    );

    wave_display dut (
        .clk(clk), .reset(reset), .x(x), .y(y), .valid(valid),
        .read_value(read_value), .read_index(read_index),
        .read_address(read_address), .valid_pixel(valid_pixel),
        .r(r), .g(g), .b(b)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // --- Enhanced Verification Logic ---
    always @(posedge clk) begin
        if (!reset && val_pipe2) begin
            // Error check: Q1 is 000, Q4 is 011. 
            // Anything else (001 or 010) is Q2/Q3 and should NOT trigger an error.
            if ((x_pipe2[10:8] == 3'b000 || x_pipe2[10:8] == 3'b011) && valid_pixel) begin
                $display("  [!] ERROR: Pixel leaked into Q1/Q4 at x=%d", x_pipe2);
            end

            // SUCCESS LOGGING: Print when we actually find the wave
            // This proves the logic isn't just "always zero"
            if (valid_pixel) begin
                $display("  [MATCH] Valid Pixel at x=%d, y=%d | RAM_Addr=%h", 
                          x_pipe2, y_pipe2, read_address);
            end
        end
    end

    initial begin
        reset = 1; x = 0; y = 0; valid = 0; read_index = 0;
        repeat (10) @(posedge clk);
        reset = 0;
        
        $display("--- Starting Forced Debug Test ---");

        // We pick an X in the middle of Q2
        x = 11'd300; 
        valid = 1;
        
        // Give the pipeline 10 cycles to fill with RAM data
        repeat (10) @(posedge clk);

        $display("Sweeping Y from 0 to 255 at X=300...");
        for (integer i = 0; i < 256; i = i + 1) begin
            y = i;
            @(posedge clk);
            // This force-prints the state of your module's signals 
            // so we can see the internal math in the console
            if (i % 32 == 0) begin
                $display("  Check at y=%d: valid_pixel=%b, R=%h", i, valid_pixel, r);
            end
        end

        $display("--- Debug Test Complete ---");
        $finish;
    end

endmodule