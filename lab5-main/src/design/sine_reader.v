module sine_reader(
    input clk,
    input reset,
    input [19:0] step_size,
    input generate_next,

    output sample_ready,
    output wire [15:0] sample
);

    wire [21:0] cur_adr, next_adr; // for D and Q of main flipflop
    
    wire [9:0] rom_adr;
    wire [15:0] rom_dout;
    wire invert_bit; // Quadrant LSB
    wire negate_bit; // Quadrant MSB
    
    assign next_adr = cur_adr + {2'b0, step_size};
    
    dffre #(22) counter ( // main next address flop
        .clk(clk),
        .r(reset),
        .en(generate_next),
        .d(next_adr),
        .q(cur_adr)
    );
    
    // Quadrant Logic
    assign invert_bit = cur_adr[20]; 
    assign rom_adr = invert_bit ? ~cur_adr[19:10] : cur_adr[19:10];
    
    sine_rom sample_rom (
        .clk(clk),
        .addr(rom_adr),
        .dout(rom_dout)
    );
    
    wire delayed_negate;
    
    dffr #(1) sign_delay ( // delay quadrant sine bit by one cycle to get negation timing at output
        .clk(clk),
        .r(reset),
        .d(cur_adr[21]), // MSB
        .q(delayed_negate)
    );
    
    dffr #(1) ready_delay ( // delay generate_next by one cycle to get sample_ready timing
        .clk(clk),
        .r(reset),
        .d(generate_next),
        .q(sample_ready)
    );
    
    assign sample = delayed_negate ? (16'b0 - rom_dout) : rom_dout;

endmodule