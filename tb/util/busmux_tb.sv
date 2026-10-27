`timescale 1ns/1ps

// busmux 定向 TB：单热、无选择、多热视为无选择、数据位宽
module busmux_tb;
    localparam int N = 4;
    localparam int W = 8;

    logic [N-1:0]        sel;
    logic [N-1:0][W-1:0] data;
    logic [W-1:0]        data_out;
    logic                vld;

    logic [1:0]          sel_w;
    logic [1:0][31:0]    data_w;
    logic [31:0]         data_out_w;
    logic                vld_w;

    int                  errors = 0;

    busmux #(
        .N (N),
        .W (W)
    ) DUT (
        .sel      (sel),
        .data     (data),
        .data_out (data_out),
        .vld      (vld)
    );

    busmux #(
        .N (2),
        .W (32)
    ) DUT_WIDE (
        .sel      (sel_w),
        .data     (data_w),
        .data_out (data_out_w),
        .vld      (vld_w)
    );

    task automatic check(input logic [N-1:0] in_sel,
                         input logic [W-1:0] exp_data,
                         input logic exp_vld,
                         input string msg);
        sel = in_sel;
        #1;
        if (data_out !== exp_data || vld !== exp_vld) begin
            errors++;
            $display("FAIL %s: sel=%0b data=%0h/%0h vld=%0b/%0b",
                     msg, in_sel, data_out, exp_data, vld, exp_vld);
        end
    endtask

    task automatic check_wide(input logic [1:0] in_sel,
                              input logic [31:0] exp_data,
                              input logic exp_vld,
                              input string msg);
        sel_w = in_sel;
        #1;
        if (data_out_w !== exp_data || vld_w !== exp_vld) begin
            errors++;
            $display("FAIL %s: sel=%0b data=%0h/%0h vld=%0b/%0b",
                     msg, in_sel, data_out_w, exp_data, vld_w, exp_vld);
        end
    endtask

    initial begin
        data[0] = 8'h11;
        data[1] = 8'h22;
        data[2] = 8'h33;
        data[3] = 8'h44;

        check(4'b0001, 8'h11, 1'b1, "select 0");
        check(4'b0010, 8'h22, 1'b1, "select 1");
        check(4'b0100, 8'h33, 1'b1, "select 2");
        check(4'b1000, 8'h44, 1'b1, "select 3");
        check(4'b0000, 8'h00, 1'b0, "no select");
        check(4'b0011, 8'h00, 1'b0, "multi-hot select 1/0");
        check(4'b1111, 8'h00, 1'b0, "multi-hot all");

        data_w[0] = 32'hDEAD_BEEF;
        data_w[1] = 32'h0123_4567;

        check_wide(2'b01, 32'hDEAD_BEEF, 1'b1, "wide select 0");
        check_wide(2'b10, 32'h0123_4567, 1'b1, "wide select 1");
        check_wide(2'b00, 32'h0000_0000, 1'b0, "wide no select");
        check_wide(2'b11, 32'h0000_0000, 1'b0, "wide multi-hot");

        if (errors == 0) $display("busmux_tb PASS");
        else             $display("busmux_tb FAIL");
        $finish;
    end
endmodule
