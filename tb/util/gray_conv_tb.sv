`timescale 1ns/1ps

// gray_conv 定向 TB：bin2gray 全遍历、gray2bin 全遍历、往返一致、位宽边界
module gray_conv_tb;
    localparam int W = 4;

    logic [W-1:0] bin_in   ;
    logic [W-1:0] gray_out ;
    logic [W-1:0] gray_in  ;
    logic [W-1:0] bin_out  ;

    logic [0:0]   bin_1    ;
    logic [0:0]   gray_1   ;

    int           errors = 0;

    gray_conv #(
        .W    (W   ),
        .MODE (1'b0)
    ) DUT_B2G (
        .din  (bin_in  ),
        .dout (gray_out)
    );

    gray_conv #(
        .W    (W   ),
        .MODE (1'b1)
    ) DUT_G2B (
        .din  (gray_in ),
        .dout (bin_out)
    );

    gray_conv #(
        .W    (1   ),
        .MODE (1'b0)
    ) DUT_W1_B2G (
        .din  (bin_1 ),
        .dout (gray_1)
    );

    function automatic logic [W-1:0] g2b_ref(input logic [W-1:0] g);
        logic [W-1:0] b;

        b[W-1] = g[W-1];
        for (int i = W - 2; i >= 0; i--) begin
            b[i] = b[i+1] ^ g[i];
        end
        return b;
    endfunction

    initial begin
        // bin2gray 全遍历
        for (int v = 0; v < 16; v++) begin
            bin_in = W'(v);
            #1;
            if (gray_out !== W'(v ^ (v >> 1))) begin
                errors++;
                $display("FAIL bin2gray %0d: got %0d exp %0d",
                         v, gray_out, v ^ (v >> 1));
            end
        end

        // gray2bin 全遍历
        for (int v = 0; v < 16; v++) begin
            gray_in = W'(v);
            #1;
            if (bin_out !== g2b_ref(W'(v))) begin
                errors++;
                $display("FAIL gray2bin %0d: got %0d exp %0d",
                         v, bin_out, g2b_ref(W'(v)));
            end
        end

        // 往返一致：gray2bin(bin2gray(x)) == x
        for (int v = 0; v < 16; v++) begin
            bin_in  = W'(v);
            #1;
            gray_in = gray_out;
            #1;
            if (bin_out !== W'(v)) begin
                errors++;
                $display("FAIL round-trip %0d: got %0d exp %0d", v, bin_out, v);
            end
        end

        // W=1 边界
        bin_1 = 1'b0;
        #1;
        if (gray_1 !== 1'b0) begin
            errors++;
            $display("FAIL W=1 zero: got %0b", gray_1);
        end
        bin_1 = 1'b1;
        #1;
        if (gray_1 !== 1'b1) begin
            errors++;
            $display("FAIL W=1 one: got %0b", gray_1);
        end

        if (errors == 0) $display("gray_conv_tb PASS");
        else             $display("gray_conv_tb FAIL");
        $finish;
    end
endmodule
