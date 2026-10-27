`timescale 1ns/1ps
`default_nettype none

module reg_slice_checker #(
    parameter int         W        = 8,
    parameter logic [1:0] RS_MODE  = 2'b11,
    parameter int         N_RANDOM = 400
) (
    input  logic clk,
    output int   errors,
    output logic done
);

    logic               rst_n;
    logic               in_vld;
    logic               in_rdy;
    logic [W -1:0]      in_data;
    logic               out_vld;
    logic               out_rdy;
    logic [W -1:0]      out_data;

    int                 exp_q [$];

    reg_slice #(
        .W       (W),
        .RS_MODE (RS_MODE)
    ) U_DUT (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_vld   (in_vld),
        .in_rdy   (in_rdy),
        .in_data  (in_data),
        .out_vld  (out_vld),
        .out_rdy  (out_rdy),
        .out_data (out_data)
    );

    task automatic drive_idle;
        in_vld  = 1'b0;
        in_data = '0;
        out_rdy = 1'b0;
    endtask

    task automatic apply_reset;
        rst_n = 1'b0;
        drive_idle();
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        #1;
    endtask

    task automatic latency_test;
        apply_reset();

        @(negedge clk);
        in_vld  = 1'b1;
        in_data = 8'hA5;
        out_rdy = 1'b1;
        #1;

        if (!in_rdy) begin
            errors++;
            $display("FAIL: mode %b in_rdy low when empty", RS_MODE);
        end
        if ((RS_MODE == 2'b00) || (RS_MODE == 2'b10)) begin
            if (!out_vld) begin
                errors++;
                $display("FAIL: mode %b zero-latency out_vld missing", RS_MODE);
            end
            if (out_data !== 8'hA5) begin
                errors++;
                $display("FAIL: mode %b zero-latency data mismatch", RS_MODE);
            end
        end else begin
            if (out_vld) begin
                errors++;
                $display("FAIL: mode %b early out_vld", RS_MODE);
            end
        end

        @(posedge clk);
        #1;
        in_vld = 1'b0;
        @(negedge clk);
        #1;

        if ((RS_MODE == 2'b00) || (RS_MODE == 2'b10)) begin
            if (out_vld) begin
                errors++;
                $display("FAIL: mode %b output not consumed", RS_MODE);
            end
        end else begin
            if (!out_vld) begin
                errors++;
                $display("FAIL: mode %b one-cycle output missing", RS_MODE);
            end
            if (out_data !== 8'hA5) begin
                errors++;
                $display("FAIL: mode %b one-cycle data mismatch", RS_MODE);
            end
        end

        @(posedge clk);
        @(negedge clk);
        #1;
        if (out_vld) begin
            errors++;
            $display("FAIL: mode %b out_vld did not drain", RS_MODE);
        end

        out_rdy = 1'b0;
        #1;
    endtask

    task automatic random_test(input int cycles);
        int unsigned e;
        logic        in_fire;
        logic        out_fire;
        logic        same_cycle;
        logic        drain_done;

        apply_reset();
        exp_q.delete();

        for (int k = 0; k < cycles; k++) begin
            @(negedge clk);
            in_vld  = ($urandom_range(0, 99) < 70);
            in_data = W'($urandom);
            out_rdy = ($urandom_range(0, 99) < 70);
            #1;

            in_fire    = in_vld & in_rdy;
            out_fire   = out_vld & out_rdy;
            same_cycle = 1'b0;

            if (out_fire) begin
                if (exp_q.size() > 0) begin
                    e = exp_q.pop_front();
                    if (int'(out_data) != e) begin
                        errors++;
                        $display("FAIL: mode %b data mismatch got %0d exp %0d",
                                 RS_MODE, out_data, e);
                    end
                end else if (((RS_MODE == 2'b00) || (RS_MODE == 2'b10)) && in_fire) begin
                    if (int'(out_data) != int'(in_data)) begin
                        errors++;
                        $display("FAIL: mode %b same-cycle data mismatch", RS_MODE);
                    end
                    same_cycle = 1'b1;
                end else begin
                    errors++;
                    $display("FAIL: mode %b unexpected out_vld", RS_MODE);
                end
            end

            if (in_fire && !same_cycle) begin
                exp_q.push_back(int'(in_data));
            end

            @(posedge clk);
        end

        #1;
        in_vld  = 1'b0;
        out_rdy = 1'b1;

        drain_done = 1'b0;
        for (int k = 0; (k < 16) && !drain_done; k++) begin
            @(negedge clk);
            #1;
            out_fire = out_vld & out_rdy;
            if (out_fire) begin
                if (exp_q.size() == 0) begin
                    errors++;
                    $display("FAIL: mode %b unexpected drain output", RS_MODE);
                end else begin
                    e = exp_q.pop_front();
                    if (int'(out_data) != e) begin
                        errors++;
                        $display("FAIL: mode %b drain data mismatch", RS_MODE);
                    end
                end
            end
            @(posedge clk);
            drain_done = (exp_q.size() == 0) && !out_vld;
        end

        if (exp_q.size() != 0) begin
            errors++;
            $display("FAIL: mode %b lost %0d items", RS_MODE, exp_q.size());
        end
        if (out_vld) begin
            errors++;
            $display("FAIL: mode %b out_vld stuck after drain", RS_MODE);
        end

        drive_idle();
        #1;
    endtask

    initial begin
        errors = 0;
        done   = 1'b0;
        drive_idle();
        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        latency_test();
        random_test(N_RANDOM);
        done = 1'b1;
    end

endmodule

module reg_slice_tb;

    logic clk;

    logic done0;
    logic done1;
    logic done2;
    logic done3;

    int err0;
    int err1;
    int err2;
    int err3;

    reg_slice_checker #(
        .W       (8),
        .RS_MODE (2'b00)
    ) U_CHK_BYPASS (
        .clk    (clk),
        .errors (err0),
        .done   (done0)
    );

    reg_slice_checker #(
        .W       (8),
        .RS_MODE (2'b01)
    ) U_CHK_FORWARD (
        .clk    (clk),
        .errors (err1),
        .done   (done1)
    );

    reg_slice_checker #(
        .W       (8),
        .RS_MODE (2'b10)
    ) U_CHK_BACKWARD (
        .clk    (clk),
        .errors (err2),
        .done   (done2)
    );

    reg_slice_checker #(
        .W       (8),
        .RS_MODE (2'b11)
    ) U_CHK_FULL (
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
