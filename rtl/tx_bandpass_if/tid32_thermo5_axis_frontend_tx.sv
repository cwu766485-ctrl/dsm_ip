`timescale 1ns/1ps
`default_nettype none

// Multi-clock FPGA integration wrapper.  AXI-stream ingress is 125 MHz and
// carries 14 contiguous complex samples per beat.  The TID frontend remains
// unchanged at 218.75 MHz and consumes eight contiguous complex samples.
module tid32_thermo5_axis_frontend_tx #(
  parameter int W = 16,
  parameter int GAIN_W = 16,
  parameter int STEP = 7168,
  parameter int DPD_MAX_TAPS = 4,
  parameter int INTERP_TAPS = 4,
  // Identity-configured memory-DPD remains structurally present by default.
  parameter bit BYPASS_DPD = 1'b0,
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
  output wire logic [3:0]                      pa_valid,
  output wire logic [63:0]                     pa_data [0:3],
  input  wire logic [3:0]                      pa_ready
);
  logic core_valid, core_ready, core_frame_start;
  logic signed [8*W-1:0] core_i_vec, core_q_vec;
  logic signed [GAIN_W-1:0] core_frame_gain;
  logic datapath_enable;
  logic lp_datapath_enable;
  logic [2:0] lp_state;
  logic [7:0] lp_outstanding;
  logic lp_ingress_enable, cdc_s_ready, cdc_s_valid;
  // Registered local CE for the thermo datapath.  It never drives AXI
  // ready/valid and changes only on a core-clock boundary.
  logic frontend_enable_q;

  // Admit AXI traffic only while a low-power run has been requested.  The
  // baseline path retains its original handshake behavior.
  assign s_axis_tready = cdc_s_ready &&
                         (!ENABLE_LOW_POWER_CTRL || lp_ingress_enable);
  // Prevent a source-held valid beat from bypassing the low-power ingress
  // policy while external ready is deasserted.
  assign cdc_s_valid = s_axis_tvalid &&
                       (!ENABLE_LOW_POWER_CTRL || lp_ingress_enable);

  generate
    if (ENABLE_LOW_POWER_CTRL) begin : g_low_power
      dsm_frame_power_ctrl #(.PREFILL_WORDS(LP_PREFILL_WORDS)) u_power_ctrl (
        .s_clk(s_axis_aclk), .s_rst_n(s_axis_aresetn),
        .s_accept(s_axis_tvalid && s_axis_tready), .run_request(core_enable),
        .core_clk(core_clk), .core_rst_n(core_aresetn),
        .core_accept(core_valid && core_ready),
        .output_accept((&pa_valid) && (&pa_ready)),
        .core_input_valid(core_valid), .output_valid(|pa_valid),
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
  if (ENABLE_LOW_POWER_CTRL) begin : g_lp_timing_safe
    // The controller, rather than the raw request, owns the CDC enable so the
    // FIFO and downstream pipeline can complete DRAIN before becoming idle.
    assign datapath_enable = lp_datapath_enable;
  end

  generate
    if (ENABLE_LOW_POWER_CTRL) begin : g_lp_local_ce
      always_ff @(posedge core_clk or negedge core_aresetn) begin
        if (!core_aresetn)
          frontend_enable_q <= 1'b0;
        else
          frontend_enable_q <= lp_datapath_enable;
      end
    end else begin : g_baseline_local_ce
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

  tid32_thermo5_frontend_tx #(.W(W), .IN_LANES(8), .DPD_LANES(16), .GAIN_W(GAIN_W),
    .STEP(STEP), .MAX_TAPS(DPD_MAX_TAPS), .INTERP_TAPS(INTERP_TAPS), .BYPASS_DPD(BYPASS_DPD),
    .HOLD_STATE_ON_DISABLE(ENABLE_LOW_POWER_CTRL)) u_frontend (
    .clk(core_clk), .rst_n(core_aresetn), .enable(frontend_enable_q),
    .in_valid(core_valid), .in_ready(core_ready), .in_frame_start(core_frame_start),
    .in_frame_gain(core_frame_gain), .in_i_vec(core_i_vec), .in_q_vec(core_q_vec),
    .dpd_active_taps(dpd_active_taps), .c1_re(c1_re[DPD_MAX_TAPS*16-1:0]), .c1_im(c1_im[DPD_MAX_TAPS*16-1:0]),
    .c3_re(c3_re[DPD_MAX_TAPS*16-1:0]), .c3_im(c3_im[DPD_MAX_TAPS*16-1:0]),
    .c5_re(c5_re[DPD_MAX_TAPS*16-1:0]), .c5_im(c5_im[DPD_MAX_TAPS*16-1:0]),
    .pa_valid(pa_valid), .pa_data(pa_data), .pa_ready(pa_ready)
  );
endmodule

`default_nettype wire
