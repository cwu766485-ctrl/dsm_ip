// Dual raw-GTH boundary for the two SFP channels in XCZU15EG quad 230.
// The aggregate Wizard interface is ordered {X1Y13, X1Y12}; the word mapping
// below must be verified by the dual known-word loopback before payload use.
module ti64_raw_gt14_dual_sfp_link (
    input  wire        pl_ddr4_clk_n,
    input  wire        pl_ddr4_clk_p,
    input  wire        gty_230_clk_n,
    input  wire        gty_230_clk_p,
    input  wire        sfp0_rx_n,
    input  wire        sfp0_rx_p,
    output wire        sfp0_tx_n,
    output wire        sfp0_tx_p,
    input  wire        sfp1_rx_n,
    input  wire        sfp1_rx_p,
    output wire        sfp1_tx_n,
    output wire        sfp1_tx_p,
    input  wire        reset_n,
    input  wire [63:0] tx_word_sfp0,
    input  wire [63:0] tx_word_sfp1,
    output wire        tx_usrclk2,
    output wire        tx_ready,
    output wire [63:0] rx_word_sfp0,
    output wire [63:0] rx_word_sfp1,
    output wire        rx_usrclk2,
    output wire        rx_ready
);
    wire freerun_clk, gt_refclk, gt_refclk_odiv2_unused;
    wire [0:0] tx_usrclk2_i, tx_active_i, tx_done_i;
    wire [0:0] rx_usrclk2_i, rx_active_i, rx_done_i;
    wire [1:0] gtpowergood_unused, rxpmaresetdone_unused, txpmaresetdone_unused;
    wire [0:0] rxcdrstable_unused, qpll0outclk_unused, qpll0outrefclk_unused;
    wire [127:0] rx_word_i;
    reg [9:0] startup_count = 10'd0;
    wire reset_active;

    IBUFDS u_freerun_clk_ibufds (.I(pl_ddr4_clk_p), .IB(pl_ddr4_clk_n), .O(freerun_clk));
    IBUFDS_GTE4 u_gth_refclk_ibufds (
        .I(gty_230_clk_p), .IB(gty_230_clk_n), .CEB(1'b0),
        .O(gt_refclk), .ODIV2(gt_refclk_odiv2_unused)
    );
    always @(posedge freerun_clk) begin
        if (!reset_n) startup_count <= 10'd0;
        else if (!(&startup_count)) startup_count <= startup_count + 10'd1;
    end
    assign reset_active = !reset_n || !(&startup_count);

    ti64_raw_gt14_dual u_gtwizard (
        .gtwiz_userclk_tx_reset_in({reset_active}),
        .gtwiz_userclk_tx_srcclk_out(), .gtwiz_userclk_tx_usrclk_out(),
        .gtwiz_userclk_tx_usrclk2_out(tx_usrclk2_i), .gtwiz_userclk_tx_active_out(tx_active_i),
        .gtwiz_userclk_rx_reset_in({reset_active}),
        .gtwiz_userclk_rx_srcclk_out(), .gtwiz_userclk_rx_usrclk_out(),
        .gtwiz_userclk_rx_usrclk2_out(rx_usrclk2_i), .gtwiz_userclk_rx_active_out(rx_active_i),
        .gtwiz_reset_clk_freerun_in({freerun_clk}), .gtwiz_reset_all_in({reset_active}),
        .gtwiz_reset_tx_pll_and_datapath_in(1'b0), .gtwiz_reset_tx_datapath_in(1'b0),
        .gtwiz_reset_rx_pll_and_datapath_in(1'b0), .gtwiz_reset_rx_datapath_in(1'b0),
        .gtwiz_reset_rx_cdr_stable_out(rxcdrstable_unused),
        .gtwiz_reset_tx_done_out(tx_done_i), .gtwiz_reset_rx_done_out(rx_done_i),
        .gtwiz_userdata_tx_in({tx_word_sfp1, tx_word_sfp0}), .gtwiz_userdata_rx_out(rx_word_i),
        .gtrefclk00_in({gt_refclk}), .qpll0outclk_out(qpll0outclk_unused),
        .qpll0outrefclk_out(qpll0outrefclk_unused),
        .gthrxn_in({sfp1_rx_n, sfp0_rx_n}), .gthrxp_in({sfp1_rx_p, sfp0_rx_p}),
        .gthtxn_out({sfp1_tx_n, sfp0_tx_n}), .gthtxp_out({sfp1_tx_p, sfp0_tx_p}),
        .gtpowergood_out(gtpowergood_unused), .rxpmaresetdone_out(rxpmaresetdone_unused),
        .txpmaresetdone_out(txpmaresetdone_unused)
    );

    assign tx_usrclk2 = tx_usrclk2_i[0];
    assign rx_usrclk2 = rx_usrclk2_i[0];
    assign tx_ready = tx_active_i[0] & tx_done_i[0] & (&txpmaresetdone_unused);
    assign rx_ready = rx_active_i[0] & rx_done_i[0] & (&rxpmaresetdone_unused);
    assign rx_word_sfp0 = rx_word_i[63:0];
    assign rx_word_sfp1 = rx_word_i[127:64];
endmodule
