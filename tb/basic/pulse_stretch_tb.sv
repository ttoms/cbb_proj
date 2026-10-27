`timescale 1ns/1ps

module pulse_stretch_tb;
    logic clk       = 1'b0;
    logic rst_n     = 1'b0;
    logic in_pulse  = 1'b0;
    logic out_n2;
    logic out_n1;
    int   errors    = 0;

    pulse_stretch #(
        .N (2)
    ) DUT_N2 (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_pulse  (in_pulse),
        .out_pulse (out_n2)
    );

    pulse_stretch #(
        .N (1)
    ) DUT_N1 (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_pulse  (in_pulse),
        .out_pulse (out_n1)
    );

    always #5 clk = ~clk;

    task automatic check_out(input logic exp_n2, input logic exp_n1,
                             input string msg);
        #1;
        if (out_n2 !== exp_n2 || out_n1 !== exp_n1) begin
            errors++;
            $display("FAIL %s: out_n2=%0b/%0b out_n1=%0b/%0b",
                     msg, out_n2, exp_n2, out_n1, exp_n1);
        end
    endtask

    initial begin
        #12;
        check_out(1'b0, 1'b0, "reset");

        rst_n = 1'b1;
        @(negedge clk);
        in_pulse = 1'b1;
        check_out(1'b1, 1'b1, "input cycle");

        @(negedge clk);
        in_pulse = 1'b0;
        check_out(1'b1, 1'b0, "N=2 extension, N=1 done");

        @(negedge clk);
        check_out(1'b0, 1'b0, "N=2 done");

        @(negedge clk);
        in_pulse = 1'b1;
        @(negedge clk);
        check_out(1'b1, 1'b1, "long input cycle 1");
        @(negedge clk);
        check_out(1'b1, 1'b1, "long input cycle 2");
        in_pulse = 1'b0;
        check_out(1'b1, 1'b0, "long input extension");
        @(negedge clk);
        check_out(1'b0, 1'b0, "long input done");

        if (errors == 0) $display("pulse_stretch_tb PASS");
        else             $display("pulse_stretch_tb FAIL");
        $finish;
    end
endmodule
