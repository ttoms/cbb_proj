`timescale 1ns/1ps

module rst_sync_tb;

    localparam int STAGES = 2;

    logic   clk         ;
    logic   rst_async_n ;
    logic   rst_n       ;

    int errors;

    rst_sync #(
        .STAGES (STAGES )
    ) U_DUT (
        .clk            (clk            ),
        .rst_async_n    (rst_async_n    ),
        .rst_n          (rst_n          )
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_out(input logic exp, input string msg);
        #1;
        if (rst_n !== exp) begin
            errors++;
            $display("[%m] FAIL: %s, rst_n=%0b exp=%0b", msg, rst_n, exp);
        end
    endtask

    initial begin
        rst_async_n = 1'b0;
        errors      = 0;

        #2;
        check_out(1'b0, "异步拉低立即生效");

        @(negedge clk);
        rst_async_n = 1'b1;

        @(posedge clk);
        check_out(1'b0, "释放后第 1 拍仍为低");

        @(posedge clk);
        check_out(1'b1, "释放后第 2 拍同步拉高");

        @(negedge clk);
        rst_async_n = 1'b0;
        #1;
        if (rst_n !== 1'b0) begin
            errors++;
            $display("[%m] FAIL: 运行中异步复位未立即生效, rst_n=%0b", rst_n);
        end

        @(negedge clk);
        rst_async_n = 1'b1;

        @(posedge clk);
        check_out(1'b0, "再次释放后第 1 拍仍为低");

        @(posedge clk);
        check_out(1'b1, "再次释放后第 2 拍拉高");

        if (errors == 0) begin
            $display("[%m] PASS");
        end else begin
            $display("[%m] FAIL, errors=%0d", errors);
            $fatal(1, "[%m] rst_sync_tb failed");
        end
        $finish;
    end

endmodule
