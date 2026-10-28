`timescale 1ns/1ps

module width_conv_bypass_tb;

    localparam int W = 16;

    logic           clk         ;
    logic           rst_n       ;
    logic           in_vld      ;
    logic           in_rdy      ;
    logic [W -1:0]  in_data     ;
    logic           in_keep     ;
    logic           in_last     ;
    logic           out_vld     ;
    logic           out_rdy     ;
    logic [W -1:0]  out_data    ;
    logic           out_keep    ;
    logic           out_last    ;

    int errors;

    width_conv #(
        .IN_W   (W  ),
        .OUT_W  (W  )
    ) U_DUT (
        .clk        (clk        ),
        .rst_n      (rst_n      ),
        .in_vld     (in_vld     ),
        .in_rdy     (in_rdy     ),
        .in_data    (in_data    ),
        .in_keep    (in_keep    ),
        .in_last    (in_last    ),
        .out_vld    (out_vld    ),
        .out_rdy    (out_rdy    ),
        .out_data   (out_data   ),
        .out_keep   (out_keep   ),
        .out_last   (out_last   )
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n   = 1'b0;
        in_vld  = 1'b0;
        in_data = '0;
        in_keep = 1'b1;
        in_last = 1'b0;
        out_rdy = 1'b0;
        errors  = 0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        for (int cyc = 0; cyc < 200; cyc++) begin
            @(negedge clk);
            in_vld  = $urandom_range(0, 1);
            in_data = $urandom;
            in_last = $urandom_range(0, 1);
            out_rdy = $urandom_range(0, 1);
            #1;

            if (out_vld !== in_vld) begin
                errors++;
                $display("[%m] FAIL: out_vld=%0b, in_vld=%0b", out_vld, in_vld);
            end
            if (in_rdy !== out_rdy) begin
                errors++;
                $display("[%m] FAIL: in_rdy=%0b, out_rdy=%0b", in_rdy, out_rdy);
            end
            if (out_data !== in_data) begin
                errors++;
                $display("[%m] FAIL: out_data=%0h, in_data=%0h", out_data, in_data);
            end
            if (out_keep !== 1'b1) begin
                errors++;
                $display("[%m] FAIL: out_keep=%0b, exp=1", out_keep);
            end
            if (out_last !== in_last) begin
                errors++;
                $display("[%m] FAIL: out_last=%0b, in_last=%0b", out_last, in_last);
            end
        end

        if (errors == 0) begin
            $display("[%m] PASS");
        end else begin
            $display("[%m] FAIL: %0d errors", errors);
        end
        $finish;
    end

endmodule
