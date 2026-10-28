`timescale 1ns/1ps

module width_conv_down_tb;

    localparam int IN_W  = 32;
    localparam int OUT_W = 8;
    localparam int RATIO = IN_W / OUT_W;

    logic               clk         ;
    logic               rst_n       ;
    logic               in_vld      ;
    logic               in_rdy      ;
    logic [IN_W  -1:0]  in_data     ;
    logic [RATIO -1:0]  in_keep     ;
    logic               in_last     ;
    logic               out_vld     ;
    logic               out_rdy     ;
    logic [OUT_W -1:0]  out_data    ;
    logic               out_keep    ;
    logic               out_last    ;

    logic [IN_W-1:0] wdata_q[$];
    logic [RATIO-1:0] wkeep_q[$];
    logic            wlast_q[$];

    logic               buf_vld     ;
    logic [IN_W  -1:0]  buf_data    ;
    logic [RATIO -1:0]  buf_keep    ;
    logic               buf_last    ;
    int                 lane_cnt    ;
    int                 last_lane   ;
    int                 errors      ;

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

    function automatic int calc_last(input logic [RATIO-1:0] k);
        int r;

        r = 0;
        for (int i = 0; i < RATIO; i++) begin
            if (k[i]) begin
                r = i;
            end
        end
        calc_last = r;
    endfunction

    task automatic push_word(
        input logic [IN_W-1:0]   d,
        input logic [RATIO-1:0]  k,
        input logic              l
    );
        wdata_q.push_back(d);
        wkeep_q.push_back(k);
        wlast_q.push_back(l);
    endtask

    initial begin
        logic   in_fire_t       ;
        logic   out_fire_t      ;
        logic   in_rdy_model    ;
        logic   lane_last       ;

        rst_n     = 1'b0;
        in_vld    = 1'b0;
        in_data   = '0;
        in_keep   = '0;
        in_last   = 1'b0;
        out_rdy   = 1'b0;
        buf_vld   = 1'b0;
        buf_data  = '0;
        buf_keep  = '0;
        buf_last  = 1'b0;
        lane_cnt  = 0;
        last_lane = 0;
        errors    = 0;

        push_word(32'h44332211, 4'b1111, 1'b0);
        push_word(32'h0000BBAA, 4'b0011, 1'b1);
        push_word(32'hDDCCBBAA, 4'b1111, 1'b1);
        push_word(32'h000000EE, 4'b0001, 1'b0);
        push_word(32'h00CCBBAA, 4'b0111, 1'b1);

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        for (int cyc = 0; cyc < 300; cyc++) begin
            @(negedge clk);

            in_vld = (wdata_q.size() > 0);
            if (in_vld) begin
                in_data = wdata_q[0];
                in_keep = wkeep_q[0];
                in_last = wlast_q[0];
            end else begin
                in_data = '0;
                in_keep = '0;
                in_last = 1'b0;
            end

            if ((wdata_q.size() > 0) || buf_vld) begin
                out_rdy = ($urandom_range(0, 3) != 0);
            end else begin
                out_rdy = 1'b1;
            end

            #1;

            lane_last    = (lane_cnt == last_lane);
            out_fire_t   = out_vld && out_rdy;
            in_rdy_model = (!buf_vld) || (out_fire_t && lane_last);
            in_fire_t    = in_vld && in_rdy;

            if (out_vld !== buf_vld) begin
                err($sformatf("out_vld=%0b, buf_vld=%0b", out_vld, buf_vld));
            end
            if (in_rdy !== in_rdy_model) begin
                err($sformatf("in_rdy=%0b, exp=%0b, buf_vld=%0b, out_rdy=%0b",
                              in_rdy, in_rdy_model, buf_vld, out_rdy));
            end

            if (buf_vld) begin
                if (out_data !== buf_data[lane_cnt*OUT_W +: OUT_W]) begin
                    err($sformatf("out_data=%0h, exp=%0h, lane=%0d",
                                  out_data, buf_data[lane_cnt*OUT_W +: OUT_W], lane_cnt));
                end
                if (out_keep !== 1'b1) begin
                    err($sformatf("out_keep=%0b, exp=1", out_keep));
                end
                if (out_last !== (buf_last && lane_last)) begin
                    err($sformatf("out_last=%0b, exp=%0b, buf_last=%0b, lane_last=%0b",
                                  out_last, buf_last && lane_last, buf_last, lane_last));
                end
            end

            @(posedge clk);

            if (in_fire_t) begin
                buf_data  = in_data;
                buf_keep  = in_keep;
                buf_last  = in_last;
                buf_vld   = 1'b1;
                lane_cnt  = 0;
                last_lane = calc_last(in_keep);
                wdata_q.delete(0);
                wkeep_q.delete(0);
                wlast_q.delete(0);
            end else if (out_fire_t) begin
                if (lane_last) begin
                    buf_vld  = 1'b0;
                    lane_cnt = 0;
                end else begin
                    lane_cnt = lane_cnt + 1;
                end
            end
        end

        if ((wdata_q.size() != 0) || buf_vld) begin
            err($sformatf("未排空：剩余 %0d 宽字，buf_vld=%0b",
                          wdata_q.size(), buf_vld));
        end

        @(negedge clk);
        in_vld  = 1'b0;
        in_keep = '0;
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
