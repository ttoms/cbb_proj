`timescale 1ns/1ps

module dff_tb;

    localparam int W = 8;

    logic           clk ;
    logic           en  ;
    logic [W -1:0]  d   ;
    logic [W -1:0]  q   ;

    int errors;

    dff #(
        .W  (W )
    ) U_DUT (
        .clk    (clk    ),
        .en     (en     ),
        .d      (d      ),
        .q      (q      )
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_q(input logic [W-1:0] exp, input string msg);
        #1;
        if (q !== exp) begin
            errors++;
            $display("[%m] FAIL: %s, q=%0h exp=%0h", msg, q, exp);
        end
    endtask

    initial begin
        en     = 1'b0;
        d      = '0;
        errors = 0;

        @(negedge clk);
        en = 1'b1;
        d  = 8'hA5;
        @(posedge clk);
        check_q(8'hA5, "en=1 首次写入");

        @(negedge clk);
        en = 1'b0;
        d  = 8'h5A;
        @(posedge clk);
        check_q(8'hA5, "en=0 保持");

        repeat (2) @(posedge clk);
        check_q(8'hA5, "en=0 连续保持");

        @(negedge clk);
        en = 1'b1;
        d  = 8'h3C;
        @(posedge clk);
        check_q(8'h3C, "en=1 再次更新");

        if (errors == 0) begin
            $display("[%m] PASS");
        end else begin
            $display("[%m] FAIL, errors=%0d", errors);
            $fatal(1, "[%m] dff_tb failed");
        end
        $finish;
    end

endmodule
