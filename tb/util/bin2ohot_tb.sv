`timescale 1ns/1ps

// bin2ohot 定向 TB：N 路输出（含非 2 的幂），in-range 独热、越界全 0
module bin2ohot_tb;

`ifndef TB_N
`define TB_N 5
`endif

localparam int N     = `TB_N;
localparam int SEL_W = (N > 1) ? $clog2(N) : 1;

logic [SEL_W-1:0] bin;
logic [N-1:0]     ohot;
logic [N-1:0]     one;
int               errors = 0;

bin2ohot #(
    .N (N)
) DUT (
    .bin  (bin),
    .ohot (ohot)
);

initial begin
    one = N'(1);

    for (int i = 0; i < (1 << SEL_W); i++) begin
        bin = i[SEL_W-1:0];
        #1;
        if (i < N) begin
            if (ohot !== (one << i)) begin
                errors++;
                $display("FAIL N=%0d bin=%0d: ohot=%0h exp=%0h",
                         N, i, ohot, one << i);
            end
            if ($countones(ohot) != 1) begin
                errors++;
                $display("FAIL N=%0d bin=%0d: not one-hot %0h", N, i, ohot);
            end
        end else begin
            if (ohot !== '0) begin
                errors++;
                $display("FAIL N=%0d bin=%0d: out-of-range not zero %0h",
                         N, i, ohot);
            end
        end
    end

    if (errors == 0) $display("bin2ohot_tb PASS (N=%0d)", N);
    else             $display("bin2ohot_tb FAIL (N=%0d)", N);
    $finish;
end

endmodule
