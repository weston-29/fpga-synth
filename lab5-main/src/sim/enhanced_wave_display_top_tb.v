`timescale 1ns/1ps

module enhanced_wave_display_top_tb;

    reg clk, reset;
    reg new_sample;
    reg [15:0] sum_sample, voice0_sample, voice1_sample, voice2_sample;
    reg [10:0] x;
    reg [9:0]  y;
    reg valid;
    reg vsync;

    wire pixel_on;
    wire [7:0] r, g, b;

    enhanced_wave_display_top dut (
        .clk(clk),
        .reset(reset),
        .new_sample(new_sample),
        .sum_sample(sum_sample),
        .voice0_sample(voice0_sample),
        .voice1_sample(voice1_sample),
        .voice2_sample(voice2_sample),
        .x(x),
        .y(y),
        .valid(valid),
        .vsync(vsync),
        .pixel_on(pixel_on),
        .r(r),
        .g(g),
        .b(b)
    );

    // Faster clock so full TB fits in short simulator runtime
    initial clk = 1'b0;
    always #0.5 clk = ~clk;   // 1 ns period

    integer errors;
    integer i;

    localparam [1:0] EW_ARMED  = 2'b00;
    localparam [1:0] EW_ACTIVE = 2'b01;
    localparam [1:0] EW_WAIT   = 2'b10;

    function [15:0] packed_sample_from_read;
        input [7:0] read_value;
        begin
            packed_sample_from_read = {~read_value[7], read_value[6:0], 8'h00};
        end
    endfunction

    function [15:0] packed_sample_from_display_y;
        input [7:0] display_y;
        reg [7:0] read_value;
        begin
            read_value = (display_y - 8'd32) << 1;
            packed_sample_from_display_y = packed_sample_from_read(read_value);
        end
    endfunction

    localparam [7:0] Y_V0  = 8'd60;
    localparam [7:0] Y_V1  = 8'd80;
    localparam [7:0] Y_SUM = 8'd100;
    localparam [7:0] Y_V2  = 8'd120;

    localparam [15:0] SAMPLE_V0  = packed_sample_from_display_y(Y_V0);
    localparam [15:0] SAMPLE_V1  = packed_sample_from_display_y(Y_V1);
    localparam [15:0] SAMPLE_SUM = packed_sample_from_display_y(Y_SUM);
    localparam [15:0] SAMPLE_V2  = packed_sample_from_display_y(Y_V2);

    task expect1;
        input actual;
        input expected;
        input [511:0] label;
        begin
            if (actual !== expected) begin
                $display("FAIL %0s got=%0b exp=%0b", label, actual, expected);
                errors = errors + 1;
            end else begin
                $display("PASS %0s = %0b", label, actual);
            end
        end
    endtask

    task expect8;
        input [7:0] actual;
        input [7:0] expected;
        input [511:0] label;
        begin
            if (actual !== expected) begin
                $display("FAIL %0s got=%02h exp=%02h", label, actual, expected);
                errors = errors + 1;
            end else begin
                $display("PASS %0s = %02h", label, actual);
            end
        end
    endtask

    task expect9;
        input [8:0] actual;
        input [8:0] expected;
        input [511:0] label;
        begin
            if (actual !== expected) begin
                $display("FAIL %0s got=%03h exp=%03h", label, actual, expected);
                errors = errors + 1;
            end else begin
                $display("PASS %0s = %03h", label, actual);
            end
        end
    endtask

    task wait_clks;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1)
                @(posedge clk);
            #0.1;
        end
    endtask

    task sample_pulse_hold;
        input [15:0] ssum;
        input [15:0] sv0;
        input [15:0] sv1;
        input [15:0] sv2;
        begin
            sum_sample    = ssum;
            voice0_sample = sv0;
            voice1_sample = sv1;
            voice2_sample = sv2;
            new_sample    = 1'b1;
            @(posedge clk);
            #0.1;
        end
    endtask

    task sample_release;
        begin
            new_sample = 1'b0;
            @(posedge clk);
            #0.1;
        end
    endtask

    task drive_sample;
        input [15:0] ssum;
        input [15:0] sv0;
        input [15:0] sv1;
        input [15:0] sv2;
        begin
            sample_pulse_hold(ssum, sv0, sv1, sv2);
            sample_release();
        end
    endtask

    task warm_display_at_y;
        input [9:0] y_in;
        integer xi;
        begin
            y = y_in;
            for (xi = 262; xi <= 276; xi = xi + 2) begin
                x = xi[10:0];
                @(posedge clk);
                #0.1;
            end
        end
    endtask

    task check_color;
        input [9:0] y_in;
        input exp_on;
        input [7:0] exp_r;
        input [7:0] exp_g;
        input [7:0] exp_b;
        input [511:0] label;
        begin
            warm_display_at_y(y_in);
            expect1(pixel_on, exp_on, {label, " pixel_on"});
            expect8(r, exp_r, {label, " r"});
            expect8(g, exp_g, {label, " g"});
            expect8(b, exp_b, {label, " b"});
        end
    endtask

    initial begin
        errors = 0;
        reset = 1'b1;
        new_sample = 1'b0;
        sum_sample = 16'h0000;
        voice0_sample = 16'h0000;
        voice1_sample = 16'h0000;
        voice2_sample = 16'h0000;
        x = 11'd262;
        y = 10'd200;
        valid = 1'b1;
        vsync = 1'b1;

        wait_clks(2);
        reset = 1'b0;
        wait_clks(1);

        $display("\n=== TEST 1: trigger starts enhanced capture ===");

        // Pre-trigger negative sample: should not capture yet
        drive_sample(16'h8000, SAMPLE_V0, SAMPLE_V1, SAMPLE_V2);
        expect1(dut.ewc.write_enable, 1'b0, "write_enable before crossing");

        // Triggering sample
        sample_pulse_hold(SAMPLE_SUM, SAMPLE_V0, SAMPLE_V1, SAMPLE_V2);
        expect1(dut.ewc.write_enable, 1'b1, "write_enable on triggering sample");
        expect1(dut.ewc.state == EW_ACTIVE, 1'b1, "state enters ACTIVE on trigger");
        expect9(dut.write_address, 9'h101, "first captured sample writes bank-1 addr 1");
        sample_release();

        // Second sample should advance address again
        sample_pulse_hold(SAMPLE_SUM, SAMPLE_V0, SAMPLE_V1, SAMPLE_V2);
        expect1(dut.ewc.write_enable, 1'b1, "write_enable on second captured sample");
        expect9(dut.write_address, 9'h102, "write_address advances to bank-1 addr 2");
        sample_release();

        $display("\n=== TEST 2: capture fills 256 samples then flips read bank on idle ===");

        // Already captured 2 samples in Test 1, so do 254 more
        for (i = 0; i < 254; i = i + 1)
            drive_sample(SAMPLE_SUM, SAMPLE_V0, SAMPLE_V1, SAMPLE_V2);

        expect1(dut.ewc.state == EW_WAIT, 1'b1, "capture enters WAIT after 256 samples");
        expect1(dut.read_index, 1'b0, "read_index before idle flip");

        vsync = 1'b0;
        @(posedge clk);
        #0.1;
        expect1(dut.read_index, 1'b1, "read_index flips after idle");
        expect1(dut.ewc.state == EW_ARMED, 1'b1, "capture returns to ARMED");
        vsync = 1'b1;
        wait_clks(2);

        $display("\n=== TEST 3: compositor shows individual voice colors and white sum trace ===");

        check_color({Y_V0, 1'b0}, 1'b1, 8'hFF, 8'h00, 8'h00, "voice0 red trace");
        expect1(dut.v0_on, 1'b1, "voice0 internal valid");

        check_color({Y_V1, 1'b0}, 1'b1, 8'h00, 8'hFF, 8'h00, "voice1 green trace");
        expect1(dut.v1_on, 1'b1, "voice1 internal valid");

        check_color({Y_V2, 1'b0}, 1'b1, 8'h00, 8'h00, 8'hFF, "voice2 blue trace");
        expect1(dut.v2_on, 1'b1, "voice2 internal valid");

        check_color({Y_SUM, 1'b0}, 1'b1, 8'hFF, 8'hFF, 8'hFF, "sum white trace");
        expect1(dut.sum_on, 1'b1, "sum internal valid");

        check_color(10'd20, 1'b0, 8'h00, 8'h00, 8'h00, "background off trace");

        $display("\n=== RESULTS: %0d error(s) ===", errors);
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("FAILED");
        $finish;
    end

    initial begin
        #10000;
        $display("TIMEOUT");
        $finish;
    end

endmodule


module dffr #(parameter WIDTH=1) (
    input clk,
    input r,
    input [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);
    always @(posedge clk) begin
        if (r) q <= {WIDTH{1'b0}};
        else   q <= d;
    end
endmodule


module dffre #(parameter WIDTH=1) (
    input clk,
    input r,
    input en,
    input [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);
    always @(posedge clk) begin
        if (r)      q <= {WIDTH{1'b0}};
        else if(en) q <= d;
    end
endmodule


module ram_1w2r #(parameter WIDTH=8, DEPTH=9) (
    input                  clka,
    input                  clkb,
    input                  wea,
    input      [DEPTH-1:0] addra,
    input      [WIDTH-1:0] dina,
    output reg [WIDTH-1:0] douta,
    input      [DEPTH-1:0] addrb,
    output reg [WIDTH-1:0] doutb
);
    reg [WIDTH-1:0] mem [0:(1<<DEPTH)-1];
    integer idx;

    initial begin
        for (idx = 0; idx < (1<<DEPTH); idx = idx + 1)
            mem[idx] = {WIDTH{1'b0}};
        douta = {WIDTH{1'b0}};
        doutb = {WIDTH{1'b0}};
    end

    always @(posedge clka) begin
        if (wea)
            mem[addra] <= dina;
        douta <= mem[addra];
    end

    always @(posedge clkb) begin
        doutb <= mem[addrb];
    end
endmodule