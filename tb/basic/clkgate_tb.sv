`timescale 1ns/1ps
`default_nettype none

module clkgate_checker #(
    parameter int IDLE_CYCLES = 4
) (
    input  logic clk,
    output int   errors,
    output logic done
);

    logic   rst_n   ;
    logic   wakeup  ;
    logic   idle    ;
    logic   gclk    ;
    logic   active  ;

    int     rise_cnt   ;
    int     glitch_cnt ;
    int     r0         ;

    clkgate #(
        .IDLE_CYCLES (IDLE_CYCLES)
    ) U_DUT (
        .clk    (clk    ),
        .rst_n  (rst_n  ),
        .wakeup (wakeup ),
        .idle   (idle   ),
        .gclk   (gclk   ),
        .active (active )
    );

    initial begin
        rise_cnt   = 0;
        glitch_cnt = 0;
    end

    // gclk 上升沿计数，用于确认门控窗口内时钟完全停止
    always @(posedge gclk) begin
        rise_cnt <= rise_cnt + 1'b1;
    end

    // 无毛刺检查：gclk 高电平必须完整落在 clk 高电平内
    always @(gclk) begin
        if ((gclk === 1'b1) && (clk !== 1'b1)) begin
            glitch_cnt = glitch_cnt + 1;
        end
    end

    task automatic apply_reset;
        rst_n  = 1'b0;
        wakeup = 1'b0;
        idle   = 1'b0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        #1;
    endtask

    task automatic expect_flag(input logic cond, input string msg);
        if (cond !== 1'b1) begin
            errors++;
            $display("FAIL: IDLE_CYCLES=%0d %s", IDLE_CYCLES, msg);
        end
    endtask

    task automatic reset_test;
        apply_reset();

        expect_flag(active === 1'b1, "active must be 1 after reset");
        r0 = rise_cnt;
        repeat (3) @(posedge clk);
        #1;
        if ((rise_cnt - r0) != 3) begin
            errors++;
            $display("FAIL: IDLE_CYCLES=%0d clock not running after reset, rises=%0d",
                     IDLE_CYCLES, rise_cnt - r0);
        end
        expect_flag(gclk === 1'b1, "gclk must be high in clk high phase");
    endtask

    task automatic gating_test;
        apply_reset();

        @(negedge clk);
        idle = 1'b1;
        repeat (IDLE_CYCLES) @(posedge clk);
        #1;
        expect_flag(active === 1'b0, "active must drop after IDLE_CYCLES idle cycles");

        @(negedge clk);
        #1;
        expect_flag(gclk === 1'b0, "gclk must stop after gating");

        r0 = rise_cnt;
        repeat (5) @(posedge clk);
        #1;
        if ((rise_cnt - r0) != 0) begin
            errors++;
            $display("FAIL: IDLE_CYCLES=%0d gclk still toggling while gated, rises=%0d",
                     IDLE_CYCLES, rise_cnt - r0);
        end
        expect_flag(gclk === 1'b0, "gclk must stay low while gated");
    endtask

    task automatic wakeup_test;
        @(negedge clk);
        wakeup = 1'b1;
        idle   = 1'b1;
        repeat (2) @(posedge clk);
        #1;
        expect_flag(active === 1'b1, "wakeup must enable the clock");
        expect_flag(gclk === 1'b1, "gclk must resume after wakeup");

        r0 = rise_cnt;
        @(negedge clk);
        wakeup = 1'b0;
        idle   = 1'b0;
        repeat (3) @(posedge clk);
        #1;
        if ((rise_cnt - r0) != 3) begin
            errors++;
            $display("FAIL: IDLE_CYCLES=%0d clock not running after wakeup, rises=%0d",
                     IDLE_CYCLES, rise_cnt - r0);
        end
        expect_flag(active === 1'b1, "idle low must keep the clock enabled");
    endtask

    task automatic hysteresis_test;
        apply_reset();

        @(negedge clk);
        idle = 1'b1;
        repeat (IDLE_CYCLES - 1) @(posedge clk);
        @(negedge clk);
        idle = 1'b0;
        #1;
        expect_flag(active === 1'b1, "short idle window must not gate the clock");

        r0 = rise_cnt;
        repeat (2) @(posedge clk);
        #1;
        if ((rise_cnt - r0) != 2) begin
            errors++;
            $display("FAIL: IDLE_CYCLES=%0d clock stopped after short idle, rises=%0d",
                     IDLE_CYCLES, rise_cnt - r0);
        end
    endtask

    initial begin
        errors = 0;
        done   = 1'b0;
        rst_n  = 1'b1;
        wakeup = 1'b0;
        idle   = 1'b0;
        #1;
        rst_n  = 1'b0;
        repeat (3) @(posedge clk);

        reset_test();
        gating_test();
        wakeup_test();
        if (IDLE_CYCLES > 1) begin
            hysteresis_test();
        end

        if (glitch_cnt != 0) begin
            errors++;
            $display("FAIL: IDLE_CYCLES=%0d detected %0d gclk glitches",
                     IDLE_CYCLES, glitch_cnt);
        end

        done = 1'b1;
    end

endmodule

module clkgate_tb;

    logic           clk     ;
    logic [2:0]     done    ;
    int             err0    ;
    int             err1    ;
    int             err2    ;

    clkgate_checker #(
        .IDLE_CYCLES (1)
    ) U_CHK_1 (
        .clk    (clk    ),
        .errors (err0   ),
        .done   (done[0])
    );

    clkgate_checker #(
        .IDLE_CYCLES (4)
    ) U_CHK_4 (
        .clk    (clk    ),
        .errors (err1   ),
        .done   (done[1])
    );

    clkgate_checker #(
        .IDLE_CYCLES (8)
    ) U_CHK_8 (
        .clk    (clk    ),
        .errors (err2   ),
        .done   (done[2])
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        wait (&done);
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
