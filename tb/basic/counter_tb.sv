`timescale 1ns/1ps

module counter_tb;
    localparam int W = 8;

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
        check_count(8'h00, 8'h00, "reset");

        rst_n = 1'b1;
        @(negedge clk);
        load     = 1'b1;
        load_val = 8'hA5;
        en       = 1'b1;
        up       = 1'b1;
        @(negedge clk);
        load = 1'b0;
        check_count(8'hA5, 8'hA5, "load A5");

        load     = 1'b1;
        load_val = 8'h3C;
        @(negedge clk);
        load = 1'b0;
        check_count(8'h3C, 8'h3C, "load priority over en");

        en = 1'b0;
        @(negedge clk);
        check_count(8'h3C, 8'h3C, "en=0 hold");

        en = 1'b1;
        up = 1'b1;
        @(negedge clk);
        check_count(8'h3D, 8'h3D, "up count");

        load     = 1'b1;
        load_val = 8'hFF;
        @(negedge clk);
        load = 1'b0;
        check_count(8'hFF, 8'hFF, "load FF");

        @(negedge clk);
        check_count(8'h00, 8'hFF, "max wrap/saturate");

        load     = 1'b1;
        load_val = 8'h00;
        @(negedge clk);
        load = 1'b0;
        check_count(8'h00, 8'h00, "load 0");

        up = 1'b0;
        @(negedge clk);
        check_count(8'hFF, 8'h00, "min wrap/saturate");

        load     = 1'b1;
        load_val = 8'h02;
        @(negedge clk);
        load = 1'b0;
        check_count(8'h02, 8'h02, "load 2");

        @(negedge clk);
        check_count(8'h01, 8'h01, "down count");

        en = 1'b0;
        @(negedge clk);
        check_count(8'h01, 8'h01, "en=0 hold low");
        @(negedge clk);
        check_count(8'h01, 8'h01, "en=0 hold again");

        if (errors == 0) $display("counter_tb PASS");
        else             $display("counter_tb FAIL");
        $finish;
    end
endmodule
