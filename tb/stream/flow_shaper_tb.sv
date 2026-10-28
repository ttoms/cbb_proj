`timescale 1ns/1ps

`ifndef TB_INIT
`define TB_INIT 0
`endif

module flow_shaper_tb;

    localparam  int W               =   8           ;
    localparam  int TICK_CYCLES     =   4           ;
    localparam  int TOKENS_PER_TICK =   1           ;
    localparam  int BURST           =   2           ;
    localparam  int INIT_TOKENS     =   `TB_INIT    ;

    logic           clk         ;
    logic           rst_n       ;
    logic           in_vld      ;
    logic           in_rdy      ;
    logic [W -1:0]  in_data     ;
    logic           out_vld     ;
    logic           out_rdy     ;
    logic [W -1:0]  out_data    ;

    int tokens_m    ;
    int tick_cnt_m  ;
    int beat_id     ;
    int errors      ;

    flow_shaper #(
        .W                  (W                  ),
        .TICK_CYCLES        (TICK_CYCLES        ),
        .TOKENS_PER_TICK    (TOKENS_PER_TICK    ),
        .BURST              (BURST              ),
        .INIT_TOKENS        (INIT_TOKENS        )
    ) U_DUT (
        .clk        (clk        ),
        .rst_n      (rst_n      ),
        .in_vld     (in_vld     ),
        .in_rdy     (in_rdy     ),
        .in_data    (in_data    ),
        .out_vld    (out_vld    ),
        .out_rdy    (out_rdy    ),
        .out_data   (out_data   )
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic err(input string msg);
        errors++;
        $display("[%m] FAIL: %s", msg);
    endtask

    initial begin
        logic   tick_m      ;
        int     avail_m     ;
        logic   token_ok_m  ;
        logic   exp_out_vld ;
        logic   exp_in_rdy  ;
        logic   exp_fire    ;

        rst_n     = 1'b0;
        in_vld    = 1'b0;
        in_data   = '0;
        out_rdy   = 1'b0;
        tokens_m  = INIT_TOKENS;
        tick_cnt_m = 0;
        beat_id   = 0;
        errors    = 0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // 复位释放后到循环第一个 negedge 之间还有一个有效 posedge，模型要跟上
        @(posedge clk);
        tick_m  = (tick_cnt_m == TICK_CYCLES - 1);
        avail_m = tokens_m + (tick_m ? TOKENS_PER_TICK : 0);
        if (avail_m > BURST) begin
            avail_m = BURST;
        end
        tokens_m   = avail_m;
        tick_cnt_m = tick_m ? 0 : (tick_cnt_m + 1);

        for (int cyc = 0; cyc < 200; cyc++) begin
            @(negedge clk);
            in_vld  = 1'b1;
            in_data = beat_id[W-1:0];
            out_rdy = $urandom_range(0, 1);
            #1;

            tick_m     = (tick_cnt_m == TICK_CYCLES - 1);
            avail_m    = tokens_m + (tick_m ? TOKENS_PER_TICK : 0);
            if (avail_m > BURST) begin
                avail_m = BURST;
            end
            token_ok_m = (avail_m != 0);

            exp_out_vld = in_vld && token_ok_m;
            exp_in_rdy  = token_ok_m && out_rdy;
            exp_fire    = in_vld && exp_in_rdy;

            if (out_vld !== exp_out_vld) begin
                err($sformatf("out_vld=%0b, exp=%0b, tokens=%0d, tick=%0b",
                              out_vld, exp_out_vld, tokens_m, tick_m));
            end
            if (in_rdy !== exp_in_rdy) begin
                err($sformatf("in_rdy=%0b, exp=%0b, tokens=%0d, out_rdy=%0b",
                              in_rdy, exp_in_rdy, tokens_m, out_rdy));
            end
            if (out_data !== in_data) begin
                err($sformatf("out_data=%0h, in_data=%0h", out_data, in_data));
            end

            @(posedge clk);

            tokens_m   = avail_m - (exp_fire ? 1 : 0);
            tick_cnt_m = tick_m ? 0 : (tick_cnt_m + 1);
            if (exp_fire) begin
                beat_id = beat_id + 1;
            end
        end

        @(negedge clk);
        in_vld  = 1'b0;
        out_rdy = 1'b1;
        #1;
        if (out_vld !== 1'b0) begin
            err("in_vld=0 时 out_vld 应为 0");
        end

        if (errors == 0) begin
            $display("[%m] PASS (INIT_TOKENS=%0d)", INIT_TOKENS);
        end else begin
            $display("[%m] FAIL: %0d errors", errors);
        end
        $finish;
    end

endmodule
