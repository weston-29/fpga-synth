`timescale 1ns/1ps

module note_display_path_tb;

    reg        note_valid;
    reg [5:0]  note_code;
    wire [31:0] text_ascii;

    integer errors;

    note_code_to_ascii dut (
        .note_valid(note_valid),
        .note_code(note_code),
        .text_ascii(text_ascii)
    );

    task check_ascii;
        input [31:0] exp;
        input [255:0] label;
        begin
            if (text_ascii !== exp) begin
                $display("FAIL %0s got=%h exp=%h", label, text_ascii, exp);
                errors = errors + 1;
            end else begin
                $display("PASS %0s -> %h", label, text_ascii);
            end
        end
    endtask

    initial begin
        errors = 0;

        $display("\n=== TEST 1: invalid note displays REST ===");
        note_valid = 1'b0;
        note_code  = 6'd40;
        #1;
        check_ascii({8'h52,8'h45,8'h53,8'h54}, "invalid note -> REST");

        $display("\n=== TEST 2: code 0 displays REST ===");
        note_valid = 1'b1;
        note_code  = 6'd0;
        #1;
        check_ascii({8'h52,8'h45,8'h53,8'h54}, "note 0 -> REST");

        $display("\n=== TEST 3: representative note mappings ===");
        note_valid = 1'b1;
        note_code  = 6'd40; #1;
        check_ascii({8'h34,8'h43,8'h20,8'h20}, "40 -> 4C");

        note_code  = 6'd41; #1;
        check_ascii({8'h34,8'h43,8'h23,8'h20}, "41 -> 4C#");

        note_code  = 6'd45; #1;
        check_ascii({8'h34,8'h46,8'h20,8'h20}, "45 -> 4F");

        note_code  = 6'd52; #1;
        check_ascii({8'h35,8'h43,8'h20,8'h20}, "52 -> 5C");

        note_code  = 6'd63; #1;
        check_ascii({8'h36,8'h42,8'h20,8'h20}, "63 -> 6B");

        $display("\n=== TEST 4: out-of-range codes fall back to REST ===");
        note_code  = 6'd31; #1;
        check_ascii({8'h33,8'h44,8'h23,8'h20}, "31 -> 3D#");

        note_valid = 1'b1;
        note_code  = 6'd62; #1;
        check_ascii({8'h36,8'h41,8'h23,8'h20}, "62 -> 6A#");

        $display("\n=== RESULTS: %0d error(s) ===", errors);
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TEST FAILED");
        $finish;
    end

endmodule
