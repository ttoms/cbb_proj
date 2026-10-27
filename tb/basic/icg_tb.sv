`timescale 1ns/1ps

module icg_tb;
    logic clk   = 1'b0;
    logic en    = 1'b0;
    logic gclk;
    int   errors = 0;

    icg DUT (
        .clk  (clk),
        .en   (en),
        .gclk (gclk)
    );

    always #5 clk = ~clk;

    task automatic check_gclk(input logic exp, input string msg);
        #1;
        if (gclk !== exp) begin
            errors++;
            $display("FAIL %s: gclk=%0b exp=%0b", msg, gclk, exp);
        end
    endtask

    initial begin
        #1;
        check_gclk(1'b0, "reset low");

        en = 1'b1;
        check_gclk(1'b0, "enable captured while low");
        @(posedge clk);
        check_gclk(1'b1, "gated clock high");

        en = 1'b0;
        check_gclk(1'b1, "disable ignored while high");
        @(negedge clk);
        check_gclk(1'b0, "disable captured while low");
        @(posedge clk);
        check_gclk(1'b0, "en=0 keeps gclk low on rising edge");
        @(negedge clk);
        check_gclk(1'b0, "en=0 keeps gclk low on falling edge");

        en = 1'b1;
        check_gclk(1'b0, "re-enable while low no glitch");
        @(posedge clk);
        check_gclk(1'b1, "re-enable follows clk high");
        @(negedge clk);
        check_gclk(1'b0, "clock low");

        en = 1'b0;
        @(posedge clk);
        check_gclk(1'b0, "disable while low keeps next high gated");

        if (errors == 0) $display("icg_tb PASS");
        else             $display("icg_tb FAIL");
        $finish;
    end
endmodule
