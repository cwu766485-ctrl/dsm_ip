// Board top for an end-to-end Cartesian x4 / TI64 / raw-GTH exercise.
//
// The internal source is intentionally deterministic bring-up stimulus, not a
// host-data interface.  It proves that the 16-lane source-rate frontend clocks
// on TXUSRCLK2 and directly drives the generated 64-bit raw-GTH user boundary.
// Replace this source only after defining the ingress clock/CDC contract.
module ti64_raw_gt14_sfp0_x4_top (
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
    wire tx_usrclk2;
    wire tx_ready;
    wire [63:0] tx_word;
    wire [63:0] rx_word;
    wire rx_usrclk2;
    wire rx_ready;
    wire frontend_in_ready;
    wire frontend_gt_valid;
    reg signed [255:0] source_i_vec = '0;
    reg signed [255:0] source_q_vec = '0;
    reg [15:0] source_sample_index = 16'd0;

    // Keep bypass/memoryless-poly selection available at the DPD boundary.
    // Unity coefficients select the same numerical signal in either mode.
    wire signed [15:0] c1_re = 16'sd16384;
    wire signed [15:0] c1_im = 16'sd0;
    wire signed [15:0] c3_re = 16'sd0;
    wire signed [15:0] c3_im = 16'sd0;
    wire signed [15:0] c5_re = 16'sd0;
    wire signed [15:0] c5_im = 16'sd0;
    wire signed [15:0] c7_re = 16'sd0;
    wire signed [15:0] c7_im = 16'sd0;

    // Each source vector represents 16 ordered complex samples.  The values
    // are deliberately bounded and asymmetric so loopback captures are not a
    // constant or trivially periodic GT word.
    always @(posedge tx_usrclk2) begin : p_source
        integer lane;
        if (!tx_ready) begin
            source_i_vec <= '0;
            source_q_vec <= '0;
            source_sample_index <= 16'd0;
        end else if (frontend_in_ready) begin
            for (lane = 0; lane < 16; lane = lane + 1) begin
                source_i_vec[lane*16 +: 16] <=
                    $signed({1'b0, source_sample_index}) + lane * 29 - 4096;
                source_q_vec[lane*16 +: 16] <=
                    $signed({1'b0, source_sample_index}) + lane * 47 - 3072;
            end
            source_sample_index <= source_sample_index + 16'd16;
        end
    end

    ti64_cartesian_x4_frontend_tx #(.W(16), .ACC_W(28)) u_frontend (
        .clk(tx_usrclk2), .rst_n(tx_ready),
        .in_valid(tx_ready), .in_ready(frontend_in_ready),
        .in_i_vec(source_i_vec), .in_q_vec(source_q_vec),
        .dpd_mode(2'd0),
        .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
        .c5_re(c5_re), .c5_im(c5_im), .c7_re(c7_re), .c7_im(c7_im),
        .dpd_effective_mode(),
        .gt_valid(frontend_gt_valid), .gt_ready(tx_ready), .gt_data(tx_word)
    );

    ti64_raw_gt14_sfp0_link u_link (
        .pl_ddr4_clk_n(pl_ddr4_clk_n), .pl_ddr4_clk_p(pl_ddr4_clk_p),
        .gty_230_clk_n(gty_230_clk_n), .gty_230_clk_p(gty_230_clk_p),
        .sfp0_rx_n(sfp0_rx_n), .sfp0_rx_p(sfp0_rx_p),
        .sfp0_tx_n(sfp0_tx_n), .sfp0_tx_p(sfp0_tx_p), .reset_n(1'b1),
        .tx_word(tx_word), .tx_usrclk2(tx_usrclk2), .tx_ready(tx_ready),
        .rx_word(rx_word), .rx_usrclk2(rx_usrclk2), .rx_ready(rx_ready)
    );

    assign sfp0_tx_disable = ~tx_ready;

    (* mark_debug = "true" *) wire [63:0] debug_rx_word = rx_word;
    (* mark_debug = "true" *) wire [63:0] debug_tx_word = tx_word;
    (* mark_debug = "true" *) wire debug_rx_ready = rx_ready;
    (* mark_debug = "true" *) wire debug_tx_ready = tx_ready;
    (* mark_debug = "true" *) wire debug_frontend_gt_valid = frontend_gt_valid;

    ila_ti64_raw_gt14_x4 u_rx_ila (
        .clk(rx_usrclk2),
        .probe0(debug_rx_word), .probe1(debug_tx_word), .probe2(debug_rx_ready),
        .probe3(debug_tx_ready), .probe4(debug_frontend_gt_valid)
    );
endmodule
