`timescale 1ns/1ps
`default_nettype none

module arbiter_qrr_checker #(
    parameter int            N        = 4,
    parameter int            QOS_W    = 2,
    parameter logic [N*QOS_W -1:0] QOS = '1,
    parameter int            N_RANDOM = 200
) (
    input  logic clk,
    output int   errors,
    output logic done
);

    logic [N -1:0]  req     ;
    logic [N -1:0]  gnt     ;
    logic           gnt_vld ;
    logic           rst_n   ;

    int exp_ptr;

    arbiter_qrr #(
        .N      (N    ),
        .QOS_W  (QOS_W)
    ) U_DUT (
        .clk     (clk     ),
        .rst_n   (rst_n   ),
        .req     (req     ),
        .qos     (QOS     ),
        .gnt     (gnt     ),
        .gnt_vld (gnt_vld )
    );

    function automatic int q_of(input int i);
        q_of = int'(QOS[i*QOS_W +: QOS_W]);
    endfunction

    function automatic int max_qos_of(input logic [N -1:0] r);
        int m;

        m = 0;
        for (int i = 0; i < N; i++) begin
            if (r[i] && (q_of(i) > m)) begin
                m = q_of(i);
            end
        end
        max_qos_of = m;
    endfunction

    function automatic logic [N -1:0] high_mask;
        int m;

        m = 0;
        for (int i = 0; i < N; i++) begin
            if (q_of(i) > m) begin
                m = q_of(i);
            end
        end

        high_mask = '0;
        for (int i = 0; i < N; i++) begin
            if (q_of(i) == m) begin
                high_mask[i] = 1'b1;
            end
        end
    endfunction

    function automatic logic all_equal;
        all_equal = 1'b1;
        for (int i = 1; i < N; i++) begin
            if (q_of(i) != q_of(0)) begin
                all_equal = 1'b0;
            end
        end
    endfunction

    function automatic int qrr_sel(input logic [N -1:0] r, input int p);
        int     m;
        int     idx;
        logic   found;

        m     = max_qos_of(r);
        found = 1'b0;
        qrr_sel = -1;

        for (int i = 0; i < N; i++) begin
            idx = (p + i) % N;
            if (!found && r[idx] && (q_of(idx) == m)) begin
                found   = 1'b1;
                qrr_sel = idx;
            end
        end
    endfunction

    task automatic apply_reset;
        rst_n = 1'b0;
        req   = '0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        exp_ptr = 0;
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
            $display("FAIL: N=%0d qos=%h %s gnt mismatch got %b exp %b",
                     N, QOS, tag, gnt, exp_gnt);
        end
        if (gnt_vld !== (sel >= 0)) begin
            errors++;
            $display("FAIL: N=%0d qos=%h %s gnt_vld mismatch got %b exp %b",
                     N, QOS, tag, gnt_vld, (sel >= 0));
        end
    endtask

    task automatic random_test(input int cycles);
        int sel;

        apply_reset();

        for (int k = 0; k < cycles; k++) begin
            @(negedge clk);
            req = N'($urandom) & ((N'($urandom_range(0, 99)) < 70) ? {N{1'b1}} : '0);
            #1;

            sel = qrr_sel(req, exp_ptr);
            check_grant(sel, "random");

            @(posedge clk);
            #1;
            if (sel >= 0) begin
                exp_ptr = (sel == (N - 1)) ? 0 : (sel + 1);
            end
        end

        req = '0;
        #1;
    endtask

    task automatic high_priority_test;
        int sel;

        apply_reset();

        for (int k = 0; k < (2 * N); k++) begin
            @(negedge clk);
            req = '1;
            #1;

            sel = qrr_sel(req, exp_ptr);
            check_grant(sel, "high-qos");

            if ((gnt & ~high_mask()) != '0) begin
                errors++;
                $display("FAIL: N=%0d qos=%h granted outside highest QoS group: %b",
                         N, QOS, gnt);
            end
            if (all_equal() && (sel != (k % N))) begin
                errors++;
                $display("FAIL: N=%0d equal-qos sequence got ch%0d at step %0d, exp ch%0d",
                         N, sel, k, (k % N));
            end

            @(posedge clk);
            #1;
            if (sel >= 0) begin
                exp_ptr = (sel == (N - 1)) ? 0 : (sel + 1);
            end
        end

        req = '0;
        #1;
    endtask

    task automatic fallback_test;
        logic [N -1:0] req_low;
        logic [N -1:0] hm;
        int sel;

        hm      = high_mask();
        req_low = '0;
        for (int i = 0; i < N; i++) begin
            if (!hm[i]) begin
                req_low[i] = 1'b1;
            end
        end

        if (req_low != '0) begin
            apply_reset();

            for (int k = 0; k < N; k++) begin
                @(negedge clk);
                req = req_low;
                #1;

                sel = qrr_sel(req, exp_ptr);
                check_grant(sel, "fallback");

                @(posedge clk);
                #1;
                if (sel >= 0) begin
                    exp_ptr = (sel == (N - 1)) ? 0 : (sel + 1);
                end
            end

            req = '0;
            #1;
        end
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

    initial begin
        errors = 0;
        done   = 1'b0;
        rst_n  = 1'b0;
        req    = '0;
        exp_ptr = 0;
        repeat (3) @(posedge clk);

        random_test(N_RANDOM);
        high_priority_test();
        fallback_test();
        no_req_test();

        done = 1'b1;
    end

endmodule

module arbiter_qrr_tb;

    logic clk;

    logic done0;
    logic done1;
    logic done2;
    logic done3;

    int err0;
    int err1;
    int err2;
    int err3;

    arbiter_qrr_checker #(
        .N     (1),
        .QOS_W (2),
        .QOS   (2'b11)
    ) U_CHK_N1 (
        .clk    (clk),
        .errors (err0),
        .done   (done0)
    );

    arbiter_qrr_checker #(
        .N     (4),
        .QOS_W (2),
        .QOS   (8'h55)
    ) U_CHK_EQUAL (
        .clk    (clk),
        .errors (err1),
        .done   (done1)
    );

    arbiter_qrr_checker #(
        .N     (4),
        .QOS_W (2),
        .QOS   (8'h2B)
    ) U_CHK_MIX (
        .clk    (clk),
        .errors (err2),
        .done   (done2)
    );

    arbiter_qrr_checker #(
        .N     (4),
        .QOS_W (2),
        .QOS   (8'h22)
    ) U_CHK_PAIR (
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
