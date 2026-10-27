`timescale 1ns/1ps

// ohot_pri_enc 定向 TB：全零、单请求、多请求取最低索引、位宽边界
module ohot_pri_enc_tb;
    localparam int IN_W  = 4;
    localparam int IDX_W = 2;

    logic [IN_W-1:0]  req;
    logic [IDX_W-1:0] idx;
    logic             vld;

    logic             req_1;
    logic [0:0]       idx_1;
    logic             vld_1;

    logic [7:0]       req_8;
    logic [2:0]       idx_8;
    logic             vld_8;

    int               errors = 0;

    ohot_pri_enc #(
        .IN_W (IN_W)
    ) DUT (
        .req (req),
        .idx (idx),
        .vld (vld)
    );

    ohot_pri_enc #(
        .IN_W (1)
    ) DUT_NARROW (
        .req (req_1),
        .idx (idx_1),
        .vld (vld_1)
    );

    ohot_pri_enc #(
        .IN_W (8)
    ) DUT_WIDE (
        .req (req_8),
        .idx (idx_8),
        .vld (vld_8)
    );

    task automatic check(input logic [IN_W-1:0] in,
                         input logic [IDX_W-1:0] exp_idx,
                         input logic exp_vld,
                         input string msg);
        req = in;
        #1;
        if (idx !== exp_idx || vld !== exp_vld) begin
            errors++;
            $display("FAIL %s: req=%0b idx=%0d/%0d vld=%0b/%0b",
                     msg, in, idx, exp_idx, vld, exp_vld);
        end
    endtask

    task automatic check_narrow(input logic in,
                                input logic exp_idx,
                                input logic exp_vld,
                                input string msg);
        req_1 = in;
        #1;
        if (idx_1 !== exp_idx || vld_1 !== exp_vld) begin
            errors++;
            $display("FAIL %s: req=%0b idx=%0d/%0d vld=%0b/%0b",
                     msg, in, idx_1, exp_idx, vld_1, exp_vld);
        end
    endtask

    task automatic check_wide(input logic [7:0] in,
                              input logic [2:0] exp_idx,
                              input logic exp_vld,
                              input string msg);
        req_8 = in;
        #1;
        if (idx_8 !== exp_idx || vld_8 !== exp_vld) begin
            errors++;
            $display("FAIL %s: req=%0b idx=%0d/%0d vld=%0b/%0b",
                     msg, in, idx_8, exp_idx, vld_8, exp_vld);
        end
    endtask

    initial begin
        check(4'b0000, 2'd0, 1'b0, "zero");
        check(4'b0001, 2'd0, 1'b1, "bit 0");
        check(4'b0010, 2'd1, 1'b1, "bit 1");
        check(4'b0100, 2'd2, 1'b1, "bit 2");
        check(4'b1000, 2'd3, 1'b1, "bit 3");
        check(4'b1010, 2'd1, 1'b1, "multi-hot lowest 1/3");
        check(4'b0101, 2'd0, 1'b1, "multi-hot lowest 0/2");
        check(4'b1110, 2'd1, 1'b1, "multi-hot lowest 1/3");
        check(4'b1111, 2'd0, 1'b1, "multi-hot all");

        check_narrow(1'b0, 1'b0, 1'b0, "narrow zero");
        check_narrow(1'b1, 1'b0, 1'b1, "narrow bit 0");

        check_wide(8'h00, 3'd0, 1'b0, "wide zero");
        check_wide(8'h01, 3'd0, 1'b1, "wide bit 0");
        check_wide(8'h80, 3'd7, 1'b1, "wide bit 7");
        check_wide(8'hA0, 3'd5, 1'b1, "wide multi-hot lowest 5/7");
        check_wide(8'h54, 3'd2, 1'b1, "wide multi-hot lowest 2/4/6");
        check_wide(8'hFE, 3'd1, 1'b1, "wide multi-hot lowest 1/7");

        if (errors == 0) $display("ohot_pri_enc_tb PASS");
        else             $display("ohot_pri_enc_tb FAIL");
        $finish;
    end
endmodule
