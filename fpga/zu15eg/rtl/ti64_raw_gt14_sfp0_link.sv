// Board-specific raw-GTH boundary for the XCZU15EG SFP0 channel.
//
// The 64-bit TX word is consumed on tx_usrclk2 (218.75 MHz).  Logical DSM
// lane 0 must be connected to tx_word[0].  Raw-GTH serialization direction
// is a hardware-verified property: use the loopback top before depending on
// physical bit order in a system integration.
module ti64_raw_gt14_sfp0_link (
    input  wire        pl_ddr4_clk_n,
    input  wire        pl_ddr4_clk_p,
    input  wire        gty_230_clk_n,
    input  wire        gty_230_clk_p,
    input  wire        sfp0_rx_n,
    input  wire        sfp0_rx_p,
    output wire        sfp0_tx_n,
    output wire        sfp0_tx_p,
    input  wire        reset_n,
    input  wire [63:0] tx_word,
    output wire        tx_usrclk2,
    output wire        tx_ready,
    output wire [63:0] rx_word,
    output wire        rx_usrclk2,
    output wire        rx_ready
);

    wire freerun_clk;
    wire gt_refclk;
    wire gt_refclk_odiv2_unused;
    wire [0:0] tx_usrclk2_i;
    wire [0:0] tx_active_i;
    wire [0:0] tx_done_i;
    wire [0:0] rx_usrclk2_i;
    wire [0:0] rx_active_i;
    wire [0:0] rx_done_i;
    wire [0:0] rx_word_i_unused;
    wire [0:0] qpll0outclk_unused;
    wire [0:0] qpll0outrefclk_unused;
    wire [0:0] gtpowergood_unused;
    wire [0:0] rxpmaresetdone_unused;
    wire [0:0] txpmaresetdone_unused;
    wire [0:0] rxcdrstable_unused;
    reg [9:0] startup_count = 10'd0;
    wire reset_active;

    // The board's PL_DDR4 clock is a documented 200 MHz differential clock.
    // It is the always-running reset-controller clock selected in the Wizard.
    IBUFDS u_freerun_clk_ibufds (
        .I  (pl_ddr4_clk_p),
        .IB (pl_ddr4_clk_n),
        .O  (freerun_clk)
    );

    // GTH refclk 0 of quad 230.  The GT pin constraints are in the companion
    // XDC; no fabric create_clock is applied to this dedicated GT reference.
    IBUFDS_GTE4 u_gth_refclk_ibufds (
        .I     (gty_230_clk_p),
        .IB    (gty_230_clk_n),
        .CEB   (1'b0),
        .O     (gt_refclk),
        .ODIV2 (gt_refclk_odiv2_unused)
    );

    // Synchronously release reset only after the 200 MHz freerun clock has
    // been present for 1024 cycles.  An external low reset restarts the hold.
    always @(posedge freerun_clk) begin
        if (!reset_n)
            startup_count <= 10'd0;
        else if (!(&startup_count))
            startup_count <= startup_count + 10'd1;
    end
    assign reset_active = !reset_n || !(&startup_count);

    ti64_raw_gt14 u_gtwizard (
        .gtwiz_userclk_tx_reset_in          ({reset_active}),
        .gtwiz_userclk_tx_srcclk_out        (),
        .gtwiz_userclk_tx_usrclk_out        (),
        .gtwiz_userclk_tx_usrclk2_out       (tx_usrclk2_i),
        .gtwiz_userclk_tx_active_out        (tx_active_i),
        .gtwiz_userclk_rx_reset_in          ({reset_active}),
        .gtwiz_userclk_rx_srcclk_out        (),
        .gtwiz_userclk_rx_usrclk_out        (),
        .gtwiz_userclk_rx_usrclk2_out       (rx_usrclk2_i),
        .gtwiz_userclk_rx_active_out        (rx_active_i),
        .gtwiz_reset_clk_freerun_in         ({freerun_clk}),
        .gtwiz_reset_all_in                 ({reset_active}),
        .gtwiz_reset_tx_pll_and_datapath_in (1'b0),
        .gtwiz_reset_tx_datapath_in         (1'b0),
        .gtwiz_reset_rx_pll_and_datapath_in (1'b0),
        .gtwiz_reset_rx_datapath_in         (1'b0),
        .gtwiz_reset_rx_cdr_stable_out      (rxcdrstable_unused),
        .gtwiz_reset_tx_done_out            (tx_done_i),
        .gtwiz_reset_rx_done_out            (rx_done_i),
        .gtwiz_userdata_tx_in               (tx_word),
        .gtwiz_userdata_rx_out              (rx_word),
        .gtrefclk00_in                      ({gt_refclk}),
        .qpll0outclk_out                    (qpll0outclk_unused),
        .qpll0outrefclk_out                 (qpll0outrefclk_unused),
        .gthrxn_in                          ({sfp0_rx_n}),
        .gthrxp_in                          ({sfp0_rx_p}),
        .gthtxn_out                         ({sfp0_tx_n}),
        .gthtxp_out                         ({sfp0_tx_p}),
        .gtpowergood_out                    (gtpowergood_unused),
        .rxpmaresetdone_out                 (rxpmaresetdone_unused),
        .txpmaresetdone_out                 (txpmaresetdone_unused)
    );

    assign tx_usrclk2 = tx_usrclk2_i[0];
    assign tx_ready   = tx_active_i[0] & tx_done_i[0];
    assign rx_usrclk2 = rx_usrclk2_i[0];
    assign rx_ready   = rx_active_i[0] & rx_done_i[0];

endmodule
