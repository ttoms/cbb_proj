`timescale 1ns/1ps
`default_nettype none

module strmux_checker #(
    parameter int                     N        = 4,
    parameter int                     PLD_W    = 8,
    parameter logic [2:0]             ARB_TYPE = 3'b001,
    parameter int                     WEIGHT_W = 2,
    parameter int                     QOS_W    = 2,
    parameter logic                   GRAN     = 1'b1,
    parameter logic [N*WEIGHT_W -1:0] WEIGHTS  = '1,
    parameter logic [N*QOS_W    -1:0] QOS      = '0,
    parameter int                     N_RANDOM = 300
) (
    input  logic clk,
    output int   errors,
    output logic done
);

    localparam int LOGD      = 1024;
    localparam int MAX_PKT   = 4;
    localparam int START_PROB = 50;
    localparam int GAP_PROB   = 20;
    localparam int CH_W      = (N > 1) ? $clog2(N) : 1;
    localparam int SEQ_W     = (PLD_W > CH_W) ? (PLD_W - CH_W) : 1;

    logic                   rst_n   ;
    logic [N -1:0]          in_hop  ;
    logic [N -1:0]          in_top  ;
    logic [N -1:0]          in_vld  ;
    logic [N -1:0]          in_rdy  ;
    logic [N*PLD_W -1:0]    in_pld  ;
    logic                   out_hop ;
    logic                   out_top ;
    logic                   out_vld ;
    logic                   out_rdy ;
    logic [PLD_W -1:0]      out_pld ;

    logic [N -1:0]  pending  ;
    logic [N -1:0]  in_pkt   ;
    int             seq      [N];
    int             pkt_remain [N];
    logic           cur_hop  [N];
    logic           cur_top  [N];

    logic [PLD_W -1:0] gen_pld [N][LOGD];
    logic              gen_hop [N][LOGD];
    logic              gen_top [N][LOGD];
    int                gen_cnt [N];
    int                cons_cnt[N];

    logic           out_in_pkt;
    int             out_pkt_ch;

    logic           last_stalled;
    logic [PLD_W -1:0] last_pld;
    logic           last_hop;
    logic           last_top;
    int             total_in_fire;
    int             total_out_fire;

    strmux #(
        .N        (N       ),
        .PLD_W    (PLD_W   ),
        .ARB_TYPE (ARB_TYPE),
        .WEIGHT_W (WEIGHT_W),
        .QOS_W    (QOS_W   ),
        .GRAN     (GRAN    )
    ) U_DUT (
        .clk     (clk     ),
        .rst_n   (rst_n   ),
        .in_hop  (in_hop  ),
        .in_top  (in_top  ),
        .in_vld  (in_vld  ),
        .in_rdy  (in_rdy  ),
        .in_pld  (in_pld  ),
        .weight  (WEIGHTS ),
        .qos     (QOS     ),
        .out_hop (out_hop ),
        .out_top (out_top ),
        .out_vld (out_vld ),
        .out_rdy (out_rdy ),
        .out_pld (out_pld )
    );

    function automatic logic [PLD_W -1:0] make_pld(input int ch, input int s);
        make_pld = PLD_W'((ch << SEQ_W) + (s & ((1 << SEQ_W) - 1)));
    endfunction

    function automatic int count_ones(input logic [N -1:0] v);
        count_ones = 0;
        for (int i = 0; i < N; i++) begin
            if (v[i]) begin
                count_ones = count_ones + 1;
            end
        end
    endfunction

    function automatic int first_one(input logic [N -1:0] v);
        first_one = -1;
        for (int i = 0; i < N; i++) begin
            if (v[i] && (first_one < 0)) begin
                first_one = i;
            end
        end
    endfunction

    task automatic push_flit(input int ch, input logic h, input logic t);
        logic [PLD_W -1:0] p;

        p = make_pld(ch, seq[ch]);
        seq[ch] = seq[ch] + 1;
        in_pld[ch*PLD_W +: PLD_W] = p;
        in_hop[ch] = h;
        in_top[ch] = t;
        if (gen_cnt[ch] >= LOGD) begin
            errors++;
            $display("FAIL: type=%b N=%0d GRAN=%b log overflow ch%0d",
                     ARB_TYPE, N, GRAN, ch);
        end else begin
            gen_pld[ch][gen_cnt[ch]] = p;
            gen_hop[ch][gen_cnt[ch]] = h;
            gen_top[ch][gen_cnt[ch]] = t;
            gen_cnt[ch] = gen_cnt[ch] + 1;
        end
    endtask

    task automatic apply_reset;
        rst_n  = 1'b0;
        in_hop = '0;
        in_top = '0;
        in_vld = '0;
        in_pld = '0;
        out_rdy = 1'b0;
        for (int i = 0; i < N; i++) begin
            pending[i]    = 1'b0;
            in_pkt[i]     = 1'b0;
            seq[i]        = 0;
            pkt_remain[i] = 0;
            cur_hop[i]    = 1'b0;
            cur_top[i]    = 1'b0;
            gen_cnt[i]    = 0;
            cons_cnt[i]   = 0;
        end
        out_in_pkt     = 1'b0;
        out_pkt_ch     = 0;
        last_stalled   = 1'b0;
        last_pld       = '0;
        last_hop       = 1'b0;
        last_top       = 1'b0;
        total_in_fire  = 0;
        total_out_fire = 0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        #1;
    endtask

    task automatic random_test(input int cycles);
        int            ones;
        int            idx;
        int            fire;
        int            len;
        logic [N -1:0] prev_rdy;

        apply_reset();
        prev_rdy = '0;

        for (int k = 0; k < cycles; k++) begin
            @(negedge clk);

            // 上一拍 in_rdy 在位：对应 flit 已在上升沿完成握手
            for (int i = 0; i < N; i++) begin
                if (prev_rdy[i]) begin
                    pending[i] = 1'b0;
                    if (cur_top[i]) begin
                        in_pkt[i] = 1'b0;
                    end
                end
            end

            // 驱动本拍源模型
            for (int i = 0; i < N; i++) begin
                if (pending[i]) begin
                    in_vld[i] = 1'b1;
                end else if (in_pkt[i]) begin
                    if ($urandom_range(0, 99) < GAP_PROB) begin
                        // packet 内 vld 间隙，用于验证锁定不切换
                        in_vld[i] = 1'b0;
                    end else begin
                        cur_hop[i]    = 1'b0;
                        cur_top[i]    = (pkt_remain[i] == 1);
                        pkt_remain[i] = pkt_remain[i] - 1;
                        push_flit(i, cur_hop[i], cur_top[i]);
                        in_vld[i]  = 1'b1;
                        pending[i] = 1'b1;
                    end
                end else if ($urandom_range(0, 99) < START_PROB) begin
                    len           = $urandom_range(1, MAX_PKT);
                    pkt_remain[i] = len - 1;
                    cur_hop[i]    = 1'b1;
                    cur_top[i]    = (len == 1);
                    in_pkt[i]     = 1'b1;
                    push_flit(i, 1'b1, (len == 1));
                    in_vld[i]  = 1'b1;
                    pending[i] = 1'b1;
                end else begin
                    in_vld[i] = 1'b0;
                end
            end
            out_rdy = ($urandom_range(0, 99) < 70);
            #1;

            fire     = out_vld & out_rdy;
            prev_rdy = in_rdy;
            ones     = count_ones(in_rdy);

            if (fire) begin
                if (ones != 1) begin
                    errors++;
                    $display("FAIL: type=%b N=%0d GRAN=%b fire with %0d rdy bits",
                             ARB_TYPE, N, GRAN, ones);
                end
            end else if (in_rdy != '0) begin
                errors++;
                $display("FAIL: type=%b N=%0d GRAN=%b rdy without fire: %b",
                         ARB_TYPE, N, GRAN, in_rdy);
            end

            if (ones == 1) begin
                idx = first_one(in_rdy);
                if (!in_vld[idx]) begin
                    errors++;
                    $display("FAIL: type=%b N=%0d GRAN=%b rdy on invalid ch%0d",
                             ARB_TYPE, N, GRAN, idx);
                end
                if (cons_cnt[idx] >= gen_cnt[idx]) begin
                    errors++;
                    $display("FAIL: type=%b N=%0d GRAN=%b consumed more than generated ch%0d",
                             ARB_TYPE, N, GRAN, idx);
                end else begin
                    if (out_pld !== gen_pld[idx][cons_cnt[idx]]) begin
                        errors++;
                        $display("FAIL: type=%b N=%0d GRAN=%b pld mismatch ch%0d got %h exp %h",
                                 ARB_TYPE, N, GRAN, idx, out_pld,
                                 gen_pld[idx][cons_cnt[idx]]);
                    end
                    if (out_hop !== gen_hop[idx][cons_cnt[idx]]) begin
                        errors++;
                        $display("FAIL: type=%b N=%0d GRAN=%b hop mismatch ch%0d got %b exp %b",
                                 ARB_TYPE, N, GRAN, idx, out_hop,
                                 gen_hop[idx][cons_cnt[idx]]);
                    end
                    if (out_top !== gen_top[idx][cons_cnt[idx]]) begin
                        errors++;
                        $display("FAIL: type=%b N=%0d GRAN=%b top mismatch ch%0d got %b exp %b",
                                 ARB_TYPE, N, GRAN, idx, out_top,
                                 gen_top[idx][cons_cnt[idx]]);
                    end
                    if ((GRAN == 1'b1) && out_hop && out_in_pkt) begin
                        errors++;
                        $display("FAIL: type=%b N=%0d packet head inside packet ch%0d",
                                 ARB_TYPE, N, idx);
                    end
                    if ((GRAN == 1'b1) && out_in_pkt && (idx != out_pkt_ch)) begin
                        errors++;
                        $display("FAIL: type=%b N=%0d packet switched ch%0d->%0d",
                                 ARB_TYPE, N, out_pkt_ch, idx);
                    end
                    if ((GRAN == 1'b1) && out_hop) begin
                        out_in_pkt = 1'b1;
                        out_pkt_ch = idx;
                    end
                    if ((GRAN == 1'b1) && out_top) begin
                        out_in_pkt = 1'b0;
                    end
                    cons_cnt[idx] = cons_cnt[idx] + 1;
                end
            end

            if (last_stalled) begin
                if (!out_vld) begin
                    errors++;
                    $display("FAIL: type=%b N=%0d GRAN=%b out_vld dropped during stall",
                             ARB_TYPE, N, GRAN);
                end
                if ((out_pld !== last_pld) || (out_hop !== last_hop) ||
                    (out_top !== last_top)) begin
                    errors++;
                    $display("FAIL: type=%b N=%0d GRAN=%b output changed during stall",
                             ARB_TYPE, N, GRAN);
                end
            end

            total_out_fire = total_out_fire + fire;
            total_in_fire  = total_in_fire + ones;
            last_stalled   = out_vld & ~out_rdy;
            last_pld       = out_pld;
            last_hop       = out_hop;
            last_top       = out_top;
        end

        if (total_out_fire == 0) begin
            errors++;
            $display("FAIL: type=%b N=%0d GRAN=%b no transfer observed", ARB_TYPE, N, GRAN);
        end
        if (total_in_fire != total_out_fire) begin
            errors++;
            $display("FAIL: type=%b N=%0d GRAN=%b fire count mismatch in=%0d out=%0d",
                     ARB_TYPE, N, GRAN, total_in_fire, total_out_fire);
        end
    endtask

    task automatic backpressure_test;
        logic [PLD_W -1:0] p0;
        logic              h0;
        logic              t0;

        apply_reset();

        // 每路起一个 2-flit packet 的头 flit
        for (int i = 0; i < N; i++) begin
            in_pkt[i]     = 1'b1;
            pkt_remain[i] = 1;
            cur_hop[i]    = 1'b1;
            cur_top[i]    = 1'b0;
            push_flit(i, 1'b1, 1'b0);
            in_vld[i]  = 1'b1;
            pending[i] = 1'b1;
        end
        out_rdy = 1'b0;

        @(negedge clk);
        #1;
        if (!out_vld) begin
            errors++;
            $display("FAIL: type=%b N=%0d GRAN=%b no out_vld under backpressure",
                     ARB_TYPE, N, GRAN);
        end
        if (in_rdy != '0) begin
            errors++;
            $display("FAIL: type=%b N=%0d GRAN=%b in_rdy asserted while stalled",
                     ARB_TYPE, N, GRAN);
        end
        p0 = out_pld;
        h0 = out_hop;
        t0 = out_top;
        if (!h0 || t0) begin
            errors++;
            $display("FAIL: type=%b N=%0d GRAN=%b expected head flit on first output",
                     ARB_TYPE, N, GRAN);
        end

        repeat (3) @(negedge clk);
        #1;
        if (!out_vld) begin
            errors++;
            $display("FAIL: type=%b N=%0d GRAN=%b out_vld dropped during backpressure",
                     ARB_TYPE, N, GRAN);
        end
        if ((out_pld !== p0) || (out_hop !== h0) || (out_top !== t0)) begin
            errors++;
            $display("FAIL: type=%b N=%0d GRAN=%b output changed during backpressure",
                     ARB_TYPE, N, GRAN);
        end
        if (in_rdy != '0) begin
            errors++;
            $display("FAIL: type=%b N=%0d GRAN=%b in_rdy asserted during backpressure",
                     ARB_TYPE, N, GRAN);
        end

        out_rdy = 1'b1;
        #1;
        if (!out_vld) begin
            errors++;
            $display("FAIL: type=%b N=%0d GRAN=%b out_vld missing after release",
                     ARB_TYPE, N, GRAN);
        end
        if (count_ones(in_rdy) != 1) begin
            errors++;
            $display("FAIL: type=%b N=%0d GRAN=%b release did not produce one handshake",
                     ARB_TYPE, N, GRAN);
        end
        if ((out_pld !== p0) || (out_hop !== h0) || (out_top !== t0)) begin
            errors++;
            $display("FAIL: type=%b N=%0d GRAN=%b output changed on release",
                     ARB_TYPE, N, GRAN);
        end

        @(negedge clk);
        out_rdy = 1'b0;
        for (int i = 0; i < N; i++) begin
            in_vld[i]  = 1'b0;
            in_hop[i]  = 1'b0;
            in_top[i]  = 1'b0;
            pending[i] = 1'b0;
            in_pkt[i]  = 1'b0;
        end
        #1;
    endtask

    task automatic no_req_test;
        apply_reset();

        for (int k = 0; k < 4; k++) begin
            @(negedge clk);
            in_vld  = '0;
            out_rdy = ($urandom_range(0, 1) == 1);
            #1;
            if (out_vld) begin
                errors++;
                $display("FAIL: type=%b N=%0d GRAN=%b out_vld with no request",
                         ARB_TYPE, N, GRAN);
            end
            if (in_rdy != '0) begin
                errors++;
                $display("FAIL: type=%b N=%0d GRAN=%b in_rdy with no request",
                         ARB_TYPE, N, GRAN);
            end
        end

        out_rdy = 1'b0;
        #1;
    endtask

    initial begin
        errors = 0;
        done   = 1'b0;
        rst_n  = 1'b0;
        in_hop = '0;
        in_top = '0;
        in_vld = '0;
        in_pld = '0;
        out_rdy = 1'b0;
        repeat (3) @(posedge clk);

        random_test(N_RANDOM);
        backpressure_test();
        no_req_test();

        done = 1'b1;
    end

endmodule

module strmux_tb;

    logic           clk     ;
    logic [7:0]     done    ;
    int             err0    ;
    int             err1    ;
    int             err2    ;
    int             err3    ;
    int             err4    ;
    int             err5    ;
    int             err6    ;
    int             err7    ;

    strmux_checker #(
        .N        (4),
        .ARB_TYPE (3'b000),
        .GRAN     (1'b0)
    ) U_CHK_FIXED_FLIT (
        .clk    (clk    ),
        .errors (err0   ),
        .done   (done[0])
    );

    strmux_checker #(
        .N        (4),
        .ARB_TYPE (3'b001),
        .GRAN     (1'b0)
    ) U_CHK_RR_FLIT (
        .clk    (clk    ),
        .errors (err1   ),
        .done   (done[1])
    );

    strmux_checker #(
        .N        (4),
        .ARB_TYPE (3'b000),
        .GRAN     (1'b1)
    ) U_CHK_FIXED_PKT (
        .clk    (clk    ),
        .errors (err2   ),
        .done   (done[2])
    );

    strmux_checker #(
        .N        (4),
        .ARB_TYPE (3'b001),
        .GRAN     (1'b1)
    ) U_CHK_RR_PKT (
        .clk    (clk    ),
        .errors (err3   ),
        .done   (done[3])
    );

    strmux_checker #(
        .N        (4),
        .ARB_TYPE (3'b010),
        .GRAN     (1'b1),
        .WEIGHTS  (8'h83)
    ) U_CHK_WRR_PKT (
        .clk    (clk    ),
        .errors (err4   ),
        .done   (done[4])
    );

    strmux_checker #(
        .N        (4),
        .ARB_TYPE (3'b011),
        .GRAN     (1'b1)
    ) U_CHK_LRU_PKT (
        .clk    (clk    ),
        .errors (err5   ),
        .done   (done[5])
    );

    strmux_checker #(
        .N        (4),
        .ARB_TYPE (3'b100),
        .GRAN     (1'b1),
        .QOS      (8'h2B)
    ) U_CHK_QRR_PKT (
        .clk    (clk    ),
        .errors (err6   ),
        .done   (done[6])
    );

    strmux_checker #(
        .N        (1),
        .ARB_TYPE (3'b001),
        .GRAN     (1'b1)
    ) U_CHK_N1_PKT (
        .clk    (clk    ),
        .errors (err7   ),
        .done   (done[7])
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        wait (&done);
        repeat (2) @(posedge clk);
        if ((err0 + err1 + err2 + err3 + err4 + err5 + err6 + err7) == 0) begin
            $display("PASS");
        end else begin
            $display("FAIL: %0d errors",
                     err0 + err1 + err2 + err3 + err4 + err5 + err6 + err7);
        end
        $finish;
    end

endmodule

`default_nettype wire
