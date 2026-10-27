`timescale 1ns/1ps

module busmux_tb;
    localparam int N = 4;
    localparam int W = 8;

    logic [N-1:0]       sel;
    logic [N-1:0][W-1:0] data;
    logic [W-1:0]       data_out;
    logic               vld;
    int                 errors = 0;

    busmux #(
        .N (N),
        .W (W)
    ) DUT (
        .sel      (sel),
        .data     (data),
        .data_out (data_out),
        .vld      (vld)
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
        check(4'b0011, 8'h00, 1'b0, "multi-hot rejected");

        if (errors == 0) $display("busmux_tb PASS");
        else             $display("busmux_tb FAIL");
        $finish;
    end
endmodule
