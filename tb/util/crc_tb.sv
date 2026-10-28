`timescale 1ns/1ps

`ifndef TB_CRC_W
`define TB_CRC_W 32
`endif
`ifndef TB_POLY
`define TB_POLY 32'h04C11DB7
`endif
`ifndef TB_INIT
`define TB_INIT 32'hFFFF_FFFF
`endif
`ifndef TB_XOROUT
`define TB_XOROUT 32'hFFFF_FFFF
`endif
`ifndef TB_REFIN
`define TB_REFIN 1
`endif
`ifndef TB_REFOUT
`define TB_REFOUT 1
`endif
`ifndef TB_DATA_W
`define TB_DATA_W 8
`endif
`ifndef TB_CHECK
`define TB_CHECK 32'hCBF43926
`endif

module crc_tb;

    localparam  int                 CRC_W   =   `TB_CRC_W   ;
    localparam  logic [CRC_W-1:0]   POLY    =   `TB_POLY    ;
    localparam  logic [CRC_W-1:0]   INIT    =   `TB_INIT    ;
    localparam  logic [CRC_W-1:0]   XOROUT  =   `TB_XOROUT  ;
    localparam  bit                 REFIN   =   `TB_REFIN   ;
    localparam  bit                 REFOUT  =   `TB_REFOUT  ;
    localparam  int                 DATA_W  =   `TB_DATA_W  ;
    localparam  logic [CRC_W-1:0]   CHECK   =   `TB_CHECK   ;

    logic               clk     ;
    logic               rst_n   ;
    logic               init    ;
    logic               en      ;
    logic [DATA_W -1:0] data    ;
    logic [CRC_W  -1:0] crc_out ;

    int errors;

    crc #(
        .CRC_W  (CRC_W  ),
        .POLY   (POLY   ),
        .INIT   (INIT   ),
        .XOROUT (XOROUT ),
        .REFIN  (REFIN  ),
        .REFOUT (REFOUT ),
        .DATA_W (DATA_W )
    ) U_DUT (
        .clk        (clk        ),
        .rst_n      (rst_n      ),
        .init       (init       ),
        .en         (en         ),
        .data       (data       ),
        .crc_out    (crc_out    )
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic step_byte(input logic [7:0] b);
        if (DATA_W == 1) begin
            for (int i = 0; i < 8; i++) begin
                @(negedge clk);
                init = 1'b0;
                en   = 1'b1;
                data = REFIN ? b[i] : b[7-i];
                @(posedge clk);
            end
        end else begin
            @(negedge clk);
            init = 1'b0;
            en   = 1'b1;
            data = DATA_W'(b);
            @(posedge clk);
        end
    endtask

    task automatic do_init;
        @(negedge clk);
        init = 1'b1;
        en   = 1'b0;
        data = '0;
        @(posedge clk);
    endtask

    initial begin
        rst_n  = 1'b0;
        init   = 1'b0;
        en     = 1'b0;
        data   = '0;
        errors = 0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // 先制造一些状态，再 init，验证 init 优先级与清状态
        step_byte(8'hAA);
        do_init();

        // 标准校验字符串 "123456789"
        step_byte(8'h31);
        step_byte(8'h32);
        step_byte(8'h33);
        step_byte(8'h34);
        step_byte(8'h35);
        step_byte(8'h36);
        step_byte(8'h37);
        step_byte(8'h38);
        step_byte(8'h39);

        @(negedge clk);
        en   = 1'b0;
        init = 1'b0;
        #1;

        if (crc_out !== CHECK) begin
            errors++;
            $display("[%m] FAIL: crc_out=%0h, exp=%0h", crc_out, CHECK);
        end

        if (errors == 0) begin
            $display("[%m] PASS (CRC_W=%0d DATA_W=%0d REFIN=%0b REFOUT=%0b)",
                     CRC_W, DATA_W, REFIN, REFOUT);
        end else begin
            $display("[%m] FAIL: %0d errors", errors);
        end
        $finish;
    end

endmodule
