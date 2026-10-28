`timescale 1ns/1ps

module width_conv_up_tb;

    localparam int IN_W  = 8;
    localparam int OUT_W = 32;
    localparam int RATIO = OUT_W / IN_W;

    logic               clk         ;
    logic               rst_n       ;
    logic               in_vld      ;
    logic               in_rdy      ;
    logic [IN_W  -1:0]  in_data     ;
    logic               in_keep     ;
    logic               in_last     ;
    logic               out_vld     ;
    logic               out_rdy     ;
    logic [OUT_W -1:0]  out_data    ;
    logic [RATIO -1:0]  out_keep    ;
    logic               out_last    ;

    logic [IN_W-1:0] beat_data_q[$];
    logic            beat_last_q[$];

    int              acc_cnt;
    logic [OUT_W-1:0] acc_model;
    int              errors;

    width_conv #(
        .IN_W   (IN_W   ),
        .OUT_W  (OUT_W  )
    ) U_DUT (
        .clk        (clk        ),
        .rst_n      (rst_n      ),
        .in_vld     (in_vld     ),
        .in_rdy     (in_rdy     ),
        .in_data    (in_data    ),
        .in_keep    (in_keep    ),
        .in_last    (in_last    ),
        .out_vld    (out_vld    ),
        .out_rdy    (out_rdy    ),
        .out_data   (out_data   ),
        .out_keep   (out_keep   ),
        .out_last   (out_last   )
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic err(input string msg);
        errors++;
        $display("[%m] FAIL: %s", msg);
    endtask

    task automatic push_pkt(input int len, input logic [IN_W-1:0] base);
        for (int i = 0; i < len; i++) begin
            beat_data_q.push_back(base + i[IN_W-1:0]);
            beat_last_q.push_back(i == (len - 1));
        end
    endtask

    task automatic check_out;
        logic [OUT_W-1:0] exp_word;
        logic [RATIO-1:0] exp_keep;
        int               lane;

        if (out_vld !== (in_vld && ((acc_cnt == RATIO - 1) || in_last))) begin
            err($sformatf("out_vld=%0b, in_vld=%0b, acc_cnt=%0d, in_last=%0b",
                          out_vld, in_vld, acc_cnt, in_last));
        end

        if (out_vld) begin
            exp_word = acc_model;
            exp_word[acc_cnt*IN_W +: IN_W] = in_data;
            exp_keep = (RATIO'(1) << (acc_cnt + 1)) - RATIO'(1);

            if (out_keep !== exp_keep) begin
                err($sformatf("out_keep=%0b, exp=%0b, acc_cnt=%0d",
                              out_keep, exp_keep, acc_cnt));
            end
            if (out_last !== in_last) begin
                err($sformatf("out_last=%0b, exp=%0b", out_last, in_last));
            end

            for (lane = 0; lane < RATIO; lane++) begin
                if (exp_keep[lane] &&
                    (out_data[lane*IN_W +: IN_W] !== exp_word[lane*IN_W +: IN_W])) begin
                    err($sformatf("lane %0d: out=%0h, exp=%0h",
                                  lane, out_data[lane*IN_W +: IN_W],
                                  exp_word[lane*IN_W +: IN_W]));
                end
            end
        end
    endtask

    initial begin
        logic in_fire_t;
        logic out_fire_t;
        logic completing_t;

        rst_n    = 1'b0;
        in_vld   = 1'b0;
        in_data  = '0;
        in_keep  = 1'b1;
        in_last  = 1'b0;
        out_rdy  = 1'b0;
        acc_cnt  = 0;
        acc_model = '0;
        errors   = 0;

        push_pkt(1, 8'hA0)  ;
        push_pkt(4, 8'hB0)  ;
        push_pkt(5, 8'hC0)  ;
        push_pkt(3, 8'hD0)  ;
        push_pkt(8, 8'hE0)  ;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        for (int cyc = 0; cyc < 300; cyc++) begin
            @(negedge clk);

            in_vld = (beat_data_q.size() > 0);
            if (in_vld) begin
                in_data = beat_data_q[0];
                in_last = beat_last_q[0];
            end else begin
                in_data = '0;
                in_last = 1'b0;
            end

            if (beat_data_q.size() > 0) begin
                out_rdy = ($urandom_range(0, 3) != 0);
            end else begin
                out_rdy = 1'b1;
            end

            #1;
            check_out();

            if (in_rdy !== (((acc_cnt == RATIO - 1) || in_last) ? out_rdy : 1'b1)) begin
                err($sformatf("in_rdy=%0b, out_rdy=%0b, acc_cnt=%0d, in_last=%0b",
                              in_rdy, out_rdy, acc_cnt, in_last));
            end

            in_fire_t   = in_vld && in_rdy;
            out_fire_t  = out_vld && out_rdy;
            completing_t = (acc_cnt == RATIO - 1) || in_last;

            @(posedge clk);

            if (in_fire_t) begin
                if (completing_t) begin
                    acc_cnt   = 0;
                    acc_model = '0;
                end else begin
                    acc_model[acc_cnt*IN_W +: IN_W] = in_data;
                    acc_cnt = acc_cnt + 1;
                end
                beat_data_q.delete(0);
                beat_last_q.delete(0);
            end

            if (out_fire_t && !in_fire_t) begin
                err("out_fire 成立但输入未被消费");
            end
        end

        if ((beat_data_q.size() != 0) || (acc_cnt != 0)) begin
            err($sformatf("未排空：剩余 %0d 拍，acc_cnt=%0d",
                          beat_data_q.size(), acc_cnt));
        end

        // 排空后再检查一拍，确认没有残留 valid
        @(negedge clk);
        in_vld  = 1'b0;
        in_last = 1'b0;
        out_rdy = 1'b1;
        #1;
        if (out_vld !== 1'b0) begin
            err("排空后 out_vld 应为 0");
        end

        if (errors == 0) begin
            $display("[%m] PASS");
        end else begin
            $display("[%m] FAIL: %0d errors", errors);
        end
        $finish;
    end

endmodule
