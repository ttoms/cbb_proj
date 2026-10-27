`timescale 1ns/1ps

module dffr_tb;

    localparam int W = 8;

    logic           clk   ;
    logic           rst_n ;
    logic           en    ;
    logic [W -1:0]  d     ;
    logic [W -1:0]  q     ;

    int errors;

    dffr #(
        .W          (W      ),
        .RESET_VAL  (8'h5A  )
    ) U_DUT (
        .clk    (clk    ),
        .rst_n  (rst_n  ),
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
        rst_n  = 1'b0;
        en     = 1'b0;
        d      = '0;
        errors = 0;

        #2;
        check_q(8'h5A, "复位值（异步、无时钟沿）");

        rst_n = 1'b1;
        @(negedge clk);
        en = 1'b1;
        d  = 8'hA5;
        @(posedge clk);
        check_q(8'hA5, "en=1 写入");

        @(negedge clk);
        en = 1'b0;
        d  = 8'h3C;
        @(posedge clk);
        check_q(8'hA5, "en=0 保持");

        @(negedge clk);
        rst_n = 1'b0;
        #1;
        check_q(8'h5A, "异步复位立即生效");

        @(negedge clk);
        rst_n = 1'b1;
        en    = 1'b1;
        d     = 8'hC3;
        @(posedge clk);
        check_q(8'hC3, "复位释放后可再次写入");

        if (errors == 0) begin
            $display("[%m] PASS");
        end else begin
            $display("[%m] FAIL, errors=%0d", errors);
            $fatal(1, "[%m] dffr_tb failed");
        end
        $finish;
    end

endmodule
