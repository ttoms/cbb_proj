`timescale 1ns/1ps
`default_nettype none

module arbmux_checker #(
    parameter int                     N        = 4,
    parameter int                     PLD_W    = 8,
    parameter logic [2:0]             ARB_TYPE = 3'b001,
    parameter int                     WEIGHT_W = 2,
    parameter int                     QOS_W    = 2,
    parameter logic [N*WEIGHT_W -1:0] WEIGHTS  = '1,
    parameter logic [N*QOS_W    -1:0] QOS      = '0,
    parameter int                     N_RANDOM = 200
) (
    input  logic clk,
    output int   errors,
    output logic done
);

    localparam int CH_W  = (N > 1) ? $clog2(N) : 1;
    localparam int SEQ_W = (PLD_W > CH_W) ? (PLD_W - CH_W) : 1;

    logic                   rst_n   ;
    logic [N -1:0]          in_vld  ;
    logic [N -1:0]          in_rdy  ;
    logic [N*PLD_W -1:0]    in_pld  ;
    logic                   out_vld ;
    logic                   out_rdy ;
    logic [PLD_W -1:0]      out_pld ;

    logic [N -1:0]          pending;
    int                     seq [N];

    logic                   last_stalled;
    logic [PLD_W -1:0]      last_pld;
    int                     total_in_fire;
    int                     total_out_fire;

    arbmux #(
        .N        (N       ),
        .PLD_W    (PLD_W   ),
        .ARB_TYPE (ARB_TYPE),
        .WEIGHT_W (WEIGHT_W),
        .QOS_W    (QOS_W   )
    ) U_DUT (
        .clk     (clk     ),
        .rst_n   (rst_n   ),
        .in_vld  (in_vld  ),
        .in_rdy  (in_rdy  ),
        .in_pld  (in_pld  ),
        .weight  (WEIGHTS ),
        .qos     (QOS     ),
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

    task automatic apply_reset;
        rst_n = 1'b0;
        in_vld = '0;
        in_pld = '0;
        out_rdy = 1'b0;
        for (int i = 0; i < N; i++) begin
            pending[i] = 1'b0;
            seq[i]     = 0;
        end
        total_in_fire  = 0;
        total_out_fire = 0;
        last_stalled   = 1'b0;
        last_pld       = '0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        #1;
    endtask

    task automatic random_test(input int cycles);
        int            ones;
        int            idx;
        int            fire;
        logic [N -1:0] prev_rdy;

        apply_reset();
        prev_rdy = '0;

        for (int k = 0; k < cycles; k++) begin
            @(negedge clk);

            // 上一拍采样到的 in_rdy 在刚才的上升沿完成握手，释放源模型
            for (int i = 0; i < N; i++) begin
                if (prev_rdy[i]) begin
                    pending[i] = 1'b0;
                end
            end

            // 驱动本拍源模型
            for (int i = 0; i < N; i++) begin
                if (pending[i]) begin
                    in_vld[i] = 1'b1;
                end else if ($urandom_range(0, 99) < 70) begin
                    in_pld[i*PLD_W +: PLD_W] = make_pld(i, seq[i]);
                    seq[i]    = seq[i] + 1;
                    in_vld[i] = 1'b1;
                    pending[i] = 1'b1;
                end else begin
                    in_vld[i] = 1'b0;
                end
            end
            out_rdy = ($urandom_range(0, 99) < 70);
            #1;

            // 采样本拍组合输出（即下一个上升沿将被消费的值）
            fire     = out_vld & out_rdy;
            prev_rdy = in_rdy;
            ones     = count_ones(in_rdy);

            if (fire) begin
                if (ones != 1) begin
                    errors++;
                    $display("FAIL: type=%b N=%0d fire with %0d rdy bits",
                             ARB_TYPE, N, ones);
                end
            end else if (in_rdy != '0) begin
                errors++;
                $display("FAIL: type=%b N=%0d rdy asserted without output fire: %b",
                         ARB_TYPE, N, in_rdy);
            end

            if (ones == 1) begin
                idx = first_one(in_rdy);
                if (!in_vld[idx]) begin
                    errors++;
                    $display("FAIL: type=%b N=%0d rdy on invalid channel %0d",
                             ARB_TYPE, N, idx);
                end
                if (out_pld !== in_pld[idx*PLD_W +: PLD_W]) begin
                    errors++;
                    $display("FAIL: type=%b N=%0d payload mismatch ch%0d got %h exp %h",
                             ARB_TYPE, N, idx, out_pld, in_pld[idx*PLD_W +: PLD_W]);
                end
            end

            if (last_stalled) begin
                if (!out_vld) begin
                    errors++;
                    $display("FAIL: type=%b N=%0d out_vld dropped during stall", ARB_TYPE, N);
                end
                if (out_pld !== last_pld) begin
                    errors++;
                    $display("FAIL: type=%b N=%0d payload changed during stall", ARB_TYPE, N);
                    $display("  k=%0d out_vld=%b out_rdy=%b out_pld=%h last_pld=%h hold=%b in_vld=%b",
                             k, out_vld, out_rdy, out_pld, last_pld,
                             U_DUT.hold_oh, in_vld);
                end
            end

            total_out_fire = total_out_fire + fire;
            total_in_fire  = total_in_fire + ones;
            last_stalled   = out_vld & ~out_rdy;
            last_pld       = out_pld;
        end

        if (total_out_fire == 0) begin
            errors++;
            $display("FAIL: type=%b N=%0d no transfer observed", ARB_TYPE, N);
        end
        if (total_in_fire != total_out_fire) begin
            errors++;
            $display("FAIL: type=%b N=%0d fire count mismatch in=%0d out=%0d",
                     ARB_TYPE, N, total_in_fire, total_out_fire);
        end
    endtask

    task automatic backpressure_test;
        logic [PLD_W -1:0] p0;

        apply_reset();

        for (int i = 0; i < N; i++) begin
            in_pld[i*PLD_W +: PLD_W] = make_pld(i, 0);
            seq[i]     = 1;
            in_vld[i]  = 1'b1;
            pending[i] = 1'b1;
        end
        out_rdy = 1'b0;

        @(negedge clk);
        #1;
        if (!out_vld) begin
            errors++;
            $display("FAIL: type=%b N=%0d no out_vld under backpressure", ARB_TYPE, N);
        end
        if (in_rdy != '0) begin
            errors++;
            $display("FAIL: type=%b N=%0d in_rdy asserted while stalled", ARB_TYPE, N);
        end
        p0 = out_pld;

        repeat (4) @(negedge clk);
        #1;
        if (!out_vld) begin
            errors++;
            $display("FAIL: type=%b N=%0d out_vld dropped during backpressure", ARB_TYPE, N);
        end
        if (out_pld !== p0) begin
            errors++;
            $display("FAIL: type=%b N=%0d out_pld changed during backpressure", ARB_TYPE, N);
        end
        if (in_rdy != '0) begin
            errors++;
            $display("FAIL: type=%b N=%0d in_rdy asserted during backpressure", ARB_TYPE, N);
        end

        out_rdy = 1'b1;
        #1;
        if (!out_vld) begin
            errors++;
            $display("FAIL: type=%b N=%0d out_vld missing after backpressure release", ARB_TYPE, N);
        end
        if (count_ones(in_rdy) != 1) begin
            errors++;
            $display("FAIL: type=%b N=%0d release did not produce one handshake", ARB_TYPE, N);
        end
        if (out_pld !== p0) begin
            errors++;
            $display("FAIL: type=%b N=%0d payload changed on backpressure release", ARB_TYPE, N);
        end

        @(negedge clk);
        out_rdy = 1'b0;
        in_vld  = '0;
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
                $display("FAIL: type=%b N=%0d out_vld with no request", ARB_TYPE, N);
            end
            if (in_rdy != '0) begin
                errors++;
                $display("FAIL: type=%b N=%0d in_rdy with no request", ARB_TYPE, N);
            end
        end

        out_rdy = 1'b0;
        #1;
    endtask

    initial begin
        errors = 0;
        done   = 1'b0;
        rst_n  = 1'b0;
        in_vld = '0;
        out_rdy = 1'b0;
        repeat (3) @(posedge clk);

        random_test(N_RANDOM);
        backpressure_test();
        no_req_test();

        done = 1'b1;
    end

endmodule

module arbmux_tb;

    logic           clk     ;
    logic [5:0]     done    ;
    int             err0    ;
    int             err1    ;
    int             err2    ;
    int             err3    ;
    int             err4    ;
    int             err5    ;

    arbmux_checker #(
        .N        (4),
        .ARB_TYPE (3'b000)
    ) U_CHK_FIXED (
        .clk    (clk    ),
        .errors (err0   ),
        .done   (done[0])
    );

    arbmux_checker #(
        .N        (4),
        .ARB_TYPE (3'b001)
    ) U_CHK_RR (
        .clk    (clk    ),
        .errors (err1   ),
        .done   (done[1])
    );

    arbmux_checker #(
        .N        (4),
        .ARB_TYPE (3'b010),
        .WEIGHTS  (8'h83)
    ) U_CHK_WRR (
        .clk    (clk    ),
        .errors (err2   ),
        .done   (done[2])
    );

    arbmux_checker #(
        .N        (4),
        .ARB_TYPE (3'b011)
    ) U_CHK_LRU (
        .clk    (clk    ),
        .errors (err3   ),
        .done   (done[3])
    );

    arbmux_checker #(
        .N        (4),
        .ARB_TYPE (3'b100),
        .QOS      (8'h2B)
    ) U_CHK_QRR (
        .clk    (clk    ),
        .errors (err4   ),
        .done   (done[4])
    );

    arbmux_checker #(
        .N        (1),
        .ARB_TYPE (3'b001)
    ) U_CHK_N1 (
        .clk    (clk    ),
        .errors (err5   ),
        .done   (done[5])
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        wait (&done);
        repeat (2) @(posedge clk);
        if ((err0 + err1 + err2 + err3 + err4 + err5) == 0) begin
            $display("PASS");
        end else begin
            $display("FAIL: %0d errors", err0 + err1 + err2 + err3 + err4 + err5);
        end
        $finish;
    end

endmodule

`default_nettype wire
