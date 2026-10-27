`timescale 1ns/1ps

// bin2ohot 定向 TB：遍历全部输入值，检查输出恰好一位有效
module bin2ohot_tb;
    localparam int W     = 4;
    localparam int OUT_W = 1 << W;

    logic [W-1:0]     bin;
    logic [OUT_W-1:0] ohot;
    logic [OUT_W-1:0] one;
    int               errors = 0;

    bin2ohot #(
        .W (W)
    ) DUT (
        .bin  (bin),
        .ohot (ohot)
    );

    initial begin
        one = OUT_W'(1);

        for (int i = 0; i < (1 << W); i++) begin
            bin = i[W-1:0];
            #1;
            if (ohot !== (one << i)) begin
                errors++;
                $display("FAIL bin=%0d: ohot=%0h exp=%0h", i, ohot, one << i);
            end
            if ($countones(ohot) != 1) begin
                errors++;
                $display("FAIL bin=%0d: not one-hot %0h", i, ohot);
            end
        end

        if (errors == 0) $display("bin2ohot_tb PASS");
        else             $display("bin2ohot_tb FAIL");
        $finish;
    end
endmodule
