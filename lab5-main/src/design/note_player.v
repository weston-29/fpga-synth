module note_player(
    input clk,
    input reset,
    input play_enable,      
    input [5:0] note_to_load,  
    input [5:0] duration_to_load, 
    input load_new_note,  
    output done_with_note,  
    input beat,  
    input generate_next_sample,  
    output [15:0] sample_out,  
    output new_sample_ready  
);

    wire [5:0] cur_ctr, next_ctr;
    wire [5:0] note_in; 

    // holds note being played now
    dffre #(6) freq_reg (
        .clk(clk), 
        .r(reset), 
        .en(load_new_note),
        .d(note_to_load), 
        .q(note_in) 
    ); 
    
    wire [19:0] rom_dout;     // intermediate wire to correctly delay rom by 1 cycle
    wire [19:0] note_stepsize; // Now driven by the register

    frequency_rom f_rom (
        .clk(clk), 
        .addr(note_in), 
        .dout(rom_dout)       // ROM drives the register input
    );
    
    dffr #(20) step_size_reg (
        .clk(clk),
        .r(reset),
        .d(rom_dout),         // Input from ROM
        .q(note_stepsize)      // Output to sine_reader
    );
    
    // If loading a new note, start at duration_to_load
    // Otherwise, if beat is high, decrement
    wire [5:0] decremented_ctr = (cur_ctr == 6'b0) ? 6'b0 : (cur_ctr - 6'd1); // To prevent 0-wrapping, but does this latch the counter at 0?
    assign next_ctr = load_new_note ? duration_to_load : decremented_ctr;

    dffre #(6) countdown (
        .clk(clk),
        .r(reset),
        // enable the countdown ff if we are loading a note OR if we are playing and a beat occurs
        .en(load_new_note || (play_enable && beat)), 
        .d(next_ctr),
        .q(cur_ctr)
    );
    
    // get instantaneous sampple from sine ROM
    sine_reader read_sin (
        .clk(clk),
        .reset(reset),
        .step_size(note_stepsize), 
        .generate_next(generate_next_sample && play_enable), // to fix note playing indefinitely bug, gate on play_enable too
        .sample_ready(new_sample_ready),
        .sample(sample_out)
    );
    
    // note done when the counter hits zero.
    assign done_with_note = (cur_ctr == 6'b0) && !load_new_note; // changed to give time for duration to get into ff

endmodule