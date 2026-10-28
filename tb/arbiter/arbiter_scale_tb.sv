`timescale 1ns/1ps

// 规模测试：N=64/128 下检查 one-hot、公平性、QoS 分组与固定优先级
module arbiter_scale_tb;

`ifndef TB_N
`define TB_N 64
`endif
`ifndef TB_CYCLES
`define TB_CYCLES (4*`TB_N)
`endif

localparam int N = `TB_N;
localparam int W = 2;

logic          clk = 1'b0;
logic          rst_n = 1'b0;
logic [N-1:0]  req;
logic [N-1:0]  gnt_pri, gnt_rr, gnt_wrr, gnt_lru, gnt_qrr;
logic          vld_pri, vld_rr, vld_wrr, vld_lru, vld_qrr;
logic [N*W-1:0] weight, qos;

int cnt_rr[N], cnt_wrr[N], cnt_lru[N], cnt_qrr[N];
int errors = 0;
int cyc, i;
int n;
int sum1_rr, sum2_rr, sum1_wrr, sum2_wrr, sum1_lru, sum2_lru, sum1_qrr;

always #5 clk = ~clk;

arbiter_pri #(.N(N)) U_PRI (
    .req(req), .gnt(gnt_pri), .gnt_vld(vld_pri));

arbiter_rr #(.N(N)) U_RR (
    .clk(clk), .rst_n(rst_n), .upd(1'b1), .req(req),
    .gnt(gnt_rr), .gnt_vld(vld_rr));

arbiter_wrr #(.N(N), .WEIGHT_W(W)) U_WRR (
    .clk(clk), .rst_n(rst_n), .upd(1'b1), .req(req), .weight(weight),
    .gnt(gnt_wrr), .gnt_vld(vld_wrr));

arbiter_lru #(.N(N)) U_LRU (
    .clk(clk), .rst_n(rst_n), .upd(1'b1), .req(req),
    .gnt(gnt_lru), .gnt_vld(vld_lru));

arbiter_qrr #(.N(N), .QOS_W(W)) U_QRR (
    .clk(clk), .rst_n(rst_n), .upd(1'b1), .req(req), .qos(qos),
    .gnt(gnt_qrr), .gnt_vld(vld_qrr));

task automatic chk(input logic [N-1:0] g, input logic v, input string name);
    n = 0;
    for (int k = 0; k < N; k++) if (g[k]) n++;
    if (v !== (n != 0)) begin
        errors++;
        $display("%s: vld=%0b but %0d grant bits", name, v, n);
    end
    if (n > 1) begin
        errors++;
        $display("%s: multi-hot grant", name);
    end
endtask

initial begin
    for (i = 0; i < N; i++) begin
        weight[i*W +: W] = (i < N/2) ? 2'd2 : 2'd1;
        qos[i*W +: W]    = (i < N/2) ? 2'd2 : 2'd1;
        cnt_rr[i]  = 0;
        cnt_wrr[i] = 0;
        cnt_lru[i] = 0;
        cnt_qrr[i] = 0;
    end

    req = '1;
    repeat (3) @(negedge clk);
    rst_n = 1'b1;

    for (cyc = 0; cyc < `TB_CYCLES; cyc++) begin
        @(negedge clk);
        chk(gnt_pri, vld_pri, "pri");
        chk(gnt_rr,  vld_rr,  "rr");
        chk(gnt_wrr, vld_wrr, "wrr");
        chk(gnt_lru, vld_lru, "lru");
        chk(gnt_qrr, vld_qrr, "qrr");

        if (gnt_pri !== N'(1)) begin
            errors++;
            $display("pri: expected bit0, got %b", gnt_pri);
        end

        for (i = 0; i < N; i++) begin
            if (gnt_rr[i])  cnt_rr[i]++;
            if (gnt_wrr[i]) cnt_wrr[i]++;
            if (gnt_lru[i]) cnt_lru[i]++;
            if (gnt_qrr[i]) cnt_qrr[i]++;
        end
    end

    sum1_rr = 0; sum2_rr = 0;
    sum1_wrr = 0; sum2_wrr = 0;
    sum1_lru = 0; sum2_lru = 0;
    sum1_qrr = 0;
    for (i = 0; i < N; i++) begin
        if (i < N/2) begin
            sum1_rr  += cnt_rr[i];
            sum1_wrr += cnt_wrr[i];
            sum1_lru += cnt_lru[i];
            sum1_qrr += cnt_qrr[i];
        end else begin
            sum2_rr  += cnt_rr[i];
            sum2_wrr += cnt_wrr[i];
            sum2_lru += cnt_lru[i];
            if (cnt_qrr[i] != 0) begin
                errors++;
                $display("qrr: low-QoS channel %0d granted %0d", i, cnt_qrr[i]);
            end
        end
    end

    // RR/LRU：每个通道都应被服务到
    for (i = 0; i < N; i++) begin
        if (cnt_rr[i] == 0)  begin errors++; $display("rr: channel %0d starved", i); end
        if (cnt_lru[i] == 0) begin errors++; $display("lru: channel %0d starved", i); end
    end

    // WRR：前半权重 2、后半权重 1，前组总授权应约为后组两倍
    if (!(sum1_wrr > sum2_wrr && sum1_wrr < 3*sum2_wrr)) begin
        errors++;
        $display("wrr: first-half=%0d second-half=%0d", sum1_wrr, sum2_wrr);
    end

    $display("N=%0d cycles=%0d", N, `TB_CYCLES);
    $display("RR  half: %0d / %0d", sum1_rr, sum2_rr);
    $display("WRR half: %0d / %0d", sum1_wrr, sum2_wrr);
    $display("LRU half: %0d / %0d", sum1_lru, sum2_lru);
    $display("QRR high sum: %0d", sum1_qrr);
    if (errors == 0) $display("[%m] PASS (N=%0d)", N);
    else             $display("[%m] FAIL errors=%0d (N=%0d)", errors, N);
    $finish;
end

endmodule
