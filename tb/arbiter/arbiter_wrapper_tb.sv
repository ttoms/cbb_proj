`timescale 1ns/1ps
`default_nettype none

module arbiter_wrapper_checker #(
    parameter int                     N        = 4,
    parameter logic [2:0]             ARB_TYPE = 3'b001,
    parameter int                     WEIGHT_W = 2,
    parameter int                     QOS_W    = 2,
    parameter logic [N*WEIGHT_W -1:0] WEIGHTS  = '1,
    parameter logic [N*QOS_W    -1:0] QOS      = '0,
    parameter int                     N_RANDOM = 200
) (
    input  logic clk,
    output int   errors,
    output logic done
);

    localparam logic [2:0] T_FIXED = 3'b000;
    localparam logic [2:0] T_RR    = 3'b001;
    localparam logic [2:0] T_WRR   = 3'b010;
    localparam logic [2:0] T_LRU   = 3'b011;
    localparam logic [2:0] T_QRR   = 3'b100;

    logic                   rst_n   ;
    logic [N -1:0]          req     ;
    logic [N -1:0]          gnt     ;
    logic                   gnt_vld ;
    logic [N*WEIGHT_W -1:0] weight  ;
    logic [N*QOS_W    -1:0] qos     ;

    logic [N -1:0]          ref_gnt     ;
    logic                   ref_gnt_vld ;

    assign weight = WEIGHTS;
    assign qos    = QOS;

    arbiter_wrapper #(
        .N        (N       ),
        .ARB_TYPE (ARB_TYPE),
        .WEIGHT_W (WEIGHT_W),
        .QOS_W    (QOS_W   )
    ) U_DUT (
        .clk     (clk     ),
        .rst_n   (rst_n   ),
        .req     (req     ),
        .weight  (weight  ),
        .qos     (qos     ),
        .gnt     (gnt     ),
        .gnt_vld (gnt_vld )
    );

    // 参考模型直接复用对应仲裁核，wrapper 只负责参数选择与端口统一
    generate
        case (ARB_TYPE)
            T_FIXED: begin : g_ref_fixed
                arbiter_pri #(
                    .N  (N  )
                ) U_REF (
                    .req     (req         ),
                    .gnt     (ref_gnt     ),
                    .gnt_vld (ref_gnt_vld )
                );
            end

            T_RR: begin : g_ref_rr
                arbiter_rr #(
                    .N  (N  )
                ) U_REF (
                    .clk     (clk         ),
                    .rst_n   (rst_n       ),
                    .req     (req         ),
                    .gnt     (ref_gnt     ),
                    .gnt_vld (ref_gnt_vld )
                );
            end

            T_WRR: begin : g_ref_wrr
                arbiter_wrr #(
                    .N        (N       ),
                    .WEIGHT_W (WEIGHT_W)
                ) U_REF (
                    .clk     (clk         ),
                    .rst_n   (rst_n       ),
                    .req     (req         ),
                    .weight  (weight      ),
                    .gnt     (ref_gnt     ),
                    .gnt_vld (ref_gnt_vld )
                );
            end

            T_LRU: begin : g_ref_lru
                arbiter_lru #(
                    .N  (N  )
                ) U_REF (
                    .clk     (clk         ),
                    .rst_n   (rst_n       ),
                    .req     (req         ),
                    .gnt     (ref_gnt     ),
                    .gnt_vld (ref_gnt_vld )
                );
            end

            T_QRR: begin : g_ref_qrr
                arbiter_qrr #(
                    .N      (N    ),
                    .QOS_W  (QOS_W)
                ) U_REF (
                    .clk     (clk         ),
                    .rst_n   (rst_n       ),
                    .req     (req         ),
                    .qos     (qos         ),
                    .gnt     (ref_gnt     ),
                    .gnt_vld (ref_gnt_vld )
                );
            end

            default: begin : g_ref_illegal
                assign ref_gnt     = '0;
                assign ref_gnt_vld = 1'b0;
            end
        endcase
    endgenerate

    task automatic apply_reset;
        rst_n = 1'b0;
        req   = '0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        #1;
    endtask

    task automatic check_grant(input string tag);
        if (gnt !== ref_gnt) begin
            errors++;
            $display("FAIL: type=%b N=%0d %s gnt mismatch got %b exp %b",
                     ARB_TYPE, N, tag, gnt, ref_gnt);
        end
        if (gnt_vld !== ref_gnt_vld) begin
            errors++;
            $display("FAIL: type=%b N=%0d %s gnt_vld mismatch got %b exp %b",
                     ARB_TYPE, N, tag, gnt_vld, ref_gnt_vld);
        end
    endtask

    task automatic random_test(input int cycles);
        apply_reset();

        for (int k = 0; k < cycles; k++) begin
            @(negedge clk);
            req = N'($urandom) & ((N'($urandom_range(0, 99)) < 70) ? {N{1'b1}} : '0);
            #1;
            check_grant("random");
            @(posedge clk);
            #1;
        end

        req = '0;
        #1;
    endtask

    task automatic all_req_test;
        apply_reset();

        for (int k = 0; k < ((2 * N) + 2); k++) begin
            @(negedge clk);
            req = '1;
            #1;
            check_grant("all-req");
            @(posedge clk);
            #1;
        end

        req = '0;
        #1;
    endtask

    task automatic no_req_test;
        apply_reset();

        for (int k = 0; k < 3; k++) begin
            @(negedge clk);
            req = '0;
            #1;
            check_grant("no-req");
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
        all_req_test();
        no_req_test();

        done = 1'b1;
    end

endmodule

module arbiter_wrapper_tb;

`ifndef SVA_ON
    localparam logic HAS_ILLEGAL = 1'b1;
`else
    localparam logic HAS_ILLEGAL = 1'b0;
`endif

    logic           clk     ;
    logic [7:0]     done    ;
    int             err0    ;
    int             err1    ;
    int             err2    ;
    int             err3    ;
    int             err4    ;
    int             err5    ;
    int             err6    ;
    int             err7    ;

    arbiter_wrapper_checker #(
        .N        (4),
        .ARB_TYPE (3'b000)
    ) U_CHK_FIXED4 (
        .clk    (clk    ),
        .errors (err0   ),
        .done   (done[0])
    );

    arbiter_wrapper_checker #(
        .N        (1),
        .ARB_TYPE (3'b000)
    ) U_CHK_FIXED1 (
        .clk    (clk    ),
        .errors (err1   ),
        .done   (done[1])
    );

    arbiter_wrapper_checker #(
        .N        (4),
        .ARB_TYPE (3'b001)
    ) U_CHK_RR4 (
        .clk    (clk    ),
        .errors (err2   ),
        .done   (done[2])
    );

    arbiter_wrapper_checker #(
        .N        (1),
        .ARB_TYPE (3'b001)
    ) U_CHK_RR1 (
        .clk    (clk    ),
        .errors (err3   ),
        .done   (done[3])
    );

    arbiter_wrapper_checker #(
        .N        (4),
        .ARB_TYPE (3'b010),
        .WEIGHTS  (8'h83)
    ) U_CHK_WRR (
        .clk    (clk    ),
        .errors (err4   ),
        .done   (done[4])
    );

    arbiter_wrapper_checker #(
        .N        (4),
        .ARB_TYPE (3'b011)
    ) U_CHK_LRU (
        .clk    (clk    ),
        .errors (err5   ),
        .done   (done[5])
    );

    arbiter_wrapper_checker #(
        .N        (4),
        .ARB_TYPE (3'b100),
        .QOS      (8'h2B)
    ) U_CHK_QRR (
        .clk    (clk    ),
        .errors (err6   ),
        .done   (done[6])
    );

    generate
        if (HAS_ILLEGAL) begin : g_illegal_chk
            arbiter_wrapper_checker #(
                .N        (4),
                .ARB_TYPE (3'b101)
            ) U_CHK_ILLEGAL (
                .clk    (clk    ),
                .errors (err7   ),
                .done   (done[7])
            );
        end
    endgenerate

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        int total;

        wait ((&done[6:0]) && ((!HAS_ILLEGAL) || done[7]));
        repeat (2) @(posedge clk);

        total = err0 + err1 + err2 + err3 + err4 + err5 + err6;
        if (HAS_ILLEGAL) begin
            total = total + err7;
        end

        if (total == 0) begin
            $display("PASS");
        end else begin
            $display("FAIL: %0d errors", total);
        end
        $finish;
    end

endmodule

`default_nettype wire
