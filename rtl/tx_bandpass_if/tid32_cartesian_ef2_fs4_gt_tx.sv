//------------------------------------------------------------------------------
// Full-rate second-order error-feedback TIDSM for one Cartesian branch.
//
// The 32 samples in one vector are evaluated in time order by an unrolled
// combinational recurrence. This preserves the scalar high-rate EF2 sequence
// while accepting one complete vector per clock. The long combinational path
// is intentional for this correctness prototype and is not timing-qualified.
// State and arithmetic use Q(W-1) input units, a signed (W+4)-bit error state,
// and a signed (W+6)-bit temporary. Error-state saturation makes the state
// invariant unconditional; no arithmetic wraps.
//------------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module tid32_cartesian_ef2_fs4_gt_tx #(
  parameter int W = 16,
  parameter int CHANNELS = 32
) (
  input  wire logic                         clk,
  input  wire logic                         rst_n,
  input  wire logic                         in_valid,
  output wire logic                         in_ready,
  input  wire logic signed [CHANNELS*W-1:0] in_i_poly_vec,
  input  wire logic signed [CHANNELS*W-1:0] in_q_poly_vec,
  output wire logic                         gt_valid,
  input  wire logic                         gt_ready,
  output wire logic [2*CHANNELS-1:0]        gt_data
);
  localparam int STATE_W = W + 4;
  localparam int ACC_W = W + 6;
  localparam logic signed [ACC_W-1:0] Q_ONE =
    $signed({{(ACC_W-1){1'b0}}, 1'b1}) <<< (W-1);
  localparam logic signed [ACC_W-1:0] STATE_MAX =
    ($signed({{(ACC_W-1){1'b0}}, 1'b1}) <<< (STATE_W-1)) - 1;
  localparam logic signed [ACC_W-1:0] STATE_MIN =
    -($signed({{(ACC_W-1){1'b0}}, 1'b1}) <<< (STATE_W-1));

  logic signed [STATE_W-1:0] err1_i_q, err2_i_q;
  logic signed [STATE_W-1:0] err1_q_q, err2_q_q;
  logic signed [STATE_W-1:0] err1_i_next, err2_i_next;
  logic signed [STATE_W-1:0] err1_q_next, err2_q_next;
  logic signed [STATE_W-1:0] work_err1_i, work_err2_i;
  logic signed [STATE_W-1:0] work_err1_q, work_err2_q;
  logic signed [ACC_W-1:0] x_i_wide, x_q_wide;
  logic signed [ACC_W-1:0] err1_i_wide, err2_i_wide;
  logic signed [ACC_W-1:0] err1_q_wide, err2_q_wide;
  logic signed [ACC_W-1:0] u_i, u_q, e_i_raw, e_q_raw;
  // Verification-visible combinational indicators. They do not feed the
  // datapath and are pruned when unused; coverage samples them only when the
  // input vector is accepted.
  logic clamp_positive_comb, clamp_negative_comb;
  logic y_i_positive, y_q_positive;
  logic [2*CHANNELS-1:0] raw_word_comb;
  logic [2*CHANNELS-1:0] raw_word_q;
  logic tid_valid_q;
  logic tid_ready;
  logic accept_word;

  initial begin
    if (W < 2 || CHANNELS < 2 || (CHANNELS % 2) != 0)
      $error("EF2 TID requires W >= 2 and an even CHANNELS >= 2");
  end

  function automatic logic signed [STATE_W-1:0] sat_error(
    input logic signed [ACC_W-1:0] value
  );
    begin
      if (value > STATE_MAX)
        sat_error = STATE_MAX[STATE_W-1:0];
      else if (value < STATE_MIN)
        sat_error = STATE_MIN[STATE_W-1:0];
      else
        sat_error = value[STATE_W-1:0];
    end
  endfunction

  always_comb begin : p_unrolled_ef2
    work_err1_i = err1_i_q;
    work_err2_i = err2_i_q;
    work_err1_q = err1_q_q;
    work_err2_q = err2_q_q;
    raw_word_comb = '0;
    x_i_wide = '0;
    x_q_wide = '0;
    err1_i_wide = '0;
    err2_i_wide = '0;
    err1_q_wide = '0;
    err2_q_wide = '0;
    u_i = '0;
    u_q = '0;
    e_i_raw = '0;
    e_q_raw = '0;
    clamp_positive_comb = 1'b0;
    clamp_negative_comb = 1'b0;
    y_i_positive = 1'b0;
    y_q_positive = 1'b0;

    for (int lane = 0; lane < CHANNELS; lane = lane + 1) begin
      x_i_wide = {{(ACC_W-W){in_i_poly_vec[lane*W+W-1]}},
                   in_i_poly_vec[lane*W +: W]};
      x_q_wide = {{(ACC_W-W){in_q_poly_vec[lane*W+W-1]}},
                   in_q_poly_vec[lane*W +: W]};
      err1_i_wide = {{(ACC_W-STATE_W){work_err1_i[STATE_W-1]}},work_err1_i};
      err2_i_wide = {{(ACC_W-STATE_W){work_err2_i[STATE_W-1]}},work_err2_i};
      err1_q_wide = {{(ACC_W-STATE_W){work_err1_q[STATE_W-1]}},work_err1_q};
      err2_q_wide = {{(ACC_W-STATE_W){work_err2_q[STATE_W-1]}},work_err2_q};

      u_i = x_i_wide + (err1_i_wide <<< 1) - err2_i_wide;
      u_q = x_q_wide + (err1_q_wide <<< 1) - err2_q_wide;
      y_i_positive = (u_i > 0);
      y_q_positive = (u_q > 0);
      e_i_raw = y_i_positive ? (u_i - Q_ONE) : (u_i + Q_ONE);
      e_q_raw = y_q_positive ? (u_q - Q_ONE) : (u_q + Q_ONE);
      if ((e_i_raw > STATE_MAX) || (e_q_raw > STATE_MAX))
        clamp_positive_comb = 1'b1;
      if ((e_i_raw < STATE_MIN) || (e_q_raw < STATE_MIN))
        clamp_negative_comb = 1'b1;

      // Fs/4 lane polarity matches the frozen raw-plane interface.
      if ((lane % 2) == 0) begin
        raw_word_comb[2*lane]     = y_i_positive;
        raw_word_comb[2*lane + 1] = !y_q_positive;
      end else begin
        raw_word_comb[2*lane]     = !y_i_positive;
        raw_word_comb[2*lane + 1] = y_q_positive;
      end

      work_err2_i = work_err1_i;
      work_err2_q = work_err1_q;
      work_err1_i = sat_error(e_i_raw);
      work_err1_q = sat_error(e_q_raw);
    end

    err1_i_next = work_err1_i;
    err2_i_next = work_err2_i;
    err1_q_next = work_err1_q;
    err2_q_next = work_err2_q;
  end

  assign in_ready = tid_ready;
  assign accept_word = in_valid && in_ready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      err1_i_q <= '0;
      err2_i_q <= '0;
      err1_q_q <= '0;
      err2_q_q <= '0;
      raw_word_q <= '0;
      tid_valid_q <= 1'b0;
    end else if (tid_ready) begin
      tid_valid_q <= accept_word;
      if (accept_word) begin
        err1_i_q <= err1_i_next;
        err2_i_q <= err2_i_next;
        err1_q_q <= err1_q_next;
        err2_q_q <= err2_q_next;
        raw_word_q <= raw_word_comb;
      end
    end
  end

  gt_tx_raw64_boundary #(.DATA_W(2*CHANNELS)) u_raw_boundary (
    .clk(clk), .rst_n(rst_n), .in_valid(tid_valid_q), .in_ready(tid_ready),
    .in_data(raw_word_q), .gt_valid(gt_valid), .gt_ready(gt_ready),
    .gt_data(gt_data)
  );
endmodule

`default_nettype wire
