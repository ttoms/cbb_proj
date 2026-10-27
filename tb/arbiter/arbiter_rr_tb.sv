`timescale 1ns/1ps
`default_nettype none

module arbiter_rr_checker #(
    parameter int N        = 4,
    parameter int N_RANDOM = 200
) (
    input  logic clk,
    output int   errors,
    output logic done
);

    logic [N -1:0]  req     ;
    logic [N -1:0]  gnt     ;
    logic           gnt_vld ;
    logic           rst_n   ;

    arbiter_rr #(
        .N (N)
    ) U_DUT (
        .clk     (clk    ),
        .rst_n   (rst_n  ),
        .req     (req    ),
        .gnt     (gnt    ),
        .gnt_vld (gnt_vld)
    );

    function automatic int rr_sel(input logic [N -1:0] r, input int p);
        int j;

        rr_sel = -1;
        for (int i = 0; i < N; i++) begin
            j = (p + i) % N;
            if ((rr_sel < 0) && r[j]) begin
                rr_sel = j;
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

    task automatic random_test(input int cycles);
        int sel;
        int exp_ptr;

        apply_reset();
        exp_ptr = 0;

        for (int k = 0; k < cycles; k++) begin
            @(negedge clk);
            req = N'($urandom) & N'($urandom_range(0, 99) < 70 ? '1 : '0);
            #1;

            sel = rr_sel(req, exp_ptr);
            check_grant(sel, "random");

            @(posedge clk);
            #1;
            if (sel >= 0) begin
                exp_ptr = (sel == (N - 1)) ? 0 : (sel + 1);
            end
        end
    endtask

    task automatic fairness_test;
        int exp_ptr;

        apply_reset();
        exp_ptr = 0;

        for (int k = 0; k < (2 * N); k++) begin
            @(negedge clk);
            req = '1;
            #1;
            check_grant(exp_ptr, "fairness");
            @(posedge clk);
            #1;
            exp_ptr = (exp_ptr == (N - 1)) ? 0 : (exp_ptr + 1);
        end

        req = '0;
        #1;
    endtask

    task automatic single_test;
        logic [N -1:0] onehot;
        int sel;

        apply_reset();

        for (int i = 0; i < N; i++) begin
            @(negedge clk);
            onehot = '0;
            onehot[i] = 1'b1;
            req = onehot;
            #1;
            check_grant(i, "single");

            @(posedge clk);
            #1;

            // 授权 i 之后，ptr 应指向 i+1；用全请求验证下一次优先路
            @(negedge clk);
            req = '1;
            #1;
            sel = (i == (N - 1)) ? 0 : (i + 1);
            check_grant(sel, "single-next");

            @(posedge clk);
            #1;
        end

        req = '0;
        #1;
    endtask

    task automatic no_req_test(input int cycles);
        apply_reset();

        for (int k = 0; k < cycles; k++) begin
            @(negedge clk);
            req = '0;
            #1;
            check_grant(-1, "no-req");
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        errors = 0;
        done   = 1'b0;
        rst_n  = 1'b0;
        req    = '0;
        repeat (3) @(posedge clk);

        random_test(N_RANDOM);
        fairness_test();
        single_test();
        no_req_test(3);

        done = 1'b1;
    end

endmodule

module arbiter_rr_tb;

    logic clk;

    logic done0;
    logic done1;
    logic done2;

    int err0;
    int err1;
    int err2;

    arbiter_rr_checker #(
        .N (1)
    ) U_CHK_N1 (
        .clk    (clk),
        .errors (err0),
        .done   (done0)
    );

    arbiter_rr_checker #(
        .N (2)
    ) U_CHK_N2 (
        .clk    (clk),
        .errors (err1),
        .done   (done1)
    );

    arbiter_rr_checker #(
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
