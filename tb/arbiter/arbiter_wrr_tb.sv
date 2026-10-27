`timescale 1ns/1ps
`default_nettype none

module arbiter_wrr_checker #(
    parameter int                    N        = 4,
    parameter int                    WEIGHT_W = 2,
    parameter logic [N*WEIGHT_W -1:0] WEIGHTS = '1,
    parameter int                    N_RANDOM = 200
) (
    input  logic clk,
    output int   errors,
    output logic done
);

    logic [N -1:0]          req     ;
    logic [N -1:0]          gnt     ;
    logic                   gnt_vld ;
    logic                   rst_n   ;

    int cnt [N];

    arbiter_wrr #(
        .N         (N       ),
        .WEIGHT_W  (WEIGHT_W)
    ) U_DUT (
        .clk     (clk     ),
        .rst_n   (rst_n   ),
        .req     (req     ),
        .weight  (WEIGHTS ),
        .gnt     (gnt     ),
        .gnt_vld (gnt_vld )
    );

    function automatic int w_of(input int i);
        w_of = int'(WEIGHTS[i*WEIGHT_W +: WEIGHT_W]);
    endfunction

    function automatic int w_tot;
        w_tot = 0;
        for (int i = 0; i < N; i++) begin
            w_tot = w_tot + w_of(i);
        end
    endfunction

    function automatic int bit_cnt(input logic [N -1:0] v);
        bit_cnt = 0;
        for (int i = 0; i < N; i++) begin
            bit_cnt = bit_cnt + int'(v[i]);
        end
    endfunction

    function automatic logic [N -1:0] w_mask;
        w_mask = '0;
        for (int i = 0; i < N; i++) begin
            if (w_of(i) != 0) begin
                w_mask[i] = 1'b1;
            end
        end
    endfunction

    task automatic apply_reset;
        rst_n = 1'b0;
        req   = '0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        #1;
    endtask

    task automatic clear_cnt;
        for (int i = 0; i < N; i++) begin
            cnt[i] = 0;
        end
    endtask

    task automatic check_cycle(input logic [N -1:0] r, input string tag);
        logic [N -1:0] exp_vld;

        exp_vld = r & w_mask();

        if (gnt_vld !== (|exp_vld)) begin
            errors++;
            $display("FAIL: N=%0d weight=%h %s gnt_vld mismatch got %b exp %b",
                     N, WEIGHTS, tag, gnt_vld, (|exp_vld));
        end
        if (gnt_vld && (bit_cnt(gnt) != 1)) begin
            errors++;
            $display("FAIL: N=%0d weight=%h %s gnt not onehot: %b", N, WEIGHTS, tag, gnt);
        end
        if ((gnt & ~r) != '0) begin
            errors++;
            $display("FAIL: N=%0d weight=%h %s grant outside req: %b", N, WEIGHTS, tag, gnt);
        end
        if ((gnt & ~w_mask()) != '0) begin
            errors++;
            $display("FAIL: N=%0d weight=%h %s grant to zero-weight channel: %b",
                     N, WEIGHTS, tag, gnt);
        end
    endtask

    task automatic run_grants(input int n, input logic [N -1:0] r);
        for (int k = 0; k < n; k++) begin
            @(negedge clk);
            req = r;
            #1;
            check_cycle(r, "weighted");
            for (int i = 0; i < N; i++) begin
                if (gnt[i]) begin
                    cnt[i]++;
                end
            end
            @(posedge clk);
            #1;
        end
        req = '0;
        #1;
    endtask

    task automatic weighted_test(input int rounds);
        int total;
        int half;

        apply_reset();
        clear_cnt();

        total = w_tot() * rounds;

        if (w_tot() == 0) begin
            // 全零权重：即使全请求也不应授权，且 credit 保持不变
            for (int k = 0; k < (4 * N); k++) begin
                @(negedge clk);
                req = '1;
                #1;
                check_cycle('1, "zero-weight");
                @(posedge clk);
                #1;
            end
            req = '0;
            #1;
        end else begin
            half = total / 2;
            run_grants(half, '1);

            // 中途空闲 3 拍，credit 应保持，不应重置整轮
            for (int k = 0; k < 3; k++) begin
                @(negedge clk);
                req = '0;
                #1;
                if (gnt_vld) begin
                    errors++;
                    $display("FAIL: N=%0d weight=%h idle produced grant", N, WEIGHTS);
                end
                @(posedge clk);
                #1;
            end

            run_grants(total - half, '1);

            for (int i = 0; i < N; i++) begin
                if (cnt[i] != (w_of(i) * rounds)) begin
                    errors++;
                    $display("FAIL: N=%0d weight=%h ch%0d got %0d grants, exp %0d",
                             N, WEIGHTS, i, cnt[i], w_of(i) * rounds);
                end
            end
        end
    endtask

    task automatic random_test(input int cycles);
        for (int k = 0; k < cycles; k++) begin
            @(negedge clk);
            req = N'($urandom) & ((N'($urandom_range(0, 99)) < 70) ? {N{1'b1}} : '0);
            #1;
            check_cycle(req, "random");
            @(posedge clk);
            #1;
        end
        req = '0;
        #1;
    endtask

    initial begin
        errors = 0;
        done   = 1'b0;
        rst_n  = 1'b0;
        req    = '0;
        repeat (3) @(posedge clk);

        weighted_test(3);
        random_test(N_RANDOM);

        done = 1'b1;
    end

endmodule

module arbiter_wrr_tb;

    logic clk;

    logic done0;
    logic done1;
    logic done2;
    logic done3;

    int err0;
    int err1;
    int err2;
    int err3;

    arbiter_wrr_checker #(
        .N        (1),
        .WEIGHT_W (2),
        .WEIGHTS  (2'b11)
    ) U_CHK_N1 (
        .clk    (clk),
        .errors (err0),
        .done   (done0)
    );

    arbiter_wrr_checker #(
        .N        (4),
        .WEIGHT_W (2),
        .WEIGHTS  (8'h55)
    ) U_CHK_EQ (
        .clk    (clk),
        .errors (err1),
        .done   (done1)
    );

    arbiter_wrr_checker #(
        .N        (4),
        .WEIGHT_W (2),
        .WEIGHTS  (8'h83)
    ) U_CHK_MIX (
        .clk    (clk),
        .errors (err2),
        .done   (done2)
    );

    arbiter_wrr_checker #(
        .N        (2),
        .WEIGHT_W (2),
        .WEIGHTS  (4'b0000)
    ) U_CHK_ZERO (
        .clk    (clk),
        .errors (err3),
        .done   (done3)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        wait ((done0 == 1'b1) && (done1 == 1'b1) &&
              (done2 == 1'b1) && (done3 == 1'b1));
        repeat (2) @(posedge clk);
        if ((err0 + err1 + err2 + err3) == 0) begin
            $display("PASS");
        end else begin
            $display("FAIL: %0d errors", err0 + err1 + err2 + err3);
        end
        $finish;
    end

endmodule

`default_nettype wire
