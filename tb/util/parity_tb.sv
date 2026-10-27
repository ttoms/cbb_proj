`timescale 1ns/1ps

// parity 定向 TB：偶/奇校验生成、匹配/不匹配检查、W=1 边界
module parity_tb;
    localparam int W = 8;

    logic [W-1:0] data_e     ;
    logic         din_par_e  ;
    logic         par_e      ;
    logic         err_e      ;

    logic [W-1:0] data_o     ;
    logic         din_par_o  ;
    logic         par_o      ;
    logic         err_o      ;

    logic [0:0]   data_1     ;
    logic         din_par_1  ;
    logic         par_1      ;
    logic         err_1      ;

    int           errors = 0;
    logic         exp_par    ;
    logic         exp_err    ;

    parity #(
        .W    (W   ),
        .MODE (1'b0)
    ) DUT_EVEN (
        .data        (data_e    ),
        .data_parity (din_par_e ),
        .parity_bit  (par_e     ),
        .err         (err_e     )
    );

    parity #(
        .W    (W   ),
        .MODE (1'b1)
    ) DUT_ODD (
        .data        (data_o    ),
        .data_parity (din_par_o ),
        .parity_bit  (par_o     ),
        .err         (err_o     )
    );

    parity #(
        .W    (1   ),
        .MODE (1'b0)
    ) DUT_W1 (
        .data        (data_1    ),
        .data_parity (din_par_1 ),
        .parity_bit  (par_1     ),
        .err         (err_1     )
    );

    task automatic check_even(input logic [W-1:0] d,
                              input logic         p,
                              input string        msg);
        data_e    = d;
        din_par_e = p;
        #1;
        exp_par = ^d;
        exp_err = (^d) ^ p;
        if (par_e !== exp_par || err_e !== exp_err) begin
            errors++;
            $display("FAIL even %s: data=%h p=%0b par=%0b/%0b err=%0b/%0b",
                     msg, d, p, par_e, exp_par, err_e, exp_err);
        end
    endtask

    task automatic check_odd(input logic [W-1:0] d,
                             input logic         p,
                             input string        msg);
        data_o    = d;
        din_par_o = p;
        #1;
        exp_par = ^d ^ 1'b1;
        exp_err = (^d) ^ p ^ 1'b1;
        if (par_o !== exp_par || err_o !== exp_err) begin
            errors++;
            $display("FAIL odd %s: data=%h p=%0b par=%0b/%0b err=%0b/%0b",
                     msg, d, p, par_o, exp_par, err_o, exp_err);
        end
    endtask

    initial begin
        // 偶数个 1 的数据
        check_even(8'h00, 1'b0, "all-zero");
        check_even(8'h03, 1'b0, "two ones");
        check_even(8'hFF, 1'b0, "eight ones");
        // 奇数个 1 的数据
        check_even(8'h01, 1'b1, "one one");
        check_even(8'h07, 1'b1, "three ones");
        check_even(8'hAA, 1'b0, "four ones");
        // 错误注入
        check_even(8'h01, 1'b0, "even mismatch");
        check_even(8'h03, 1'b1, "even mismatch 2");

        check_odd(8'h00, 1'b1, "all-zero");
        check_odd(8'h03, 1'b1, "two ones");
        check_odd(8'hFF, 1'b1, "eight ones");
        check_odd(8'h01, 1'b0, "one one");
        check_odd(8'h07, 1'b0, "three ones");
        check_odd(8'h01, 1'b1, "odd mismatch");
        check_odd(8'h03, 1'b0, "odd mismatch 2");

        // W=1：只校验生成公式与检查结果
        din_par_1 = 1'b0;
        data_1 = 1'b0;
        #1;
        if (par_1 !== 1'b0 || err_1 !== 1'b0) begin
            errors++;
            $display("FAIL W=1 data 0: par=%0b err=%0b", par_1, err_1);
        end
        data_1 = 1'b1;
        #1;
        if (par_1 !== 1'b1 || err_1 !== 1'b1) begin
            errors++;
            $display("FAIL W=1 data 1: par=%0b err=%0b", par_1, err_1);
        end

        if (errors == 0) $display("parity_tb PASS");
        else             $display("parity_tb FAIL");
        $finish;
    end
endmodule
