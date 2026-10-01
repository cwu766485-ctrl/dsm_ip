`timescale 1ns/1ps
`default_nettype none

// Multi-clock integration wrapper for the two-plane thermometric frontend.
// 125 MHz AXI-S carries fourteen contiguous complex samples; the XPM FIFO and
// exact 14:8 gearbox supply the existing 218.75 MHz / eight-complex core.
// The DPD interface is present and intended to run identity coefficients
// until an independently qualified calibration is available.
module tid32_thermo3_axis_frontend_tx #(
  parameter int W = 16,
  parameter int GAIN_W = 16,
  parameter int THRESHOLD = 8192,
  parameter int DPD_MAX_TAPS = 4,
  parameter int INTERP_TAPS = 4,
  parameter bit FPGA_USE_XPM_FIFO = 1'b1,
  parameter bit ENABLE_LOW_POWER_CTRL = 1'b0,
  parameter int LP_PREFILL_WORDS = 4
) (
  input  wire logic                            s_axis_aclk,
  input  wire logic                            s_axis_aresetn,
  input  wire logic                            s_axis_tvalid,
  output wire logic                            s_axis_tready,
  input  wire logic signed [14*W-1:0]          s_axis_i_vec,
  input  wire logic signed [14*W-1:0]          s_axis_q_vec,
  input  wire logic                            s_axis_tuser_frame_start,
  input  wire logic signed [GAIN_W-1:0]        s_axis_tuser_frame_gain,
  output wire logic                            s_axis_fifo_full,

  input  wire logic                            core_clk,
  input  wire logic                            core_aresetn,
  input  wire logic                            core_enable,
  output wire logic                            core_underflow,
  output wire logic                            core_protocol_error,
  input  wire logic [2:0]                      dpd_active_taps,
  input  wire logic signed [63:0]              c1_re, c1_im, c3_re, c3_im, c5_re, c5_im,
  output wire logic                            pa_p_valid,
  output wire logic [63:0]                     pa_p_data,
  input  wire logic                            pa_p_ready,
  output wire logic                            pa_m_valid,
  output wire logic [63:0]                     pa_m_data,
  input  wire logic                            pa_m_ready
);
  logic core_valid, core_ready, core_frame_start;
  logic signed [8*W-1:0] core_i_vec, core_q_vec;
  logic signed [GAIN_W-1:0] core_frame_gain;
  logic gain_valid, gain_ready;
  logic signed [8*W-1:0] gain_i_vec, gain_q_vec;
  logic datapath_enable;
  logic lp_datapath_enable;
  logic [2:0] lp_state;
  logic [7:0] lp_outstanding;
  logic lp_ingress_enable, cdc_s_ready, cdc_s_valid;
  // LP control is deliberately consumed at registered stage boundaries.  The
  // CDC/AXI ready path remains identical to baseline; only the two local
  // datapath stages stop between complete transactions.
  logic gain_enable_q, frontend_enable_q;

  // In low-power mode the source may enter only after run_request has crossed
  // into the AXI domain.  This prevents idle traffic from filling the FIFO
  // behind a stopped recursive datapath.  Baseline handshake is unchanged.
  assign s_axis_tready = cdc_s_ready &&
                         (!ENABLE_LOW_POWER_CTRL || lp_ingress_enable);
  // Ready and valid must be gated as one AXI ingress firewall.  Gating only
  // external ready would let a source-held valid beat enter the internal FIFO
  // repeatedly while the controller is idle or synchronizing run_request.
  assign cdc_s_valid = s_axis_tvalid &&
                       (!ENABLE_LOW_POWER_CTRL || lp_ingress_enable);

  generate
    if (ENABLE_LOW_POWER_CTRL) begin : g_low_power
      dsm_frame_power_ctrl #(.PREFILL_WORDS(LP_PREFILL_WORDS)) u_power_ctrl (
        .s_clk(s_axis_aclk), .s_rst_n(s_axis_aresetn),
        .s_accept(s_axis_tvalid && s_axis_tready), .run_request(core_enable),
        .core_clk(core_clk), .core_rst_n(core_aresetn),
        .core_accept(core_valid && core_ready),
        .output_accept(pa_p_valid && pa_p_ready && pa_m_valid && pa_m_ready),
        .core_input_valid(core_valid), .output_valid(pa_p_valid || pa_m_valid),
        .core_activity_enable(lp_datapath_enable), .power_state(lp_state),
        .ingress_enable(lp_ingress_enable),
        .outstanding_words(lp_outstanding)
      );
    end else begin : g_baseline_power
      assign datapath_enable = core_enable;
      assign lp_ingress_enable = 1'b1;
      assign lp_state = 3'd3;
      assign lp_outstanding = '0;
    end
  endgenerate
  // Keep the CDC/gearbox running through DRAIN.  lp_datapath_enable falls only
  // after accepted words and all visible pipeline data have left the block.
  if (ENABLE_LOW_POWER_CTRL) begin : g_lp_timing_safe
    assign datapath_enable = lp_datapath_enable;
  end

  generate
    if (ENABLE_LOW_POWER_CTRL) begin : g_lp_local_ce
      always_ff @(posedge core_clk or negedge core_aresetn) begin
        if (!core_aresetn) begin
          gain_enable_q     <= 1'b0;
          frontend_enable_q <= 1'b0;
        end else begin
          // lp_datapath_enable is generated synchronously in core_clk.
          // Registering at each boundary prevents it becoming a wide
          // combinational CE net.  The baseline path is not retimed.
          gain_enable_q     <= lp_datapath_enable;
          frontend_enable_q <= lp_datapath_enable;
        end
      end
    end else begin : g_baseline_local_ce
      assign gain_enable_q     = core_enable;
      assign frontend_enable_q = core_enable;
    end
  endgenerate

  dsm_axis14_to_core8_cdc #(.W(W), .GAIN_W(GAIN_W), .USE_XPM_FIFO(FPGA_USE_XPM_FIFO)) u_cdc (
    .s_axis_aclk(s_axis_aclk), .s_axis_aresetn(s_axis_aresetn),
    .s_axis_tvalid(cdc_s_valid), .s_axis_tready(cdc_s_ready),
    .s_axis_i_vec(s_axis_i_vec), .s_axis_q_vec(s_axis_q_vec),
    .s_axis_tuser_frame_start(s_axis_tuser_frame_start),
    .s_axis_tuser_frame_gain(s_axis_tuser_frame_gain), .s_axis_fifo_full(s_axis_fifo_full),
    .core_clk(core_clk), .core_aresetn(core_aresetn), .core_enable(datapath_enable),
    .core_drain(ENABLE_LOW_POWER_CTRL && (lp_state == 3'd4)),
    .core_valid(core_valid), .core_ready(core_ready), .core_i_vec(core_i_vec), .core_q_vec(core_q_vec),
    .core_frame_start(core_frame_start), .core_frame_gain(core_frame_gain),
    .core_underflow(core_underflow), .core_protocol_error(core_protocol_error)
  );

  dsm_frame_gain_vector #(
    .W(W), .LANES(8), .GAIN_W(GAIN_W),
    .HOLD_STATE_ON_DISABLE(ENABLE_LOW_POWER_CTRL)
  ) u_frame_gain (
    .clk(core_clk), .rst_n(core_aresetn), .enable(gain_enable_q),
    .in_valid(core_valid), .in_ready(core_ready), .in_frame_start(core_frame_start),
    .in_frame_gain(core_frame_gain), .in_i_vec(core_i_vec), .in_q_vec(core_q_vec),
    .out_valid(gain_valid), .out_ready(gain_ready), .out_i_vec(gain_i_vec), .out_q_vec(gain_q_vec)
  );

  tid32_thermo3_frontend_tx #(
    .W(W), .IN_LANES(8), .DPD_LANES(16), .MAX_TAPS(DPD_MAX_TAPS),
    .INTERP_TAPS(INTERP_TAPS), .THRESHOLD(THRESHOLD),
    .HOLD_STATE_ON_DISABLE(ENABLE_LOW_POWER_CTRL)
  ) u_frontend (
    .clk(core_clk), .rst_n(core_aresetn), .enable(frontend_enable_q),
    .in_valid(gain_valid), .in_ready(gain_ready), .in_i_vec(gain_i_vec), .in_q_vec(gain_q_vec),
    .dpd_active_taps(dpd_active_taps), .c1_re(c1_re[DPD_MAX_TAPS*16-1:0]), .c1_im(c1_im[DPD_MAX_TAPS*16-1:0]),
    .c3_re(c3_re[DPD_MAX_TAPS*16-1:0]), .c3_im(c3_im[DPD_MAX_TAPS*16-1:0]),
    .c5_re(c5_re[DPD_MAX_TAPS*16-1:0]), .c5_im(c5_im[DPD_MAX_TAPS*16-1:0]),
    .pa_p_valid(pa_p_valid), .pa_p_data(pa_p_data), .pa_p_ready(pa_p_ready),
    .pa_m_valid(pa_m_valid), .pa_m_data(pa_m_data), .pa_m_ready(pa_m_ready)
  );
endmodule

`default_nettype wire
