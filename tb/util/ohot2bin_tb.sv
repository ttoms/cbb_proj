`timescale 1ns/1ps

// ohot2bin 定向 TB：单热、全零、多热取最高索引、位宽边界
module ohot2bin_tb;
    localparam int IN_W  = 4;
    localparam int OUT_W = 2;

    logic [IN_W-1:0]  ohot;
    logic [OUT_W-1:0] bin;
    logic             vld;

    logic             ohot_1;
    logic [0:0]       bin_1;
    logic             vld_1;

    logic [7:0]       ohot_8;
    logic [2:0]       bin_8;
    logic             vld_8;

    logic [4:0]       ohot_5;
    logic [2:0]       bin_5;
    logic             vld_5;

    int               errors = 0;

    ohot2bin #(
        .IN_W (IN_W)
    ) DUT (
        .ohot (ohot),
        .bin  (bin),
        .vld  (vld)
    );

    ohot2bin #(
        .IN_W (1)
    ) DUT_NARROW (
        .ohot (ohot_1),
        .bin  (bin_1),
        .vld  (vld_1)
    );

    ohot2bin #(
        .IN_W (8)
    ) DUT_WIDE (
        .ohot (ohot_8),
        .bin  (bin_8),
        .vld  (vld_8)
    );

    // 非 2 的幂的输入宽度
    ohot2bin #(
        .IN_W (5)
    ) DUT_ODD (
        .ohot (ohot_5),
        .bin  (bin_5),
        .vld  (vld_5)
    );

    task automatic check(input logic [IN_W-1:0] in,
                         input logic [OUT_W-1:0] exp_bin,
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

    task automatic check_narrow(input logic in,
                                input logic exp_bin,
                                input logic exp_vld,
                                input string msg);
        ohot_1 = in;
        #1;
        if (bin_1 !== exp_bin || vld_1 !== exp_vld) begin
            errors++;
            $display("FAIL %s: ohot=%0b bin=%0d/%0d vld=%0b/%0b",
                     msg, in, bin_1, exp_bin, vld_1, exp_vld);
        end
    endtask

    task automatic check_wide(input logic [7:0] in,
                              input logic [2:0] exp_bin,
                              input logic exp_vld,
                              input string msg);
        ohot_8 = in;
        #1;
        if (bin_8 !== exp_bin || vld_8 !== exp_vld) begin
            errors++;
            $display("FAIL %s: ohot=%0b bin=%0d/%0d vld=%0b/%0b",
                     msg, in, bin_8, exp_bin, vld_8, exp_vld);
        end
    endtask

    task automatic check_odd(input logic [4:0] in,
                             input logic [2:0] exp_bin,
                             input logic exp_vld,
                             input string msg);
        ohot_5 = in;
        #1;
        if (bin_5 !== exp_bin || vld_5 !== exp_vld) begin
            errors++;
            $display("FAIL %s: ohot=%0b bin=%0d/%0d vld=%0b/%0b",
                     msg, in, bin_5, exp_bin, vld_5, exp_vld);
        end
    endtask

    initial begin
        check(4'b0000, 2'd0, 1'b0, "zero");
        check(4'b0001, 2'd0, 1'b1, "bit 0");
        check(4'b0010, 2'd1, 1'b1, "bit 1");
        check(4'b0100, 2'd2, 1'b1, "bit 2");
        check(4'b1000, 2'd3, 1'b1, "bit 3");
        check(4'b1010, 2'd3, 1'b1, "multi-hot highest 3/1");
        check(4'b0101, 2'd2, 1'b1, "multi-hot highest 2/0");
        check(4'b1111, 2'd3, 1'b1, "multi-hot all");

        check_narrow(1'b0, 1'b0, 1'b0, "narrow zero");
        check_narrow(1'b1, 1'b0, 1'b1, "narrow bit 0");

        check_wide(8'h00, 3'd0, 1'b0, "wide zero");
        check_wide(8'h01, 3'd0, 1'b1, "wide bit 0");
        check_wide(8'h80, 3'd7, 1'b1, "wide bit 7");
        check_wide(8'hA0, 3'd7, 1'b1, "wide multi-hot highest");
        check_wide(8'h55, 3'd6, 1'b1, "wide multi-hot even bits");

        check_odd(5'b00000, 3'd0, 1'b0, "odd zero");
        check_odd(5'b00001, 3'd0, 1'b1, "odd bit 0");
        check_odd(5'b10000, 3'd4, 1'b1, "odd bit 4");
        check_odd(5'b10100, 3'd4, 1'b1, "odd multi-hot 4/2");
        check_odd(5'b01110, 3'd3, 1'b1, "odd multi-hot 3/2/1");

        if (errors == 0) $display("ohot2bin_tb PASS");
        else             $display("ohot2bin_tb FAIL");
        $finish;
    end
endmodule
