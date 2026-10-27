`timescale 1ns/1ps

// binmux 定向 TB：正常选择、N=3 越界选择（无选择）、数据位宽
module binmux_tb;
    localparam int N = 3;
    localparam int W = 8;

    logic [1:0]          sel;
    logic [N-1:0][W-1:0] data;
    logic [W-1:0]        data_out;
    logic                vld;

    logic [2:0]          sel_w;
    logic [7:0][15:0]    data_w;
    logic [15:0]         data_out_w;
    logic                vld_w;

    int                  errors = 0;

    binmux #(
        .N (N),
        .W (W)
    ) DUT (
        .sel      (sel),
        .data     (data),
        .data_out (data_out),
        .vld      (vld)
    );

    binmux #(
        .N (8),
        .W (16)
    ) DUT_WIDE (
        .sel      (sel_w),
        .data     (data_w),
        .data_out (data_out_w),
        .vld      (vld_w)
    );

    task automatic check(input logic [1:0] in_sel,
                         input logic [W-1:0] exp_data,
                         input logic exp_vld,
                         input string msg);
        sel = in_sel;
        #1;
        if (data_out !== exp_data || vld !== exp_vld) begin
            errors++;
            $display("FAIL %s: sel=%0d data=%0h/%0h vld=%0b/%0b",
                     msg, in_sel, data_out, exp_data, vld, exp_vld);
        end
    endtask

    task automatic check_wide(input logic [2:0] in_sel,
                              input logic [15:0] exp_data,
                              input logic exp_vld,
                              input string msg);
        sel_w = in_sel;
        #1;
        if (data_out_w !== exp_data || vld_w !== exp_vld) begin
            errors++;
            $display("FAIL %s: sel=%0d data=%0h/%0h vld=%0b/%0b",
                     msg, in_sel, data_out_w, exp_data, vld_w, exp_vld);
        end
    endtask

    initial begin
        data[0] = 8'h11;
        data[1] = 8'h22;
        data[2] = 8'h33;

        check(2'd0, 8'h11, 1'b1, "select 0");
        check(2'd1, 8'h22, 1'b1, "select 1");
        check(2'd2, 8'h33, 1'b1, "select 2");
        check(2'd3, 8'h00, 1'b0, "N=3 out of range / no select");

        for (int i = 0; i < 8; i++) begin
            data_w[i] = 16'h1000 + i[15:0];
        end

        check_wide(3'd0, 16'h1000, 1'b1, "wide select 0");
        check_wide(3'd7, 16'h1007, 1'b1, "wide select 7");
        check_wide(3'd3, 16'h1003, 1'b1, "wide select 3");

        if (errors == 0) $display("binmux_tb PASS");
        else             $display("binmux_tb FAIL");
        $finish;
    end
endmodule
