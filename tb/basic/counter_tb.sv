`timescale 1ns/1ps

module counter_tb;
    localparam int W = 4;

    logic         clk      = 1'b0;
    logic         rst_n    = 1'b0;
    logic         en       = 1'b0;
    logic         load     = 1'b0;
    logic         up       = 1'b1;
    logic [W-1:0] load_val = '0;
    logic [W-1:0] count_wrap;
    logic [W-1:0] count_sat;
    int           errors   = 0;

    counter #(
        .W        (W),
        .SATURATE (1'b0)
    ) DUT_WRAP (
        .clk      (clk),
        .rst_n    (rst_n),
        .en       (en),
        .load     (load),
        .up       (up),
        .load_val (load_val),
        .count    (count_wrap)
    );

    counter #(
        .W        (W),
        .SATURATE (1'b1)
    ) DUT_SAT (
        .clk      (clk),
        .rst_n    (rst_n),
        .en       (en),
        .load     (load),
        .up       (up),
        .load_val (load_val),
        .count    (count_sat)
    );

    always #5 clk = ~clk;

    task automatic check_count(input logic [W-1:0] exp_wrap,
                               input logic [W-1:0] exp_sat,
                               input string msg);
        #1;
        if (count_wrap !== exp_wrap || count_sat !== exp_sat) begin
            errors++;
            $display("FAIL %s: wrap=%0h/%0h sat=%0h/%0h",
                     msg, count_wrap, exp_wrap, count_sat, exp_sat);
        end
    endtask

    initial begin
        #12;
        check_count(4'h0, 4'h0, "reset");

        rst_n = 1'b1;
        @(negedge clk);
        load     = 1'b1;
        load_val = 4'hE;
        @(negedge clk);
        load = 1'b0;
        check_count(4'hE, 4'hE, "load E");

        en = 1'b1;
        up = 1'b1;
        @(negedge clk);
        check_count(4'hF, 4'hF, "up to F");
        @(negedge clk);
        check_count(4'h0, 4'hF, "wrap/saturate at F");

        @(negedge clk);
        load     = 1'b1;
        load_val = 4'h1;
        @(negedge clk);
        load = 1'b0;
        check_count(4'h1, 4'h1, "load 1");

        up = 1'b0;
        @(negedge clk);
        check_count(4'h0, 4'h0, "down to 0");
        @(negedge clk);
        en = 1'b0;
        up = 1'b1;
        #1;
        check_count(4'hF, 4'h0, "wrap to F and hold");

        @(negedge clk);
        check_count(4'hF, 4'h0, "hold next cycle");

        @(negedge clk);
        load     = 1'b1;
        load_val = 4'h5;
        @(negedge clk);
        load = 1'b0;
        check_count(4'h5, 4'h5, "load priority");

        if (errors == 0) $display("counter_tb PASS");
        else             $display("counter_tb FAIL");
        $finish;
    end
endmodule
