`timescale 1ns/1ps

module dffr_tb;
    localparam int W = 8;

    logic         clk   = 1'b0;
    logic         rst_n = 1'b0;
    logic         en    = 1'b0;
    logic [W-1:0] d     = '0;
    logic [W-1:0] q;
    int           errors = 0;

    dffr #(
        .W           (W),
        .RESET_VALUE (8'h00)
    ) DUT (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (en),
        .d     (d),
        .q     (q)
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
        #12;
        check_q(8'h00, "async reset");

        rst_n = 1'b1;
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

        rst_n = 1'b0;
        #1;
        check_q(8'h00, "async re-assert");

        if (errors == 0) $display("dffr_tb PASS");
        else             $display("dffr_tb FAIL");
        $finish;
    end
endmodule
