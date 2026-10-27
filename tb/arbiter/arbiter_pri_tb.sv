`timescale 1ns/1ps

// arbiter_pri 定向 TB：无请求、单请求、全请求、索引优先级
module arbiter_pri_tb;
    localparam int N = 4;

    logic [N-1:0] req;
    logic [N-1:0] gnt;
    logic         gnt_vld;
    int           errors = 0;

    arbiter_pri #(
        .N (N)
    ) DUT (
        .req     (req),
        .gnt     (gnt),
        .gnt_vld (gnt_vld)
    );

    task automatic check(input logic [N-1:0] in_req,
                         input logic [N-1:0] exp_gnt,
                         input logic exp_vld,
                         input string msg);
        req = in_req;
        #1;
        if (gnt !== exp_gnt || gnt_vld !== exp_vld) begin
            errors++;
            $display("FAIL %s: req=%0b gnt=%0b/%0b vld=%0b/%0b",
                     msg, in_req, gnt, exp_gnt, gnt_vld, exp_vld);
        end
    endtask

    initial begin
        check(4'b0000, 4'b0000, 1'b0, "no request");
        check(4'b0001, 4'b0001, 1'b1, "index 0");
        check(4'b0010, 4'b0010, 1'b1, "index 1");
        check(4'b0100, 4'b0100, 1'b1, "index 2");
        check(4'b1000, 4'b1000, 1'b1, "index 3");
        check(4'b1100, 4'b0100, 1'b1, "index 2 over 3");
        check(4'b1010, 4'b0010, 1'b1, "index 1 over 3");
        check(4'b0110, 4'b0010, 1'b1, "index 1 over 2");
        check(4'b1111, 4'b0001, 1'b1, "all request");

        if (errors == 0) $display("arbiter_pri_tb PASS");
        else             $display("arbiter_pri_tb FAIL");
        $finish;
    end
endmodule
