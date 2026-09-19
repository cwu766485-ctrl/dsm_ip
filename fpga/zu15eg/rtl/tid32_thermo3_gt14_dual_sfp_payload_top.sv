// Dual-SFP GTH payload target for the three-level Cartesian TID transmitter.
// SFP0/SFP1 carry the two equal-weight thermometer code planes. Their raw
// words are advanced together by the payload wrapper; the physical PA combiner
// must preserve phase alignment and equal amplitude. The local source is a
// deterministic lane-distinct smoke generator, not an OFDM feeder.
module tid32_thermo3_gt14_dual_sfp_payload_top (
    input wire gty_230_clk_n, input wire gty_230_clk_p,
    input wire pl_ddr4_clk_n, input wire pl_ddr4_clk_p,
    input wire sfp0_rx_n, input wire sfp0_rx_p, output wire sfp0_tx_n, output wire sfp0_tx_p,
    output wire sfp0_tx_disable,
    input wire sfp1_rx_n, input wire sfp1_rx_p, output wire sfp1_tx_n, output wire sfp1_tx_p,
    output wire sfp1_tx_disable
);
    wire tx_usrclk2, tx_ready, rx_usrclk2, rx_ready;
    wire [63:0] rx_word_sfp0, rx_word_sfp1;
    wire tid_in_ready, pa_p_valid, pa_m_valid;
    wire [63:0] pa_p_data, pa_m_data;
    reg [15:0] sample_phase = 16'd0;
    reg signed [511:0] i_poly, q_poly;
    integer lane;

    always @* begin
        for (lane = 0; lane < 32; lane = lane + 1) begin
            i_poly[lane*16 +: 16] = sample_phase + lane * 16'sd257;
            q_poly[lane*16 +: 16] = ~sample_phase + lane * 16'sd193;
        end
    end
    always @(posedge tx_usrclk2 or negedge tx_ready) begin
        if (!tx_ready) sample_phase <= 16'd0;
        else if (tid_in_ready) sample_phase <= sample_phase + 16'd1;
    end

    tid32_thermo3_fs4_multipa_tx #(.W(16), .CHANNELS(32), .THRESHOLD(8192)) u_tid32_thermo3 (
        .clk(tx_usrclk2), .rst_n(tx_ready), .in_valid(tx_ready), .in_ready(tid_in_ready),
        .in_i_poly_vec(i_poly), .in_q_poly_vec(q_poly),
        .pa_p_valid(pa_p_valid), .pa_p_data(pa_p_data), .pa_p_ready(1'b1),
        .pa_m_valid(pa_m_valid), .pa_m_data(pa_m_data), .pa_m_ready(1'b1)
    );

    ti64_raw_gt14_dual_sfp_link u_link (
        .pl_ddr4_clk_n(pl_ddr4_clk_n), .pl_ddr4_clk_p(pl_ddr4_clk_p),
        .gty_230_clk_n(gty_230_clk_n), .gty_230_clk_p(gty_230_clk_p),
        .sfp0_rx_n(sfp0_rx_n), .sfp0_rx_p(sfp0_rx_p), .sfp0_tx_n(sfp0_tx_n), .sfp0_tx_p(sfp0_tx_p),
        .sfp1_rx_n(sfp1_rx_n), .sfp1_rx_p(sfp1_rx_p), .sfp1_tx_n(sfp1_tx_n), .sfp1_tx_p(sfp1_tx_p),
        .reset_n(1'b1), .tx_word_sfp0(pa_p_data), .tx_word_sfp1(pa_m_data),
        .tx_usrclk2(tx_usrclk2), .tx_ready(tx_ready), .rx_word_sfp0(rx_word_sfp0),
        .rx_word_sfp1(rx_word_sfp1), .rx_usrclk2(rx_usrclk2), .rx_ready(rx_ready)
    );
    assign sfp0_tx_disable = ~(tx_ready & pa_p_valid);
    assign sfp1_tx_disable = ~(tx_ready & pa_m_valid);
endmodule
