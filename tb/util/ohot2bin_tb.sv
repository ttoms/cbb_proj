`timescale 1ns/1ps

module ohot2bin_tb;
    localparam int IN_W = 4;

    logic [IN_W-1:0] ohot;
    logic [1:0]      bin;
    logic            vld;
    int              errors = 0;

    ohot2bin #(
        .IN_W (IN_W)
    ) DUT (
        .ohot (ohot),
        .bin  (bin),
        .vld  (vld)
    );

    task automatic check(input logic [IN_W-1:0] in,
                          input logic [1:0] exp_bin,
                          input logic exp_vld,
                          input string msg);
        ohot = in;
        #1;
        if (bin !== exp_bin || vld !== exp_vld) begin
            errors++;
            $display("FAIL %s: ohot=%0b bin=%0d/%0d vld=%0b/%0b",
                     msg, in, bin, exp_bin, vld, exp_vld);
        end
    endtask

    initial begin
        check(4'b0000, 2'd0, 1'b0, "zero");
        check(4'b0001, 2'd0, 1'b1, "bit 0");
        check(4'b0010, 2'd1, 1'b1, "bit 1");
        check(4'b0100, 2'd2, 1'b1, "bit 2");
        check(4'b1000, 2'd3, 1'b1, "bit 3");
        check(4'b1010, 2'd3, 1'b1, "multi-hot highest");
        check(4'b0101, 2'd2, 1'b1, "multi-hot highest 2");

        if (errors == 0) $display("ohot2bin_tb PASS");
        else             $display("ohot2bin_tb FAIL");
        $finish;
    end
endmodule
