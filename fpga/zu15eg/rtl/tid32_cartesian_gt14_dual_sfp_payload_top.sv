// Board payload-smoke top for the timing-closed Cartesian TID32 transmitter.
// SFP0 carries the TID32 64-bit raw-GT user word.  SFP1 remains a distinct
// fixed word to retain the dual-channel ordering check.  The local sample
// generator is deliberately a deterministic bring-up source, not a claim of
// a board-resident 256-QAM OFDM source; the latter must replace it through a
// verified sample-stream interface before RF qualification.
module tid32_cartesian_gt14_dual_sfp_payload_top #(
    parameter USE_ILA = 1
) (
    input wire gty_230_clk_n, input wire gty_230_clk_p,
    input wire pl_ddr4_clk_n, input wire pl_ddr4_clk_p,
    input wire sfp0_rx_n, input wire sfp0_rx_p, output wire sfp0_tx_n, output wire sfp0_tx_p,
    output wire sfp0_tx_disable,
    input wire sfp1_rx_n, input wire sfp1_rx_p, output wire sfp1_tx_n, output wire sfp1_tx_p,
    output wire sfp1_tx_disable
);
    localparam [63:0] KNOWN_WORD_SFP1 = 64'hfedc_ba98_7654_3210;
    wire tx_usrclk2, tx_ready, rx_usrclk2, rx_ready;
    wire [63:0] rx_word_sfp0, rx_word_sfp1;
    wire tid_in_ready, tid_gt_valid;
    wire [63:0] tid_gt_data;
    reg [15:0] sample_phase = 16'd0;
    reg signed [511:0] i_poly, q_poly;
    integer lane;

    always @* begin
        for (lane = 0; lane < 32; lane = lane + 1) begin
            // Different I/Q lane slopes make lane swaps observable in ILA.
            i_poly[lane*16 +: 16] = sample_phase + lane * 16'sd257;
            q_poly[lane*16 +: 16] = ~sample_phase + lane * 16'sd193;
        end
    end
    always @(posedge tx_usrclk2 or negedge tx_ready) begin
        if (!tx_ready) sample_phase <= 16'd0;
        else if (tid_in_ready) sample_phase <= sample_phase + 16'd1;
    end

    tid32_cartesian_fs4_gt_tx u_tid32 (
        .clk(tx_usrclk2), .rst_n(tx_ready), .in_valid(tx_ready), .in_ready(tid_in_ready),
        .in_i_poly_vec(i_poly), .in_q_poly_vec(q_poly),
        .gt_valid(tid_gt_valid), .gt_ready(1'b1), .gt_data(tid_gt_data)
    );
    ti64_raw_gt14_dual_sfp_link u_link (
        .pl_ddr4_clk_n(pl_ddr4_clk_n), .pl_ddr4_clk_p(pl_ddr4_clk_p),
        .gty_230_clk_n(gty_230_clk_n), .gty_230_clk_p(gty_230_clk_p),
        .sfp0_rx_n(sfp0_rx_n), .sfp0_rx_p(sfp0_rx_p), .sfp0_tx_n(sfp0_tx_n), .sfp0_tx_p(sfp0_tx_p),
        .sfp1_rx_n(sfp1_rx_n), .sfp1_rx_p(sfp1_rx_p), .sfp1_tx_n(sfp1_tx_n), .sfp1_tx_p(sfp1_tx_p),
        .reset_n(1'b1), .tx_word_sfp0(tid_gt_data), .tx_word_sfp1(KNOWN_WORD_SFP1),
        .tx_usrclk2(tx_usrclk2), .tx_ready(tx_ready), .rx_word_sfp0(rx_word_sfp0),
        .rx_word_sfp1(rx_word_sfp1), .rx_usrclk2(rx_usrclk2), .rx_ready(rx_ready)
    );
    assign sfp0_tx_disable = ~(tx_ready & tid_gt_valid);
    assign sfp1_tx_disable = ~tx_ready;
    generate
      if (USE_ILA) begin : g_ila
        (* mark_debug = "true" *) wire [63:0] debug_rx_word_sfp0 = rx_word_sfp0;
        (* mark_debug = "true" *) wire [63:0] debug_rx_word_sfp1 = rx_word_sfp1;
        (* mark_debug = "true" *) wire debug_rx_ready = rx_ready;
        (* mark_debug = "true" *) wire debug_tid_valid = tid_gt_valid;
        ila_ti64_raw_gt14_dual_loopback u_rx_ila (
            .clk(rx_usrclk2), .probe0(debug_rx_word_sfp0), .probe1(debug_rx_word_sfp1),
            .probe2(debug_rx_ready), .probe3(debug_tid_valid)
        );
      end
    endgenerate
endmodule
