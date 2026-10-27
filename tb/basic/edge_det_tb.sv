`timescale 1ns/1ps

module edge_det_tb;
    logic clk   = 1'b0;
    logic rst_n = 1'b0;
    logic sig   = 1'b0;
    logic rise;
    logic fall;
    logic both;
    int   errors = 0;

    edge_det DUT (
        .clk   (clk),
        .rst_n (rst_n),
        .sig   (sig),
        .rise  (rise),
        .fall  (fall),
        .both  (both)
    );

    always #5 clk = ~clk;

    task automatic check_edge(input logic exp_rise,
                              input logic exp_fall,
                              input logic exp_both,
                              input string msg);
        #1;
        if (rise !== exp_rise || fall !== exp_fall || both !== exp_both) begin
            errors++;
            $display("FAIL %s: rise=%0b fall=%0b both=%0b", msg, rise, fall, both);
        end
    endtask

    initial begin
        #12;
        check_edge(1'b0, 1'b0, 1'b0, "reset no edge");

        rst_n = 1'b1;
        @(negedge clk);
        sig = 1'b1;
        #1;
        check_edge(1'b1, 1'b0, 1'b1, "rising edge");

        @(negedge clk);
        check_edge(1'b0, 1'b0, 1'b0, "stable high");

        sig = 1'b0;
        #1;
        check_edge(1'b0, 1'b1, 1'b1, "falling edge");

        @(negedge clk);
        check_edge(1'b0, 1'b0, 1'b0, "stable low");

        if (errors == 0) $display("edge_det_tb PASS");
        else             $display("edge_det_tb FAIL");
        $finish;
    end
endmodule
