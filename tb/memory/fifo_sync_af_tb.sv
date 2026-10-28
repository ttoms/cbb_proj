`timescale 1ns/1ps

module fifo_sync_af_tb;

    localparam  int DATA_W  =   8   ;
    localparam  int DEPTH   =   4   ;
    localparam  int AF      =   3   ;
    localparam  int AE      =   1   ;

    logic               clk             ;
    logic               rst_n           ;
    logic               wr_vld          ;
    logic               wr_rdy          ;
    logic [DATA_W -1:0] wr_data         ;
    logic               rd_vld          ;
    logic               rd_rdy          ;
    logic [DATA_W -1:0] rd_data         ;
    logic               empty           ;
    logic               full            ;
    logic               almost_full     ;
    logic               almost_empty    ;

    logic [DATA_W -1:0] exp_q[$];
    int                 cnt;
    int                 errors;

    fifo_sync_af #(
        .DATA_W     (DATA_W ),
        .DEPTH      (DEPTH  ),
        .AF_THRESH  (AF     ),
        .AE_THRESH  (AE     )
    ) U_DUT (
        .clk            (clk            ),
        .rst_n          (rst_n          ),
        .wr_vld         (wr_vld         ),
        .wr_rdy         (wr_rdy         ),
        .wr_data        (wr_data        ),
        .rd_vld         (rd_vld         ),
        .rd_rdy         (rd_rdy         ),
        .rd_data        (rd_data        ),
        .empty          (empty          ),
        .full           (full           ),
        .almost_full    (almost_full    ),
        .almost_empty   (almost_empty   )
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic err(input string msg);
        errors++;
        $display("[%m] FAIL: %s", msg);
    endtask

    task automatic check_state(input string tag);
        if (empty !== (cnt == 0)) begin
            err($sformatf("%s: empty=%0b, cnt=%0d", tag, empty, cnt));
        end
        if (full !== (cnt == DEPTH)) begin
            err($sformatf("%s: full=%0b, cnt=%0d", tag, full, cnt));
        end
        if (wr_rdy !== (cnt != DEPTH)) begin
            err($sformatf("%s: wr_rdy=%0b, cnt=%0d", tag, wr_rdy, cnt));
        end
        if (rd_vld !== (cnt != 0)) begin
            err($sformatf("%s: rd_vld=%0b, cnt=%0d", tag, rd_vld, cnt));
        end
        if (almost_full !== (cnt >= AF)) begin
            err($sformatf("%s: almost_full=%0b, cnt=%0d", tag, almost_full, cnt));
        end
        if (almost_empty !== (cnt <= AE)) begin
            err($sformatf("%s: almost_empty=%0b, cnt=%0d", tag, almost_empty, cnt));
        end
        if (rd_vld && (rd_data !== exp_q[0])) begin
            err($sformatf("%s: rd_data=%0h, exp=%0h", tag, rd_data, exp_q[0]));
        end
    endtask

    task automatic cycle(
        input logic              we,
        input logic [DATA_W-1:0] wd,
        input logic              rr
    );
        logic wr_fire_t;
        logic rd_fire_t;
        int   nxt_cnt;

        @(negedge clk);
        wr_vld  = we;
        wr_data = wd;
        rd_rdy  = rr;

        #1;
        check_state("pre");

        wr_fire_t = wr_vld && wr_rdy;
        rd_fire_t = rd_vld && rd_rdy;
        nxt_cnt   = cnt + (wr_fire_t ? 1 : 0) - (rd_fire_t ? 1 : 0);

        @(posedge clk);
        cnt = nxt_cnt;
        if (rd_fire_t) exp_q.delete(0);
        if (wr_fire_t) exp_q.push_back(wd);

        #1;
        check_state("post");
    endtask

    initial begin
        rst_n   = 1'b0;
        wr_vld  = 1'b0;
        wr_data = '0;
        rd_rdy  = 1'b0;
        cnt     = 0;
        errors  = 0;
        exp_q.delete();

        #2;
        if (empty !== 1'b1)        err("复位后 empty 应为 1");
        if (full !== 1'b0)         err("复位后 full 应为 0");
        if (almost_full !== 1'b0)  err("复位后 almost_full 应为 0");
        if (almost_empty !== 1'b1) err("复位后 almost_empty 应为 1");

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        cycle(1'b0, 8'h00, 1'b0);
        cycle(1'b1, 8'hA1, 1'b0);
        cycle(1'b1, 8'hA2, 1'b0);
        cycle(1'b1, 8'hA3, 1'b0);
        cycle(1'b1, 8'hA4, 1'b0);
        cycle(1'b1, 8'hA5, 1'b0);
        cycle(1'b0, 8'h00, 1'b1);
        cycle(1'b1, 8'hA6, 1'b1);
        cycle(1'b0, 8'h00, 1'b1);
        cycle(1'b0, 8'h00, 1'b1);
        cycle(1'b0, 8'h00, 1'b1);
        cycle(1'b0, 8'h00, 1'b1);
        cycle(1'b1, 8'hB1, 1'b0);

        if (errors == 0) begin
            $display("[%m] PASS");
        end else begin
            $display("[%m] FAIL: %0d errors", errors);
        end
        $finish;
    end

endmodule
