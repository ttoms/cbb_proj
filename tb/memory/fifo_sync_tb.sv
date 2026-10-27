`timescale 1ns/1ps

module fifo_sync_tb;
    localparam int DATA_W = 8;
    localparam int DEPTH  = 2;

    logic              clk     = 1'b0;
    logic              rst_n   = 1'b0;
    logic              wr_vld  = 1'b0;
    logic              wr_rdy;
    logic [DATA_W-1:0] wr_data = '0;
    logic              rd_vld;
    logic              rd_rdy  = 1'b0;
    logic [DATA_W-1:0] rd_data;
    logic              full;
    logic              empty;
    logic [1:0]        count;
    int                errors = 0;

    fifo_sync #(
        .DATA_W (DATA_W),
        .DEPTH  (DEPTH)
    ) DUT (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_vld  (wr_vld),
        .wr_rdy  (wr_rdy),
        .wr_data (wr_data),
        .rd_vld  (rd_vld),
        .rd_rdy  (rd_rdy),
        .rd_data (rd_data),
        .full    (full),
        .empty   (empty),
        .count   (count)
    );

    always #5 clk = ~clk;

    task automatic check_count(input logic [1:0] exp, input string msg);
        #1;
        if (count !== exp) begin
            errors++;
            $display("FAIL %s: count=%0d exp=%0d", msg, count, exp);
        end
    endtask

    initial begin
        #12;
        check_count(2'd0, "reset empty");
        if (empty !== 1'b1) begin
            errors++;
            $display("FAIL reset empty flag");
        end

        rst_n = 1'b1;
        @(negedge clk);
        wr_vld  = 1'b1;
        wr_data = 8'hA1;
        @(posedge clk);
        wr_vld = 1'b0;
        check_count(2'd1, "write A1");
        if (rd_vld !== 1'b1 || rd_data !== 8'hA1) begin
            errors++;
            $display("FAIL show-ahead A1: rd_vld=%0b rd_data=%0h", rd_vld, rd_data);
        end

        @(negedge clk);
        rd_rdy = 1'b1;
        @(posedge clk);
        rd_rdy = 1'b0;
        check_count(2'd0, "read A1");

        @(negedge clk);
        wr_vld = 1'b1;
        wr_data = 8'hA2;
        @(negedge clk);
        wr_data = 8'hA3;
        @(negedge clk);
        wr_vld = 1'b0;
        check_count(2'd2, "fill A2 A3");
        if (full !== 1'b1 || wr_rdy !== 1'b0 || rd_data !== 8'hA2) begin
            errors++;
            $display("FAIL full boundary: full=%0b wr_rdy=%0b rd_data=%0h",
                     full, wr_rdy, rd_data);
        end

        @(negedge clk);
        wr_vld  = 1'b1;
        wr_data = 8'hA4;
        @(posedge clk);
        wr_vld = 1'b0;
        check_count(2'd2, "write blocked when full");

        @(negedge clk);
        rd_rdy = 1'b1;
        @(posedge clk);
        rd_rdy = 1'b0;
        check_count(2'd1, "read A2");
        if (rd_data !== 8'hA3) begin
            errors++;
            $display("FAIL after read A2: rd_data=%0h", rd_data);
        end

        @(negedge clk);
        wr_vld  = 1'b1;
        wr_data = 8'hA5;
        rd_rdy  = 1'b1;
        @(posedge clk);
        wr_vld = 1'b0;
        rd_rdy = 1'b0;
        check_count(2'd1, "simultaneous read/write");
        if (rd_data !== 8'hA5) begin
            errors++;
            $display("FAIL simultaneous data: rd_data=%0h", rd_data);
        end

        @(negedge clk);
        rd_rdy = 1'b1;
        @(posedge clk);
        rd_rdy = 1'b0;
        check_count(2'd0, "read A5");
        if (empty !== 1'b1) begin
            errors++;
            $display("FAIL final empty flag");
        end

        if (errors == 0) $display("fifo_sync_tb PASS");
        else             $display("fifo_sync_tb FAIL");
        $finish;
    end
endmodule
