`timescale 1ns/1ps
`default_nettype none

//------------------------------------------------------------------------------
// Full five-level 14-GS/s frontend at a 218.75-MHz word cadence.
//
// 8 complex samples -> frame gain -> x2 -> optional vector DPD ->
// x2 -> 32 complex samples -> four aligned Fs/4 raw code planes.
// Lane 0 is always the earliest sample.  The four outputs are code planes;
// they are not a claim of four physically routed GTH lanes.
//
// The deployed configuration uses identity coefficients (c1=1, all remaining
// coefficients zero) but keeps the DPD datapath instantiated.  This retains
// a stable, timing-accounted integration boundary for a future calibrated
// memory-DPD without claiming an RF improvement from the identity setting.
//------------------------------------------------------------------------------
module tid32_thermo5_frontend_tx #(
  parameter int W = 16,
  parameter int IN_LANES = 8,
  parameter int DPD_LANES = 16,
  parameter int MAX_TAPS = 4,
  parameter int INTERP_TAPS = 4,
  parameter bit INTERP_CENTERED_CUBIC = 1'b1,
  parameter int COEFF_W = 16,
  parameter int COEFF_FRAC = 14,
  parameter int GAIN_W = 16,
  parameter int GAIN_FRAC = 14,
  parameter int STEP = 5120,
  parameter bit HOLD_STATE_ON_DISABLE = 1'b0,
  parameter bit BYPASS_DPD = 1'b0,
  parameter int TIDSM_ORDER = 2
) (
  input  wire logic                                      clk,
  input  wire logic                                      rst_n,
  input  wire logic                                      enable,
  input  wire logic                                      in_valid,
  output wire logic                                      in_ready,
  input  wire logic                                      in_frame_start,
  input  wire logic                                      in_frame_end,
  input  wire logic signed [GAIN_W-1:0]                  in_frame_gain,
  input  wire logic signed [IN_LANES*W-1:0]              in_i_vec,
  input  wire logic signed [IN_LANES*W-1:0]              in_q_vec,
  input  wire logic [2:0]                                dpd_active_taps,
  input  wire logic signed [MAX_TAPS*COEFF_W-1:0]        c1_re, c1_im,
  input  wire logic signed [MAX_TAPS*COEFF_W-1:0]        c3_re, c3_im,
  input  wire logic signed [MAX_TAPS*COEFF_W-1:0]        c5_re, c5_im,
  output wire logic [3:0]                                pa_valid,
  output wire logic [63:0]                               pa_data [0:3],
  output wire logic                                      dpd_config_boundary,
  input  wire logic [3:0]                                pa_ready
);
  logic gain_valid, gain_ready, gain_input_ready, gain_frame_start, gain_frame_end;
  logic ingress_valid, ingress_ready;
  logic ingress_frame_start, ingress_frame_end;
  logic signed [GAIN_W-1:0] ingress_frame_gain;
  logic i1_valid, i1_ready, i1_frame_start, i1_frame_end, i1_tail;
  logic i1_buf_valid, i1_buf_ready, i1_buf_frame_start;
  logic dpd_valid, dpd_ready, dpd_buf_valid, dpd_buf_ready, i2_valid, i2_ready;
  logic [1:0] dpd_meta, dpd_buf_meta;
  logic i2_frame_start, i2_frame_end, i2_tail;
  logic i2_fifo_valid, tid_ready;
  logic [GAIN_W+1:0] ingress_meta;
  logic [1:0] i1_buf_meta;
  logic signed [IN_LANES*W-1:0] gain_i, gain_q;
  logic signed [IN_LANES*W-1:0] ingress_i, ingress_q;
  logic signed [DPD_LANES*W-1:0] i1_i, i1_q, i1_buf_i, i1_buf_q, dpd_i, dpd_q, dpd_buf_i, dpd_buf_q;
  logic signed [2*DPD_LANES*W-1:0] i2_i, i2_q;
  logic signed [2*DPD_LANES*W-1:0] i2_fifo_i, i2_fifo_q;

  // Decouple the asynchronous FIFO read-enable from downstream PA ready.
  // The low-power enable still gates admission exactly as before.
  assign ingress_meta = {in_frame_gain, in_frame_end, in_frame_start};
  assign in_ready = enable && ingress_ready;
  thermo5_vector_registered_ready_fifo #(
    .W(W), .LANES(IN_LANES), .META_W(GAIN_W+2)
  ) u_cdc_to_frame_gain_fifo (
    .clk(clk), .rst_n(rst_n),
    .in_valid(in_valid && enable), .in_ready(ingress_ready), .in_meta(ingress_meta),
    .in_i_vec(in_i_vec), .in_q_vec(in_q_vec),
    .out_valid(ingress_valid), .out_ready(gain_input_ready),
    .out_meta({ingress_frame_gain, ingress_frame_end, ingress_frame_start}),
    .out_i_vec(ingress_i), .out_q_vec(ingress_q)
  );

  dsm_frame_gain_vector #(
    .W(W), .LANES(IN_LANES), .GAIN_W(GAIN_W), .GAIN_FRAC(GAIN_FRAC),
    .HOLD_STATE_ON_DISABLE(HOLD_STATE_ON_DISABLE)
  ) u_frame_gain (
    .clk(clk), .rst_n(rst_n), .enable(enable),
    .in_valid(ingress_valid), .in_ready(gain_input_ready),
    .in_frame_start(ingress_frame_start), .in_frame_end(ingress_frame_end),
    .in_frame_gain(ingress_frame_gain),
    .in_i_vec(ingress_i), .in_q_vec(ingress_q),
    .out_valid(gain_valid), .out_frame_start(gain_frame_start),
    .out_frame_end(gain_frame_end),
    .out_ready(gain_ready), .out_i_vec(gain_i), .out_q_vec(gain_q)
  );

  generate
    if (INTERP_CENTERED_CUBIC) begin : g_interp1_centered
      dsm_interp_x2_centered_cubic_vector #(
        .W(W), .LANES(IN_LANES), .APPEND_TAIL_VECTOR(1'b1),
        .HOLD_STATE_ON_DISABLE(HOLD_STATE_ON_DISABLE)
      ) u_interp_1 (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .in_valid(gain_valid), .in_ready(gain_ready),
        .in_frame_start(gain_frame_start), .in_frame_end(gain_frame_end), .in_tail(1'b0),
        .in_i_vec(gain_i), .in_q_vec(gain_q),
        .out_valid(i1_valid), .out_frame_start(i1_frame_start),
        .out_frame_end(i1_frame_end), .out_tail(i1_tail), .out_ready(i1_ready),
        .out_i_vec(i1_i), .out_q_vec(i1_q)
      );
    end else begin : g_interp1_causal
      dsm_interp_x2_polyphase_vector #(
        .W(W), .LANES_IN(IN_LANES), .INTERP_TAPS(INTERP_TAPS),
        .HOLD_STATE_ON_DISABLE(HOLD_STATE_ON_DISABLE)
      ) u_interp_1 (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .in_valid(gain_valid), .in_ready(gain_ready), .in_frame_start(gain_frame_start),
        .in_i_vec(gain_i), .in_q_vec(gain_q),
        .out_valid(i1_valid), .out_frame_start(i1_frame_start), .out_ready(i1_ready),
        .out_i_vec(i1_i), .out_q_vec(i1_q)
      );
      assign i1_frame_end = 1'b0;
      assign i1_tail = 1'b0;
    end
  endgenerate

  // This word-atomic register boundary is also retained in the bypass option
  // so both configurations share the same temporal and timing contract.
  thermo5_vector_registered_ready_fifo #(.W(W), .LANES(DPD_LANES), .META_W(2)) u_interp_to_dpd_elastic (
    .clk(clk), .rst_n(rst_n),
    .in_valid(i1_valid), .in_ready(i1_ready), .in_meta({i1_tail, i1_frame_start}),
    .in_i_vec(i1_i), .in_q_vec(i1_q),
    .out_valid(i1_buf_valid), .out_meta(i1_buf_meta), .out_ready(i1_buf_ready),
    .out_i_vec(i1_buf_i), .out_q_vec(i1_buf_q)
  );
  assign i1_buf_frame_start = i1_buf_meta[0];

  // The configuration controller commits on the exact DPD input transaction,
  // after the frame marker has traversed the same elastic path as its data.
  assign dpd_config_boundary = i1_buf_valid && i1_buf_ready && i1_buf_frame_start;

  generate
    if (BYPASS_DPD) begin : g_no_dpd
      assign dpd_valid = i1_buf_valid;
      assign i1_buf_ready = dpd_ready;
      assign dpd_i = i1_buf_i;
      assign dpd_q = i1_buf_q;
      assign dpd_meta = i1_buf_meta;
    end else begin : g_memory_dpd
      dpd_vector16_memory_poly #(
        .W(W), .LANES(DPD_LANES), .COEFF_W(COEFF_W), .COEFF_FRAC(COEFF_FRAC),
        .MAX_TAPS(MAX_TAPS)
      ) u_memory_dpd (
        .clk(clk), .rst_n(rst_n), .active_taps(dpd_active_taps),
        .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
        .c5_re(c5_re), .c5_im(c5_im),
        .in_valid(i1_buf_valid), .in_ready(i1_buf_ready), .in_meta(i1_buf_meta),
        .in_i_vec(i1_buf_i), .in_q_vec(i1_buf_q),
        .out_valid(dpd_valid), .out_ready(dpd_ready), .out_meta(dpd_meta),
        .out_i_vec(dpd_i), .out_q_vec(dpd_q)
      );
    end
  endgenerate

  thermo5_vector_registered_ready_fifo #(.W(W), .LANES(DPD_LANES), .META_W(2)) u_dpd_to_interp_elastic (
    .clk(clk), .rst_n(rst_n),
    .in_valid(dpd_valid), .in_ready(dpd_ready), .in_meta(dpd_meta),
    .in_i_vec(dpd_i), .in_q_vec(dpd_q),
    .out_valid(dpd_buf_valid), .out_meta(dpd_buf_meta), .out_ready(dpd_buf_ready),
    .out_i_vec(dpd_buf_i), .out_q_vec(dpd_buf_q)
  );

  generate
    if (INTERP_CENTERED_CUBIC) begin : g_interp2_centered
      dsm_interp_x2_centered_cubic_vector #(
        .W(W), .LANES(DPD_LANES), .APPEND_TAIL_VECTOR(1'b0),
        .HOLD_STATE_ON_DISABLE(HOLD_STATE_ON_DISABLE)
      ) u_interp_2 (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .in_valid(dpd_buf_valid), .in_ready(dpd_buf_ready),
        .in_frame_start(dpd_buf_meta[0]), .in_frame_end(dpd_buf_meta[1]),
        .in_tail(dpd_buf_meta[1]), .in_i_vec(dpd_buf_i), .in_q_vec(dpd_buf_q),
        .out_valid(i2_valid), .out_frame_start(i2_frame_start),
        .out_frame_end(i2_frame_end), .out_tail(i2_tail), .out_ready(i2_ready),
        .out_i_vec(i2_i), .out_q_vec(i2_q)
      );
    end else begin : g_interp2_causal
      dsm_interp_x2_polyphase_vector #(
        .W(W), .LANES_IN(DPD_LANES), .INTERP_TAPS(INTERP_TAPS),
        .HOLD_STATE_ON_DISABLE(HOLD_STATE_ON_DISABLE)
      ) u_interp_2 (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .in_valid(dpd_buf_valid), .in_ready(dpd_buf_ready),
        .in_frame_start(dpd_buf_meta[0]),
        .in_i_vec(dpd_buf_i), .in_q_vec(dpd_buf_q),
        .out_valid(i2_valid), .out_frame_start(i2_frame_start), .out_ready(i2_ready),
        .out_i_vec(i2_i), .out_q_vec(i2_q)
      );
      assign i2_frame_end = 1'b0;
      assign i2_tail = 1'b0;
    end
  endgenerate

  // Break the full-chain combinational ready path at a word-atomic boundary.
  // in_ready depends only on registered occupancy; PA backpressure can change
  // the FIFO occupancy on this edge, but cannot ripple through the two
  // interpolators, DPD, frame-gain, and back to the asynchronous FIFO in one
  // cycle.  The queue sustains one 32-complex-sample word per core cycle.
  thermo5_vector_registered_ready_fifo #(
    .W(W), .LANES(2*DPD_LANES), .META_W(1)
  ) u_interp2_to_tid_fifo (
    .clk(clk), .rst_n(rst_n),
    .in_valid(i2_valid), .in_ready(i2_ready), .in_meta(1'b0),
    .in_i_vec(i2_i), .in_q_vec(i2_q),
    .out_valid(i2_fifo_valid), .out_ready(tid_ready), .out_meta(),
    .out_i_vec(i2_fifo_i), .out_q_vec(i2_fifo_q)
  );

  tid32_thermo5_fs4_multipa_tx #(.W(W), .CHANNELS(2*DPD_LANES),
    .STEP(STEP), .TIDSM_ORDER(TIDSM_ORDER)) u_tid (
    .clk(clk), .rst_n(rst_n), .in_valid(i2_fifo_valid), .in_ready(tid_ready),
    .in_i_poly_vec(i2_fifo_i), .in_q_poly_vec(i2_fifo_q),
    .pa_valid(pa_valid), .pa_data(pa_data), .pa_ready(pa_ready)
  );
endmodule

//------------------------------------------------------------------------------
// Two-entry vector FIFO with a registered-occupancy ready contract.
// Payload is intentionally not reset: it is meaningful only when out_valid is
// asserted.  Resetting only control state also avoids a reset tree across the
// wide data bank.  Simultaneous push/pop is supported at one word per cycle.
//------------------------------------------------------------------------------
module thermo5_vector_registered_ready_fifo #(
  parameter int W = 16,
  parameter int LANES = 32,
  parameter int META_W = 1
) (
  input  wire logic                         clk,
  input  wire logic                         rst_n,
  input  wire logic                         in_valid,
  output wire logic                         in_ready,
  input  wire logic [META_W-1:0]            in_meta,
  input  wire logic signed [LANES*W-1:0]    in_i_vec,
  input  wire logic signed [LANES*W-1:0]    in_q_vec,
  output wire logic                         out_valid,
  input  wire logic                         out_ready,
  output wire logic [META_W-1:0]            out_meta,
  output wire logic signed [LANES*W-1:0]    out_i_vec,
  output wire logic signed [LANES*W-1:0]    out_q_vec
);
  logic [1:0] count_q;
  logic rd_ptr_q, wr_ptr_q;
  logic [META_W-1:0] meta_mem [0:1];
  logic signed [LANES*W-1:0] data_i_mem [0:1];
  logic signed [LANES*W-1:0] data_q_mem [0:1];
  logic push, pop;

  assign in_ready = (count_q != 2'd2);
  assign out_valid = (count_q != 2'd0);
  assign out_meta = out_valid ? meta_mem[rd_ptr_q] : '0;
  assign out_i_vec = data_i_mem[rd_ptr_q];
  assign out_q_vec = data_q_mem[rd_ptr_q];
  assign push = in_valid && in_ready;
  assign pop = out_valid && out_ready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count_q <= 2'd0;
      rd_ptr_q <= 1'b0;
      wr_ptr_q <= 1'b0;
    end else begin
      if (push) begin
        data_i_mem[wr_ptr_q] <= in_i_vec;
        data_q_mem[wr_ptr_q] <= in_q_vec;
        meta_mem[wr_ptr_q] <= in_meta;
        wr_ptr_q <= ~wr_ptr_q;
      end
      if (pop)
        rd_ptr_q <= ~rd_ptr_q;

      case ({push, pop})
        2'b10: count_q <= count_q + 2'd1;
        2'b01: count_q <= count_q - 2'd1;
        default: count_q <= count_q;
      endcase
    end
  end
endmodule

`default_nettype wire
