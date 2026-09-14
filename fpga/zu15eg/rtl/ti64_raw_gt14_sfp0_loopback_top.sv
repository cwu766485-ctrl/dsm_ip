// Raw-GTH known-word loopback top.  It is intentionally separate from the
// DSM transmit integration: this design establishes GTH reset, clocking, pin
// mapping and recovered raw-word observability before payload integration.
module ti64_raw_gt14_sfp0_loopback_top (
    input  wire gty_230_clk_n,
    input  wire gty_230_clk_p,
    input  wire pl_ddr4_clk_n,
    input  wire pl_ddr4_clk_p,
    input  wire sfp0_rx_n,
    input  wire sfp0_rx_p,
    output wire sfp0_tx_n,
    output wire sfp0_tx_p,
    output wire sfp0_tx_disable
);

    localparam [63:0] KNOWN_WORD = 64'h0123_4567_89ab_cdef;

    wire tx_usrclk2;
    wire tx_ready;
    wire [63:0] rx_word;
    wire rx_usrclk2;
    wire rx_ready;

    ti64_raw_gt14_sfp0_link u_link (
        .pl_ddr4_clk_n (pl_ddr4_clk_n),
        .pl_ddr4_clk_p (pl_ddr4_clk_p),
        .gty_230_clk_n (gty_230_clk_n),
        .gty_230_clk_p (gty_230_clk_p),
        .sfp0_rx_n      (sfp0_rx_n),
        .sfp0_rx_p      (sfp0_rx_p),
        .sfp0_tx_n      (sfp0_tx_n),
        .sfp0_tx_p      (sfp0_tx_p),
        .reset_n        (1'b1),
        .tx_word        (KNOWN_WORD),
        .tx_usrclk2     (tx_usrclk2),
        .tx_ready       (tx_ready),
        .rx_word        (rx_word),
        .rx_usrclk2     (rx_usrclk2),
        .rx_ready       (rx_ready)
    );

    // Active-high on this board.  Keep the optical transmitter disabled
    // until the Wizard declares its TX datapath ready.
    assign sfp0_tx_disable = ~tx_ready;

    // Retain direct hardware-observation points.  The build script attaches
    // an ILA clocked by rx_usrclk2 and probes the recovered raw word.
    (* mark_debug = "true" *) wire [63:0] debug_rx_word = rx_word;
    (* mark_debug = "true" *) wire        debug_rx_ready = rx_ready;
    (* mark_debug = "true" *) wire        debug_tx_ready = tx_ready;
    (* mark_debug = "true" *) wire        debug_tx_usrclk2 = tx_usrclk2;

    ila_ti64_raw_gt14_loopback u_rx_ila (
        .clk    (rx_usrclk2),
        .probe0 (debug_rx_word),
        .probe1 (debug_rx_ready),
        .probe2 (debug_tx_ready)
    );

endmodule
