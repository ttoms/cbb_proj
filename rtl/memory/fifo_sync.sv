//=============================================================================
// Module      : fifo_sync
// Description : Single-clock synchronous FIFO with valid-ready handshakes.
// Features    : Show-ahead read, full/empty flags, count output, power-of-two depth.
// Parameters  : DATA_W - data width; DEPTH - entries, power of two and >= 2.
// Limitations : Full/empty boundaries are conservative; no almost-full/empty.
//=============================================================================
`default_nettype none

module fifo_sync #(
    parameter   int DATA_W  =   32  ,
    parameter   int DEPTH   =   16
) (
    input   logic                           clk     ,
    input   logic                           rst_n   ,
    input   logic                           wr_vld  ,
    output  logic                           wr_rdy  ,
    input   logic [DATA_W          -1:0]    wr_data ,
    output  logic                           rd_vld  ,
    input   logic                           rd_rdy  ,
    output  logic [DATA_W          -1:0]    rd_data ,
    output  logic                           full    ,
    output  logic                           empty   ,
    output  logic [$clog2(DEPTH+1) -1:0]    count
);

    localparam int PTR_W = $clog2(DEPTH);
    localparam int CNT_W = $clog2(DEPTH + 1);

    logic [DATA_W -1:0] mem     [0:DEPTH-1];
    logic [PTR_W  -1:0] wr_ptr  ;
    logic [PTR_W  -1:0] rd_ptr  ;
    logic [CNT_W  -1:0] count_q ;
    logic               wr_fire ;
    logic               rd_fire ;

    generate
        if (DEPTH < 2 || ((DEPTH & (DEPTH - 1)) != 0)) begin : g_param_check
            $error("fifo_sync: DEPTH must be a power of two and >= 2");
        end
    endgenerate

    assign full    = (count_q == DEPTH);
    assign empty   = (count_q == '0);
    assign wr_rdy  = ~full;
    assign rd_vld  = ~empty;
    assign rd_data = mem[rd_ptr];
    assign count   = count_q;

    assign wr_fire = wr_vld && wr_rdy;
    assign rd_fire = rd_vld && rd_rdy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr  <= '0;
            rd_ptr  <= '0;
            count_q <= '0;
        end else begin
            if (wr_fire) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr      <= wr_ptr + 1'b1;
            end
            if (rd_fire) begin
                rd_ptr <= rd_ptr + 1'b1;
            end

            case ({wr_fire, rd_fire})
                2'b10:   count_q <= count_q + 1'b1;
                2'b01:   count_q <= count_q - 1'b1;
                default: count_q <= count_q;
            endcase
        end
    end

endmodule

`default_nettype wire
