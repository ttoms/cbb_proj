`timescale 1ns/1ps

module rst_sync_tb;
    logic clk        = 1'b0;
    logic rst_n      = 1'b0;
    logic rst_sync_n;
    int   errors     = 0;

    rst_sync #(
        .STAGES (2)
    ) DUT (
        .clk        (clk),
        .rst_n      (rst_n),
        .rst_sync_n (rst_sync_n)
    );

    always #5 clk = ~clk;

    task automatic check_out(input logic exp, input string msg);
        #1;
        if (rst_sync_n !== exp) begin
            errors++;
            $display("FAIL %s: rst_sync_n=%0b exp=%0b", msg, rst_sync_n, exp);
        end
    endtask

    initial begin
        #12;
        check_out(1'b0, "async assert");

        rst_n = 1'b1;
        @(posedge clk);
        check_out(1'b0, "first release stage");
        @(posedge clk);
        check_out(1'b1, "release after 2 stages");

        rst_n = 1'b0;
        check_out(1'b0, "async re-assert");

        if (errors == 0) $display("rst_sync_tb PASS");
        else             $display("rst_sync_tb FAIL");
        $finish;
    end
endmodule
