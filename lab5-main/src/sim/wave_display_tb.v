`timescale 1ns/1ps

module wave_display_tb;

    // -------------------------------------------------------
    // DUT + fake RAM signals
    // -------------------------------------------------------
    reg         clk, reset;
    reg  [10:0] x;
    reg  [9:0]  y;
    reg         valid;
    reg         read_index;

    wire [7:0]  read_value;
    wire [8:0]  read_address;
    wire        valid_pixel;
    wire [7:0]  r, g, b;

    // -------------------------------------------------------
    // Instantiate DUT
    // -------------------------------------------------------
    wave_display dut (
        .clk         (clk),
        .reset       (reset),
        .x           (x),
        .y           (y),
        .valid       (valid),
        .read_value  (read_value),
        .read_index  (read_index),
        .read_address(read_address),
        .valid_pixel (valid_pixel),
        .r(r), .g(g), .b(b)
    );

    // -------------------------------------------------------
    // Fake RAM: read_value = read_address[7:0], one cycle later
    // -------------------------------------------------------
    fake_sample_ram fake_ram (
        .clk  (clk),
        .addr (read_address[7:0]),
        .dout (read_value)
    );

    // -------------------------------------------------------
    // Clock
    // -------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------
    // Error tracking
    // -------------------------------------------------------
    integer errors = 0;

    // -------------------------------------------------------
    // Check task: compare valid_pixel against expected,
    // always print result so every check is visible
    // -------------------------------------------------------
    task check;
        input [10:0] cx;
        input [9:0]  cy;
        input        expected;
        input [63:0] label;  // cycle number for display
        begin
            if (valid_pixel !== expected) begin
                $display("FAIL  cycle=%0d x=%0d y=%0d | valid_pixel=%b expected=%b | cur=%0d prev=%0d",
                         label, cx, cy, valid_pixel, expected,
                         dut.cur_sample, dut.prev_sample);
                errors = errors + 1;
            end else begin
                $display("PASS  cycle=%0d x=%0d y=%0d | valid_pixel=%b | cur=%0d prev=%0d bounds=[%0d,%0d]",
                         label, cx, cy, valid_pixel,
                         dut.cur_sample, dut.prev_sample,
                         dut.lower_bound, dut.upper_bound);
            end
        end
    endtask

    // -------------------------------------------------------
    // Advance one clock cycle and optionally check
    // -------------------------------------------------------
    integer cycle;

    task tick;
        begin
            @(posedge clk); #1;
            cycle = cycle + 1;
        end
    endtask

    // -------------------------------------------------------
    // Main test
    // -------------------------------------------------------
    initial begin
        cycle      = 0;
        reset      = 1;
        x          = 11'd256;
        y          = 10'd64;   // y_val=32 by default
        valid      = 1;
        read_index = 0;

        tick; tick;           // hold reset for 2 cycles
        reset = 0;

        // -------------------------------------------------
        // TEST 1: Scan x across Q2 from 256 upward.
        // Check specific (x,y) pairs against pre-computed
        // bounds derived from the fake RAM trace above.
        // -------------------------------------------------
        $display("\n=== TEST 1: Spot checks at known x/y values ===");

        // Advance x=256..261 to let pipeline fill
        x = 11'd256; tick;   // cycle 3 after reset
        x = 11'd257; tick;
        x = 11'd258; tick;
        x = 11'd259; tick;
        x = 11'd260; tick;
        x = 11'd261; tick;

        // At x=262 (cycle 9 from reset=0):
        // cur=33, prev=32 ? bounds=[32,33]
        x = 11'd262;

        // y_val=32 (y=64) ? should be lit
        y = 10'd64; tick;
        check(11'd262, 10'd64, 1'b1, cycle);

        // y_val=33 (y=66) ? should be lit
        y = 10'd66; x = 11'd262; tick;
        check(11'd262, 10'd66, 1'b1, cycle);

        // y_val=31 (y=62) ? should NOT be lit
        y = 10'd62; x = 11'd262; tick;
        check(11'd262, 10'd62, 1'b0, cycle);

        // y_val=34 (y=68) ? should NOT be lit
        y = 10'd68; x = 11'd262; tick;
        check(11'd262, 10'd68, 1'b0, cycle);

        // -------------------------------------------------
        // TEST 2: Out-of-bounds regions never light
        // -------------------------------------------------
        $display("\n=== TEST 2: Out-of-bounds x/y ===");

        // Bottom half: y[9]=1 ? never valid
        y = 10'd600; x = 11'd262; tick;
        check(11'd262, 10'd600, 1'b0, cycle);

        // Q1: x[10:8]=000 ? never valid (x=100)
        y = 10'd64; x = 11'd100; tick;
        check(11'd100, 10'd64, 1'b0, cycle);

        // Q4: x[10:8]=011 ? never valid (x=768)
        y = 10'd64; x = 11'd768; tick;
        check(11'd768, 10'd64, 1'b0, cycle);

        // -------------------------------------------------
        // TEST 3: Scan a full row in Q2 and print all
        // lit pixels to visually verify ramp shape.
        // Reset x to 256 and scan to 511.
        // Expected: valid_pixel rises as x increases,
        // lighting pixels whose y_val tracks the
        // monotonically increasing adjusted sample value.
        // -------------------------------------------------
        $display("\n=== TEST 3: Row scan x=256..299, y=50 (y_val=25) ===");
        // y_val=25 is below the ramp (ramp starts at ~32),
        // so valid_pixel should be 0 for the whole row.
        y = 10'd50;
        begin : scan_low
            integer xi;
            for (xi = 256; xi < 300; xi = xi + 1) begin
                x = xi[10:0]; tick;
                if (valid_pixel) begin
                    $display("UNEXPECTED lit pixel x=%0d y=50 y_val=25", xi);
                    errors = errors + 1;
                end
            end
        end
        $display("  Row scan y=50 complete (expected all dark)");

        $display("\n=== TEST 3b: Row scan x=256..299, y=64 (y_val=32) ===");
        // y_val=32 is exactly at the start of the ramp.
        // First few columns will be dark (pipeline filling),
        // then lit once bounds reach 32.
        y = 10'd64;
        begin : scan_ramp
            integer xi2;
            for (xi2 = 256; xi2 < 300; xi2 = xi2 + 1) begin
                x = xi2[10:0]; tick;
                // Only print lit pixels so output is readable
                if (valid_pixel)
                    $display("  LIT x=%0d y=64 | cur=%0d prev=%0d bounds=[%0d,%0d]",
                             xi2, dut.cur_sample, dut.prev_sample,
                             dut.lower_bound, dut.upper_bound);
            end
        end
        $display("  Row scan y=64 complete");

        // -------------------------------------------------
        // Results
        // -------------------------------------------------
        $display("\n=== RESULTS: %0d error(s) ===", errors);
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("FAILED");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #500_000;
        $display("TIMEOUT");
        $finish;
    end

endmodule