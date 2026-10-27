`timescale 1ns/1ps

module debounce_tb;
    logic clk   = 1'b0;
    logic rst_n = 1'b0;
    logic in    = 1'b0;
    logic out;
    int   errors = 0;

    debounce #(
        .N (3)
    ) DUT (
        .clk   (clk),
        .rst_n (rst_n),
        .in    (in),
        .out   (out)
    );

    always #5 clk = ~clk;

    task automatic check_out(input logic exp, input string msg);
        #1;
        if (out !== exp) begin
            errors++;
            $display("FAIL %s: out=%0b exp=%0b", msg, out, exp);
        end
    endtask

    initial begin
        #12;
        check_out(1'b0, "reset");

        rst_n = 1'b1;
        @(negedge clk);
        in = 1'b1;
        @(negedge clk);
        check_out(1'b0, "stable 1 cycle");
        @(negedge clk);
        check_out(1'b0, "stable 2 cycles");
        @(negedge clk);
        check_out(1'b1, "stable 3 cycles");

        @(negedge clk);
        in = 1'b0;
        @(negedge clk);
        check_out(1'b1, "glitch cycle 1");
        in = 1'b1;
        @(negedge clk);
        check_out(1'b1, "glitch rejected");

        @(negedge clk);
        in = 1'b0;
        @(negedge clk);
        check_out(1'b1, "falling cycle 1");
        @(negedge clk);
        check_out(1'b1, "falling cycle 2");
        @(negedge clk);
        check_out(1'b0, "falling cycle 3");

        @(negedge clk);
        in = 1'b1;
        @(negedge clk);
        check_out(1'b0, "2-cycle glitch cycle 1");
        @(negedge clk);
        check_out(1'b0, "2-cycle glitch cycle 2");
        in = 1'b0;
        @(negedge clk);
        check_out(1'b0, "2-cycle glitch rejected");
        @(negedge clk);
        check_out(1'b0, "hold low");

        @(negedge clk);
        in = 1'b1;
        @(negedge clk);
        check_out(1'b0, "rise stable 1 cycle");
        @(negedge clk);
        check_out(1'b0, "rise stable 2 cycles");
        @(negedge clk);
        check_out(1'b1, "rise stable 3 cycles");

        if (errors == 0) $display("debounce_tb PASS");
        else             $display("debounce_tb FAIL");
        $finish;
    end
endmodule
