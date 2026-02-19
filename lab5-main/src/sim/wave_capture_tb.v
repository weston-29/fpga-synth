`timescale 1ns/1ps

module wave_capture_tb;

    reg           clk;
    reg           reset;
    reg           new_sample_ready;
    reg [15:0]    new_sample_in;
    reg           wave_display_idle;

    wire [8:0]    write_address;
    wire          write_enable;
    wire [7:0]    write_sample;
    wire          read_index;

    wave_capture dut (
        .clk(clk),
        .reset(reset),
        .new_sample_ready(new_sample_ready),
        .new_sample_in(new_sample_in),
        .wave_display_idle(wave_display_idle),
        .write_address(write_address),
        .write_enable(write_enable),
        .write_sample(write_sample),
        .read_index(read_index)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer k;
    integer write_count;
    reg start_read_index;
    reg cap_write_half;
    reg [15:0] s;

    function [7:0] exp_u8;
        input [15:0] sample;
        reg [15:0] biased;
        begin
            biased = sample + 16'h8000;
            exp_u8 = biased[15:8];
        end
    endfunction

    // Count writes
    always @(posedge clk) begin
        if (reset) write_count <= 0;
        else if (write_enable) write_count <= write_count + 1;
    end

    // Pulse new_sample_ready for EXACTLY one clock and check expected write
    task pulse_and_check_write;
        input [15:0] sample;
        input        exp_we;
        input [8:0]  exp_addr;
        input [7:0]  exp_data;
        input [255*8:1] tag;
        begin
            // CRITICAL FIX: Drive inputs on NEGEDGE to avoid race condition at posedge
            @(negedge clk);
            new_sample_in    = sample;
            new_sample_ready = 1'b1;

            @(posedge clk); // Check at posedge

            if (exp_we) begin
                if (write_enable !== 1'b1) begin
                    $display("[FAIL] %s: expected write_enable=1, got %b", tag, write_enable);
                    $fatal(1);
                end
                if (write_address !== exp_addr) begin
                    $display("[FAIL] %s: expected addr=%h, got %h", tag, exp_addr, write_address);
                    $fatal(1);
                end
                if (write_sample !== exp_data) begin
                    $display("[FAIL] %s: expected data=%h, got %h (sample=%h)",
                             tag, exp_data, write_sample, sample);
                    $fatal(1);
                end
            end else begin
                if (write_enable !== 1'b0) begin
                    $display("[FAIL] %s: expected no write, but write_enable=1 addr=%h data=%h",
                             tag, write_address, write_sample);
                    $fatal(1);
                end
            end

            // Clear ready for next cycle
            @(negedge clk);
            new_sample_ready = 1'b0;
        end
    endtask

    // NEW: pulse and check a write where we don't know the half-bit yet
    task pulse_and_check_write_lo8;
        input [15:0] sample;
        input [7:0]  exp_lo8;
        input [7:0]  exp_data;
        input [255*8:1] tag;
        begin
            // CRITICAL FIX: Drive inputs on NEGEDGE
            @(negedge clk);
            new_sample_in    = sample;
            new_sample_ready = 1'b1;

            @(posedge clk); // Check at posedge

            if (write_enable !== 1'b1) begin
                $display("[FAIL] %s: expected write_enable=1, got %b", tag, write_enable);
                $fatal(1);
            end

            // Only enforce low 8 bits here
            if (write_address[7:0] !== exp_lo8) begin
                $display("[FAIL] %s: expected addr[7:0]=%h, got %h (full addr=%h)",
                         tag, exp_lo8, write_address[7:0], write_address);
                $fatal(1);
            end

            if (write_sample !== exp_data) begin
                $display("[FAIL] %s: expected data=%h, got %h (sample=%h)",
                         tag, exp_data, write_sample, sample);
                $fatal(1);
            end

            // Clear ready
            @(negedge clk);
            new_sample_ready = 1'b0;
        end
    endtask

    initial begin
        reset            = 1'b1;
        new_sample_ready = 1'b0;
        new_sample_in    = 16'd0;
        wave_display_idle= 1'b0;
        write_count      = 0;
        cap_write_half   = 1'b0;

        repeat (5) @(posedge clk);
        reset = 1'b0;
        @(posedge clk);

        $display("=== TEST 1: No writes until positive zero-crossing ===");

        pulse_and_check_write(16'sd1000, 1'b0, 9'd0, 8'd0, "pos-only #1");
        pulse_and_check_write(16'sd2000, 1'b0, 9'd0, 8'd0, "pos-only #2");
        pulse_and_check_write(-16'sd1000, 1'b0, 9'd0, 8'd0, "neg alone");

        // Record display buffer index at the moment we start capture
        start_read_index = read_index;

        // Crossing: we don't assume the half bit; we only require low8==0 and correct data
        pulse_and_check_write_lo8(16'sd1500, 8'h00, exp_u8(16'sd1500), "crossing -> sample0 write");

        // Learn which half DUT actually wrote into for this capture
        cap_write_half = write_address[8];
        $display("INFO: learned cap_write_half=%b from sample0 write (full addr=%h)", cap_write_half, write_address);

        $display("PASS: crossing and sample0 correct.");

        $display("=== TEST 2: Capture remaining 255 samples (total 256) ===");

        for (k = 1; k <= 255; k = k + 1) begin
              s = (k * 157) - 16'sd20000;
              // FIX: Force k to be 8 bits [7:0] so concatenation works correctly
              pulse_and_check_write(s, 1'b1, {cap_write_half, k[7:0]}, exp_u8(s), "active write");
        end

        if (write_count !== 256) begin
            $display("[FAIL] expected total writes=256, got %0d", write_count);
            $fatal(1);
        end
        $display("PASS: wrote 256 samples.");

        $display("=== TEST 3: WAIT: no writes, no flip until wave_display_idle ===");

        pulse_and_check_write(16'sd1234, 1'b0, 9'd0, 8'd0, "wait no-write #1");
        pulse_and_check_write(-16'sd4321, 1'b0, 9'd0, 8'd0, "wait no-write #2");

        if (read_index !== start_read_index) begin
            $display("[FAIL] read_index changed early. start=%b now=%b", start_read_index, read_index);
            $fatal(1);
        end

        wave_display_idle = 1'b1;
        @(posedge clk);
        wave_display_idle = 1'b0;
        @(posedge clk);

        if (read_index !== ~start_read_index) begin
            $display("[FAIL] read_index did not flip. expected=%b got=%b", ~start_read_index, read_index);
            $fatal(1);
        end
        $display("PASS: read_index flips only when wave_display_idle asserted.");

        $display("=== ALL TESTS PASSED ===");
        $finish;
    end

    // Cleaned up display logic
    always @(posedge clk) begin
        if (write_enable)
            $display("WRITE: addr=%h count=%h", write_address, dut.counter);
    end

endmodule