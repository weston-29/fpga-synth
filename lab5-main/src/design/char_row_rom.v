module char_row_rom (
    input  wire [7:0] ascii,
    input  wire [2:0] row,
    output wire [7:0] bits
);

    wire [8:0] rom_addr;
    assign rom_addr = {ascii[5:0], row};

    tcgrom font_rom (
        .addr(rom_addr),
        .data(bits)
    );

endmodule