`timescale 1ns/1ps

module dff_tb;
    localparam int W = 8;

    logic         clk = 1'b0;
    logic         en  = 1'b0;
    logic [W-1:0] d   = '0;
    logic [W-1:0] q;
    int           errors = 0;

    dff #(
        .W (W)
    ) DUT (
        .clk (clk),
        .en  (en),
        .d   (d),
        .q   (q)
    );

    always #5 clk = ~clk;

    task automatic check_q(input logic [W-1:0] exp, input string msg);
        #1;
        if (q !== exp) begin
            errors++;
            $display("FAIL %s: q=%0h exp=%0h", msg, q, exp);
        end
    endtask

    initial begin
        @(negedge clk);
        en = 1'b1;
        d  = 8'hA5;
        @(posedge clk);
        check_q(8'hA5, "write A5");

        @(negedge clk);
        en = 1'b0;
        d  = 8'h5A;
        @(posedge clk);
        check_q(8'hA5, "hold when en=0");

        @(negedge clk);
        en = 1'b1;
        d  = 8'h3C;
        @(posedge clk);
        check_q(8'h3C, "write 3C");

        if (errors == 0) $display("dff_tb PASS");
        else             $display("dff_tb FAIL");
        $finish;
    end
endmodule
