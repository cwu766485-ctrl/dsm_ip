// Dual-SFP known-word loopback top. SFP0 and SFP1 use different static words
// so ILA observation proves channel ordering as well as per-channel bit order.
module ti64_raw_gt14_dual_sfp_loopback_top (
    input  wire gty_230_clk_n,
    input  wire gty_230_clk_p,
    input  wire pl_ddr4_clk_n,
    input  wire pl_ddr4_clk_p,
    input  wire sfp0_rx_n,
    input  wire sfp0_rx_p,
    output wire sfp0_tx_n,
    output wire sfp0_tx_p,
    output wire sfp0_tx_disable,
    input  wire sfp1_rx_n,
    input  wire sfp1_rx_p,
    output wire sfp1_tx_n,
    output wire sfp1_tx_p,
    output wire sfp1_tx_disable
);
    localparam [63:0] KNOWN_WORD_SFP0 = 64'h0123_4567_89ab_cdef;
    localparam [63:0] KNOWN_WORD_SFP1 = 64'hfedc_ba98_7654_3210;
    wire tx_usrclk2, tx_ready, rx_usrclk2, rx_ready;
    wire [63:0] rx_word_sfp0, rx_word_sfp1;
    (* ASYNC_REG = "TRUE" *) reg [1:0] tx_ready_rx_sync = 2'b00;

    ti64_raw_gt14_dual_sfp_link u_link (
        .pl_ddr4_clk_n(pl_ddr4_clk_n), .pl_ddr4_clk_p(pl_ddr4_clk_p),
        .gty_230_clk_n(gty_230_clk_n), .gty_230_clk_p(gty_230_clk_p),
        .sfp0_rx_n(sfp0_rx_n), .sfp0_rx_p(sfp0_rx_p), .sfp0_tx_n(sfp0_tx_n), .sfp0_tx_p(sfp0_tx_p),
        .sfp1_rx_n(sfp1_rx_n), .sfp1_rx_p(sfp1_rx_p), .sfp1_tx_n(sfp1_tx_n), .sfp1_tx_p(sfp1_tx_p),
        .reset_n(1'b1), .tx_word_sfp0(KNOWN_WORD_SFP0), .tx_word_sfp1(KNOWN_WORD_SFP1),
        .tx_usrclk2(tx_usrclk2), .tx_ready(tx_ready),
        .rx_word_sfp0(rx_word_sfp0), .rx_word_sfp1(rx_word_sfp1),
        .rx_usrclk2(rx_usrclk2), .rx_ready(rx_ready)
    );

    assign sfp0_tx_disable = ~tx_ready;
    assign sfp1_tx_disable = ~tx_ready;

    // TXUSRCLK2 and RXUSRCLK2 are distinct GTH clock domains.  ILA is in
    // RXUSRCLK2, so observe TX readiness only after an explicit two-flop CDC.
    always @(posedge rx_usrclk2) begin
        tx_ready_rx_sync <= {tx_ready_rx_sync[0], tx_ready};
    end

    (* mark_debug = "true" *) wire [63:0] debug_rx_word_sfp0 = rx_word_sfp0;
    (* mark_debug = "true" *) wire [63:0] debug_rx_word_sfp1 = rx_word_sfp1;
    (* mark_debug = "true" *) wire        debug_rx_ready = rx_ready;
    (* mark_debug = "true" *) wire        debug_tx_ready = tx_ready_rx_sync[1];

    ila_ti64_raw_gt14_dual_loopback u_rx_ila (
        .clk(rx_usrclk2), .probe0(debug_rx_word_sfp0), .probe1(debug_rx_word_sfp1),
        .probe2(debug_rx_ready), .probe3(debug_tx_ready)
    );
endmodule
