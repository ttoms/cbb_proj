`timescale 1ns/1ps

module fifo_sync_tb;

    localparam int DATA_W = 8;
    localparam int DEPTH  = 2;
    localparam int PTR_W  = $clog2(DEPTH);

    logic               clk     ;
    logic               rst_n   ;
    logic               wr_vld  ;
    logic               wr_rdy  ;
    logic [DATA_W -1:0] wr_data ;
    logic               rd_vld  ;
    logic               rd_rdy  ;
    logic [DATA_W -1:0] rd_data ;
    logic               empty   ;
    logic               full    ;

    logic [DATA_W-1:0] exp_q[$];
    int exp_wr_ptr;
    int exp_rd_ptr;
    int errors;

    fifo_sync #(
        .DATA_W (DATA_W ),
        .DEPTH  (DEPTH  )
    ) U_DUT (
        .clk        (clk        ),
        .rst_n      (rst_n      ),
        .wr_vld     (wr_vld     ),
        .wr_rdy     (wr_rdy     ),
        .wr_data    (wr_data    ),
        .rd_vld     (rd_vld     ),
        .rd_rdy     (rd_rdy     ),
        .rd_data    (rd_data    ),
        .empty      (empty      ),
        .full       (full       )
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic err(input string msg);
        errors++;
        $display("[%m] FAIL: %s", msg);
    endtask

    task automatic cycle(
        input logic             we,
        input logic [DATA_W-1:0] wd,
        input logic             rr
    );
        logic wr_fire_t;
        logic rd_fire_t;
        int   pre_size;

        @(negedge clk);
        wr_vld  = we;
        wr_data = wd;
        rd_rdy  = rr;

        #1;
        pre_size = exp_q.size();

        if (empty !== (pre_size == 0)) begin
            err($sformatf("empty=%0b, exp_q.size=%0d", empty, pre_size));
        end
        if (full !== (pre_size == DEPTH)) begin
            err($sformatf("full=%0b, exp_q.size=%0d", full, pre_size));
        end
        if (wr_rdy !== (pre_size != DEPTH)) begin
            err($sformatf("wr_rdy=%0b, exp_q.size=%0d", wr_rdy, pre_size));
        end
        if (rd_vld !== (pre_size != 0)) begin
            err($sformatf("rd_vld=%0b, exp_q.size=%0d", rd_vld, pre_size));
        end
        if (rd_vld && (rd_data !== exp_q[0])) begin
            err($sformatf("rd_data=%0h, exp=%0h", rd_data, exp_q[0]));
        end

        wr_fire_t = wr_vld && wr_rdy;
        rd_fire_t = rd_vld && rd_rdy;

        @(posedge clk);
        if (rd_fire_t) begin
            exp_q.delete(0);
            exp_rd_ptr = (exp_rd_ptr + 1) % DEPTH;
        end
        if (wr_fire_t) begin
            exp_q.push_back(wd);
            exp_wr_ptr = (exp_wr_ptr + 1) % DEPTH;
        end
        if (wr_fire_t && rd_fire_t && (exp_q.size() != pre_size)) begin
            err("同拍读写后条目数发生变化");
        end

        #1;
        if (U_DUT.wr_ptr !== exp_wr_ptr[PTR_W-1:0]) begin
            err($sformatf("wr_ptr=%0d, exp=%0d", U_DUT.wr_ptr, exp_wr_ptr));
        end
        if (U_DUT.rd_ptr !== exp_rd_ptr[PTR_W-1:0]) begin
            err($sformatf("rd_ptr=%0d, exp=%0d", U_DUT.rd_ptr, exp_rd_ptr));
        end
    endtask

    initial begin
        rst_n      = 1'b0;
        wr_vld     = 1'b0;
        wr_data    = '0;
        rd_rdy     = 1'b0;
        exp_wr_ptr = 0;
        exp_rd_ptr = 0;
        errors     = 0;
        exp_q.delete();

        #2;
        if (empty !== 1'b1) err("复位后 empty 应为 1");
        if (full !== 1'b0)  err("复位后 full 应为 0");
        if (rd_vld !== 1'b0) err("复位后 rd_vld 应为 0");
        if (wr_rdy !== 1'b1) err("复位后 wr_rdy 应为 1");

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        cycle(1'b1, 8'hA1, 1'b0);
        cycle(1'b1, 8'hA2, 1'b0);
        cycle(1'b1, 8'hA9, 1'b0);
        cycle(1'b0, 8'h00, 1'b1);
        cycle(1'b1, 8'hA3, 1'b0);
        cycle(1'b0, 8'h00, 1'b1);
        cycle(1'b1, 8'hA4, 1'b1);
        cycle(1'b0, 8'h00, 1'b1);
        cycle(1'b0, 8'h00, 1'b0);

        if (errors == 0) begin
            $display("[%m] PASS");
        end else begin
            $display("[%m] FAIL, errors=%0d", errors);
            $fatal(1, "[%m] fifo_sync_tb failed");
        end
        $finish;
    end

endmodule
