`timescale 1ns/1ps
module wave_display_tb();

reg clk, reset, valid, read_index;
reg [10:0] x;
reg [9:0] y;
reg errors;
wire [8:0] read_address;
wire [7:0] read_value;
wire valid_pixel;
wire [7:0] r, g, b;

wave_display dut (
    .clk(clk), .reset(reset), .x(x), .y(y), .valid(valid),
    .read_value(read_value), .read_index(read_index),
    .read_address(read_address), .valid_pixel(valid_pixel),
    .r(r), .g(g), .b(b)
);

fake_sample_ram fake_ram (
    .clk(clk),
    .addr(read_address[7:0]),
    .dout(read_value)
);

always begin
    #5 clk = 0;
    #5 clk = 1;
end

initial begin
    // Reset
    reset = 1; valid = 1; read_index = 0;
    x = 0; y = 0; errors = 0;
    #20 reset = 0;

    // -------------------------------------------------------
    // TEST 1: Out of bounds - Q1 (x[10:8]=000), top half
    // valid_pixel must never fire here
    // -------------------------------------------------------
    x = 11'd100; y = 10'd100;
    #10
    $display("TEST 1 (Q1, in bounds x): valid_pixel=%b, expected=0", valid_pixel);
    if (valid_pixel !== 1'b0) begin errors = 1; $display("FAIL test 1"); end

    // -------------------------------------------------------
    // TEST 2: Out of bounds - bottom half (y[9]=1), Q2 x
    // valid_pixel must never fire here
    // -------------------------------------------------------
    x = 11'd300; y = 10'd600;  // y[9]=1 -> bottom half
    #10
    $display("TEST 2 (Q2 x, bottom half y): valid_pixel=%b, expected=0", valid_pixel);
    if (valid_pixel !== 1'b0) begin errors = 1; $display("FAIL test 2"); end

    // -------------------------------------------------------
    // TEST 3: In-bounds region, Q2, scan two adjacent columns
    // With fake RAM: read_value = addr = {read_index, x[9], x[7:1]}[7:0]
    // At x=256 (Q2 start): addr[7:0] = {0, 0000000} = 0, adj = 0+32 = 32
    // At x=258:            addr[7:0] = {0, 0000001} = 1, adj = 0+32 = 32 (same, >>1 of 1 = 0)
    // At x=260:            addr[7:0] = {0, 0000010} = 2, adj = 1+32 = 33
    // So around x=260, y_val=32 or 33 should produce valid_pixel=1
    // Pipeline delay: valid_pixel reflects x from ONE cycle ago
    // So drive x=260 then check on the NEXT #10
    // -------------------------------------------------------
    x = 11'd256; y = 10'd64;   // y_val = y[8:1] = 32, in top half
    #10                         // cycle N: addr=0 sent to RAM
    x = 11'd258; y = 10'd64;
    #10                         // cycle N+1: RAM returns 0, cur_sample latches adj=32
    x = 11'd260; y = 10'd64;
    #10                         // cycle N+2: RAM returns 2, cur latches 33, prev=32
                                // valid_pixel now reflects x=258's pixel
                                // y_val=32, lower=32, upper=33 -> should be 1
    $display("TEST 3 (in-bounds, y_val=32, expect lit): valid_pixel=%b, expected=1", valid_pixel);
    if (valid_pixel !== 1'b1) begin errors = 1; $display("FAIL test 3"); end

    // -------------------------------------------------------
    // TEST 4: Same column, y clearly above the waveform -> unlit
    // adj values near x=260 are 32-33, so y_val=100 should be off
    // -------------------------------------------------------
    x = 11'd256; y = 10'd200;  // y_val = 100
    #10
    x = 11'd258; y = 10'd200;
    #10
    x = 11'd260; y = 10'd200;
    #10
    $display("TEST 4 (in-bounds, y_val=100, expect unlit): valid_pixel=%b, expected=0", valid_pixel);
    if (valid_pixel !== 1'b0) begin errors = 1; $display("FAIL test 4"); end

    // -------------------------------------------------------
    // TEST 5: Q3 region (x[10:8]=010), still valid display zone
    // At x=512: addr[7:0] = {x[9]=1, x[7:1]=0000000} = 128
    // adj = 64 + 32 = 96, prev adj = 95
    // y_val=96 (y=192) should be lit
    // -------------------------------------------------------
    x = 11'd510; y = 10'd192;  // y_val = 96
    #10
    x = 11'd511; y = 10'd192;
    #10
    x = 11'd512; y = 10'd192;
    #10
    $display("TEST 5 (Q3, y_val=96, expect lit): valid_pixel=%b, expected=1", valid_pixel);
    if (valid_pixel !== 1'b1) begin errors = 1; $display("FAIL test 5"); end

    // -------------------------------------------------------
    // TEST 6: Q4 (x[10:8]=011) - out of bounds, must be unlit
    // -------------------------------------------------------
    x = 11'd768; y = 10'd100;
    #10
    $display("TEST 6 (Q4, expect unlit): valid_pixel=%b, expected=0", valid_pixel);
    if (valid_pixel !== 1'b0) begin errors = 1; $display("FAIL test 6"); end

    // -------------------------------------------------------
    // Result
    // -------------------------------------------------------
    if (errors == 0) $display("All tests passed!");
    else             $display("Errors detected.");
end

// Add this alongside your existing initial block
initial begin
    #2000;
    $display("WATCHDOG: valid_pixel never went high in 2000ns");
    $finish;
end

always @(posedge clk) begin
    if (valid_pixel === 1'b1) begin
        $display("valid_pixel went HIGH at time=%0t x=%0d y=%0d cur=%0d prev=%0d y_del=%0d in_bounds_del=%0b",
                 $time, x, y, dut.cur_sample, dut.prev_sample, dut.y_delayed, dut.in_bounds_delayed);
        $finish;
    end
end

always @(posedge clk) begin
    if (dut.in_bounds)
        $display("in_bounds HIGH at t=%0t x=%0d y=%0d", $time, x, y);
end

always @(posedge clk) begin
    if (dut.in_bounds_delayed)
        $display("in_bounds_delayed HIGH at t=%0t", $time);
end

always @(posedge clk) begin
    if (dut.addr_changed)
        $display("addr_changed at t=%0t addr=%0d cur=%0d prev=%0d y_del=%0d",
                 $time, dut.read_address, dut.cur_sample, dut.prev_sample, dut.y_delayed);
end

always @(posedge clk) begin
    $display("t=%0t read_address=%0d last_addr=%0d addr_changed=%b",
             $time, dut.read_address, dut.last_addr, dut.addr_changed);
end

endmodule