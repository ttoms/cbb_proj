//=============================================================================
// Module      : reg_slice
// Description : Configurable valid-ready register slice.
// Features    : RS_MODE selects bypass, forward, backward or full slice.
// Parameters  : W - data width; RS_MODE - 2-bit slice mode.
// Limitations : Single clock; no packet boundary handling; no width conversion.
//=============================================================================
`default_nettype none

module reg_slice #(
    parameter   int         W       =   32      ,
    parameter   logic [1:0] RS_MODE =   2'b11
) (
    input   logic           clk         ,
    input   logic           rst_n       ,
    input   logic           in_vld      ,
    output  logic           in_rdy      ,
    input   logic [W -1:0]  in_data     ,
    output  logic           out_vld     ,
    input   logic           out_rdy     ,
    output  logic [W -1:0]  out_data
);

    localparam logic [1:0] RS_BYPASS   = 2'b00;
    localparam logic [1:0] RS_FORWARD  = 2'b01;
    localparam logic [1:0] RS_BACKWARD = 2'b10;

    generate
        case (RS_MODE)
            RS_BYPASS: begin : g_bypass
                assign out_vld  = in_vld;
                assign out_data = in_data;
                assign in_rdy   = out_rdy;
            end

            RS_FORWARD: begin : g_forward
                logic           vld_q       ;
                logic [W -1:0]  data_q      ;
                logic           in_fire     ;
                logic           out_fire    ;
                logic           vld_nxt     ;
                logic           vld_en      ;

                assign in_rdy   = ~vld_q | out_rdy;
                assign out_vld  = vld_q;
                assign out_data = data_q;
                assign in_fire  = in_vld & in_rdy;
                assign out_fire = vld_q & out_rdy;
                assign vld_nxt  = in_fire ? 1'b1 : (out_fire ? 1'b0 : vld_q);
                assign vld_en   = in_fire | out_fire;

                dffr #(
                    .W  (1  )
                ) U_VLD (
                    .clk    (clk        ),
                    .rst_n  (rst_n      ),
                    .en     (vld_en     ),
                    .d      (vld_nxt    ),
                    .q      (vld_q      )
                );

                dff #(
                    .W  (W  )
                ) U_DATA (
                    .clk    (clk        ),
                    .en     (in_fire    ),
                    .d      (in_data    ),
                    .q      (data_q     )
                );
            end

            RS_BACKWARD: begin : g_backward
                logic           skid_vld        ;
                logic [W -1:0]  skid_data       ;
                logic           in_fire         ;
                logic           out_fire        ;
                logic           cap             ;
                logic           skid_vld_nxt    ;
                logic           skid_en         ;

                assign out_vld      = in_vld | skid_vld;
                assign out_data     = skid_vld ? skid_data : in_data;
                assign in_rdy       = ~skid_vld;
                assign in_fire      = in_vld & in_rdy;
                assign out_fire     = out_vld & out_rdy;
                assign cap          = in_fire & ~out_rdy;
                assign skid_vld_nxt = cap ? 1'b1
                                          : ((out_fire & skid_vld) ? 1'b0 : skid_vld);
                assign skid_en      = cap | (out_fire & skid_vld);

                dffr #(
                    .W  (1  )
                ) U_SKID_VLD (
                    .clk    (clk            ),
                    .rst_n  (rst_n          ),
                    .en     (skid_en        ),
                    .d      (skid_vld_nxt   ),
                    .q      (skid_vld       )
                );

                dff #(
                    .W  (W  )
                ) U_SKID_DATA (
                    .clk    (clk        ),
                    .en     (cap        ),
                    .d      (in_data    ),
                    .q      (skid_data  )
                );
            end

            default: begin : g_full
                logic [1   :0]  entry_vld   ;
                logic           wr_ptr      ;
                logic           rd_ptr      ;
                logic [W -1:0]  mem0        ;
                logic [W -1:0]  mem1        ;
                logic           full        ;
                logic           empty       ;
                logic           wr_en       ;
                logic           rd_en       ;
                logic [1   :0]  entry_nxt   ;
                logic [1   :0]  wr_mask     ;
                logic [1   :0]  rd_mask     ;
                logic           entry_en    ;
                logic           wr_ptr_nxt  ;
                logic           rd_ptr_nxt  ;
                logic           mem0_en     ;
                logic           mem1_en     ;

                assign full       = &entry_vld;
                assign empty      = ~|entry_vld;
                assign in_rdy     = ~full;
                assign out_vld    = ~empty;
                assign out_data   = rd_ptr ? mem1 : mem0;
                assign wr_en      = in_vld & in_rdy;
                assign rd_en      = out_vld & out_rdy;
                assign wr_mask    = wr_en ? (wr_ptr ? 2'b10 : 2'b01) : 2'b00;
                assign rd_mask    = rd_en ? (rd_ptr ? 2'b10 : 2'b01) : 2'b00;
                assign entry_nxt  = (entry_vld & ~rd_mask) | wr_mask;
                assign entry_en   = wr_en | rd_en;
                assign wr_ptr_nxt = ~wr_ptr;
                assign rd_ptr_nxt = ~rd_ptr;
                assign mem0_en    = wr_en & ~wr_ptr;
                assign mem1_en    = wr_en & wr_ptr;

                dffr #(
                    .W  (2  )
                ) U_ENTRY_VLD (
                    .clk    (clk        ),
                    .rst_n  (rst_n      ),
                    .en     (entry_en   ),
                    .d      (entry_nxt  ),
                    .q      (entry_vld  )
                );

                dffr #(
                    .W  (1  )
                ) U_WR_PTR (
                    .clk    (clk        ),
                    .rst_n  (rst_n      ),
                    .en     (wr_en      ),
                    .d      (wr_ptr_nxt ),
                    .q      (wr_ptr     )
                );

                dffr #(
                    .W  (1  )
                ) U_RD_PTR (
                    .clk    (clk        ),
                    .rst_n  (rst_n      ),
                    .en     (rd_en      ),
                    .d      (rd_ptr_nxt ),
                    .q      (rd_ptr     )
                );

                dff #(
                    .W  (W  )
                ) U_MEM0 (
                    .clk    (clk        ),
                    .en     (mem0_en    ),
                    .d      (in_data    ),
                    .q      (mem0       )
                );

                dff #(
                    .W  (W  )
                ) U_MEM1 (
                    .clk    (clk        ),
                    .en     (mem1_en    ),
                    .d      (in_data    ),
                    .q      (mem1       )
                );
            end
        endcase
    endgenerate

`ifdef SVA_ON
`include "reg_slice.sva"
`endif

endmodule

`default_nettype wire
