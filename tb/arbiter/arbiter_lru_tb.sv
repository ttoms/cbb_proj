`timescale 1ns/1ps
`default_nettype none

module arbiter_lru_checker #(
    parameter int N        = 4,
    parameter int N_RANDOM = 200
) (
    input  logic clk,
    output int   errors,
    output logic done
);

    localparam int AGE_W_MODEL = (N > 1) ? ($clog2(N) + 1) : 1;
    localparam int AGE_MAX_MODEL = (1 << AGE_W_MODEL) - 1;

    logic [N -1:0]  req     ;
    logic [N -1:0]  gnt     ;
    logic           gnt_vld ;
    logic           rst_n   ;
    logic           upd     ;

    int exp_age [N];

    arbiter_lru #(
        .N (N)
    ) U_DUT (
        .clk     (clk    ),
        .rst_n   (rst_n  ),
        .upd     (upd    ),
        .req     (req    ),
        .gnt     (gnt    ),
        .gnt_vld (gnt_vld)
    );

    function automatic int lru_sel(input logic [N -1:0] r);
        int     best;
        int     sel;
        logic   found;

        best  = 0;
        sel   = 0;
        found = 1'b0;

        for (int i = 0; i < N; i++) begin
            if (r[i] && (!found || (exp_age[i] > best))) begin
                found = 1'b1;
                best  = exp_age[i];
                sel   = i;
            end
        end

        lru_sel = found ? sel : -1;
    endfunction

    task automatic clear_age;
        for (int i = 0; i < N; i++) begin
            exp_age[i] = 0;
        end
    endtask

    task automatic apply_reset;
        rst_n = 1'b0;
        req   = '0;
        upd   = 1'b1;
        clear_age();
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        #1;
    endtask

    task automatic check_grant(input int sel, input string tag);
        logic [N -1:0] exp_gnt;

        exp_gnt = '0;
        if (sel >= 0) begin
            exp_gnt[sel] = 1'b1;
        end

        if (gnt !== exp_gnt) begin
            errors++;
            $display("FAIL: N=%0d %s gnt mismatch got %b exp %b", N, tag, gnt, exp_gnt);
        end
        if (gnt_vld !== (sel >= 0)) begin
            errors++;
            $display("FAIL: N=%0d %s gnt_vld mismatch got %b exp %b",
                     N, tag, gnt_vld, (sel >= 0));
        end
    endtask

    task automatic update_age(input int sel);
        for (int i = 0; i < N; i++) begin
            if (i == sel) begin
                exp_age[i] = 0;
            end else if (exp_age[i] >= AGE_MAX_MODEL) begin
                exp_age[i] = AGE_MAX_MODEL;
            end else begin
                exp_age[i] = exp_age[i] + 1;
            end
        end
    endtask

    task automatic random_test(input int cycles);
        int sel;

        apply_reset();

        for (int k = 0; k < cycles; k++) begin
            @(negedge clk);
            req = N'($urandom) & ((N'($urandom_range(0, 99)) < 70) ? {N{1'b1}} : '0);
            #1;

            sel = lru_sel(req);
            check_grant(sel, "random");

            @(posedge clk);
            #1;
            if (sel >= 0) begin
                update_age(sel);
            end
        end

        req = '0;
        #1;
    endtask

    task automatic all_req_test;
        int sel;

        apply_reset();

        for (int k = 0; k < (2 * N); k++) begin
            @(negedge clk);
            req = '1;
            #1;

            sel = lru_sel(req);
            check_grant(sel, "all-req");
            if (sel != (k % N)) begin
                errors++;
                $display("FAIL: N=%0d all-req sequence got ch%0d at step %0d, exp ch%0d",
                         N, sel, k, (k % N));
            end

            @(posedge clk);
            #1;
            if (sel >= 0) begin
                update_age(sel);
            end
        end

        req = '0;
        #1;
    endtask

    task automatic lru_preference_test;
        int sel;

        apply_reset();

        // 先授权索引 0
        @(negedge clk);
        req = '0;
        req[0] = 1'b1;
        #1;
        check_grant(0, "pref-first");
        @(posedge clk);
        #1;
        update_age(0);

        // 空闲两拍，年龄保持
        for (int k = 0; k < 2; k++) begin
            @(negedge clk);
            req = '0;
            #1;
            check_grant(-1, "pref-idle");
            @(posedge clk);
            #1;
        end

        // 全请求时，刚刚授权过的索引 0 应最后被选中
        @(negedge clk);
        req = '1;
        #1;
        sel = lru_sel(req);
        if ((N > 1) && (sel != 1)) begin
            errors++;
            $display("FAIL: N=%0d LRU preference got ch%0d, exp ch1", N, sel);
        end
        check_grant(sel, "pref-resume");
        @(posedge clk);
        #1;
        update_age(sel);

        req = '0;
        #1;
    endtask

    task automatic no_req_test;
        apply_reset();

        for (int k = 0; k < 3; k++) begin
            @(negedge clk);
            req = '0;
            #1;
            check_grant(-1, "no-req");
            @(posedge clk);
            #1;
        end
    endtask

    // upd=0 时年龄冻结、gnt 不切换；upd=1 后恢复更新
    task automatic hold_test;
        int held;
        int sel;

        apply_reset();
        upd = 1'b0;
        req = '1;

        @(negedge clk);
        #1;
        held = lru_sel(req);
        check_grant(held, "upd-hold-start");

        for (int k = 0; k < 4; k++) begin
            @(posedge clk);
            #1;
            @(negedge clk);
            req = '1;
            #1;
            check_grant(held, "upd-hold");
        end

        upd = 1'b1;
        @(posedge clk);
        #1;
        update_age(held);

        @(negedge clk);
        req = '1;
        #1;
        sel = lru_sel(req);
        check_grant(sel, "upd-resume");
        if ((N > 1) && (sel == held)) begin
            errors++;
            $display("FAIL: N=%0d upd-resume kept ch%0d (exp another)", N, held);
        end

        @(posedge clk);
        #1;
        update_age(sel);

        req = '0;
        upd = 1'b1;
        #1;
    endtask

    initial begin
        errors = 0;
        done   = 1'b0;
        rst_n  = 1'b0;
        req    = '0;
        upd    = 1'b1;
        repeat (3) @(posedge clk);

        random_test(N_RANDOM);
        all_req_test();
        lru_preference_test();
        no_req_test();
        hold_test();

        done = 1'b1;
    end

endmodule

module arbiter_lru_tb;

    logic clk;

    logic done0;
    logic done1;
    logic done2;

    int err0;
    int err1;
    int err2;

    arbiter_lru_checker #(
        .N (1)
    ) U_CHK_N1 (
        .clk    (clk),
        .errors (err0),
        .done   (done0)
    );

    arbiter_lru_checker #(
        .N (2)
    ) U_CHK_N2 (
        .clk    (clk),
        .errors (err1),
        .done   (done1)
    );

    arbiter_lru_checker #(
        .N (4)
    ) U_CHK_N4 (
        .clk    (clk),
        .errors (err2),
        .done   (done2)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        wait ((done0 == 1'b1) && (done1 == 1'b1) && (done2 == 1'b1));
        repeat (2) @(posedge clk);
        if ((err0 + err1 + err2) == 0) begin
            $display("PASS");
        end else begin
            $display("FAIL: %0d errors", err0 + err1 + err2);
        end
        $finish;
    end

endmodule

`default_nettype wire
