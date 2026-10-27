//=============================================================================
// Module      : counter
// Description : Parameterized up/down counter with load and saturate/wrap.
// Features    : Async reset, load priority, enable, direction, saturation mode.
// Parameters  : W - counter width; SATURATE - 1 holds at bounds, 0 wraps.
// Limitations : Single clock; load wins over enable.
//=============================================================================
`default_nettype none

module counter #(
    parameter   int W           =   8       ,
    parameter   bit SATURATE    =   1'b0
) (
    input   logic           clk         ,
    input   logic           rst_n       ,
    input   logic           en          ,
    input   logic           load        ,
    input   logic           up          ,
    input   logic [W -1:0]  load_val    ,
    output  logic [W -1:0]  count
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;
        end else if (load) begin
            count <= load_val;
        end else if (en) begin
            if (up) begin
                if (count == {W{1'b1}}) begin
                    if (!SATURATE) begin
                        count <= '0;
                    end
                end else begin
                    count <= count + 1'b1;
                end
            end else begin
                if (count == '0) begin
                    if (!SATURATE) begin
                        count <= {W{1'b1}};
                    end
                end else begin
                    count <= count - 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
