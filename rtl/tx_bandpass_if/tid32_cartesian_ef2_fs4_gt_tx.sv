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
  parameter int CHANNELS = 32,
  // Experimental exact two-sample look-ahead. Keep disabled in the product
  // baseline until an FPGA implementation is routed and timing-qualified.
  parameter bit PAIR_LOOKAHEAD = 1'b0
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
  localparam logic signed [ACC_W:0] INPUT_ABS_BOUND =
    $signed({{ACC_W{1'b0}}, 1'b1}) <<< (W-1);
  localparam logic signed [ACC_W:0] STATE_ABS_BOUND =
    $signed({{ACC_W{1'b0}}, 1'b1}) <<< (STATE_W-1);
  localparam logic signed [ACC_W:0] U_ABS_BOUND =
    INPUT_ABS_BOUND + STATE_ABS_BOUND + (STATE_ABS_BOUND <<< 1);
  localparam logic signed [ACC_W:0] E_RAW_ABS_BOUND = U_ABS_BOUND +
    $signed({Q_ONE[ACC_W-1], Q_ONE});

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
  // Formal observability: these indicators do not feed the datapath and are
  // expected to be pruned by synthesis when unused. The extra sign bit
  // checks that each ACC_W intermediate equals its wider mathematical value.
  logic arithmetic_no_wrap_comb, arithmetic_bounds_comb;
  logic signed [ACC_W:0] x_i_check, x_q_check;
  logic signed [ACC_W:0] err1_i_check, err2_i_check;
  logic signed [ACC_W:0] err1_q_check, err2_q_check;
  logic signed [ACC_W:0] u_i_check, u_q_check;
  logic signed [ACC_W:0] e_i_raw_check, e_q_raw_check;
  logic signed [ACC_W:0] q_one_check;
  typedef struct packed {
    logic q0_positive;
    logic q1_positive;
    logic signed [STATE_W-1:0] e0_state;
    logic signed [STATE_W-1:0] e1_state;
    logic signed [ACC_W-1:0] u0;
    logic signed [ACC_W-1:0] e0_raw;
    logic signed [ACC_W-1:0] u1;
    logic signed [ACC_W-1:0] e1_raw;
    logic no_wrap;
    logic in_bounds;
    logic clamp_positive;
    logic clamp_negative;
  } ef2_pair_result_t;
  ef2_pair_result_t pair_i, pair_q;
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

  // Exact pairwise look-ahead. q0 is computed from u0 while both possible
  // saturated e0 values and their corresponding u1 values are evaluated in
  // parallel. q0 then selects the matching u1; q1 and the final state follow.
  // This changes only the combinational factoring, not the recurrence.
  function automatic ef2_pair_result_t ef2_pair_lookahead(
    input logic signed [W-1:0] x0,
    input logic signed [W-1:0] x1,
    input logic signed [STATE_W-1:0] e1_prev,
    input logic signed [STATE_W-1:0] e2_prev
  );
    logic signed [ACC_W-1:0] x0_wide, x1_wide;
    logic signed [ACC_W-1:0] e1_wide, e2_wide;
    logic signed [ACC_W-1:0] u1_positive, u1_negative;
    logic signed [STATE_W-1:0] e0_positive, e0_negative;
    logic signed [ACC_W:0] x0_check, x1_check;
    logic signed [ACC_W:0] e1_check, e2_check;
    logic signed [ACC_W:0] e0_check;
    logic signed [ACC_W:0] u0_check, e0_raw_check;
    logic signed [ACC_W:0] u1_check, e1_raw_check;
    logic signed [ACC_W:0] q_one_wide;
    ef2_pair_result_t result;
    begin
      result = '0;
      result.no_wrap = 1'b1;
      result.in_bounds = 1'b1;
      x0_wide = {{(ACC_W-W){x0[W-1]}}, x0};
      x1_wide = {{(ACC_W-W){x1[W-1]}}, x1};
      e1_wide = {{(ACC_W-STATE_W){e1_prev[STATE_W-1]}}, e1_prev};
      e2_wide = {{(ACC_W-STATE_W){e2_prev[STATE_W-1]}}, e2_prev};
      result.u0 = x0_wide + (e1_wide <<< 1) - e2_wide;
      result.q0_positive = (result.u0 > 0);
      result.e0_raw = result.q0_positive ? (result.u0 - Q_ONE) :
                                                       (result.u0 + Q_ONE);
      e0_positive = sat_error(result.u0 - Q_ONE);
      e0_negative = sat_error(result.u0 + Q_ONE);
      result.e0_state = result.q0_positive ? e0_positive : e0_negative;

      u1_positive = x1_wide +
        ({{(ACC_W-STATE_W){e0_positive[STATE_W-1]}}, e0_positive} <<< 1) -
        e1_wide;
      u1_negative = x1_wide +
        ({{(ACC_W-STATE_W){e0_negative[STATE_W-1]}}, e0_negative} <<< 1) -
        e1_wide;
      result.u1 = result.q0_positive ? u1_positive : u1_negative;
      result.q1_positive = (result.u1 > 0);
      result.e1_raw = result.q1_positive ? (result.u1 - Q_ONE) :
                                                       (result.u1 + Q_ONE);
      result.e1_state = sat_error(result.e1_raw);

      x0_check = {{(ACC_W+1-W){x0[W-1]}}, x0};
      x1_check = {{(ACC_W+1-W){x1[W-1]}}, x1};
      e1_check = {{(ACC_W+1-STATE_W){e1_prev[STATE_W-1]}}, e1_prev};
      e2_check = {{(ACC_W+1-STATE_W){e2_prev[STATE_W-1]}}, e2_prev};
      e0_check = {{(ACC_W+1-STATE_W){result.e0_state[STATE_W-1]}},
                  result.e0_state};
      q_one_wide = $signed({Q_ONE[ACC_W-1], Q_ONE});
      u0_check = x0_check + (e1_check <<< 1) - e2_check;
      e0_raw_check = (u0_check > 0) ? (u0_check - q_one_wide) :
                                                      (u0_check + q_one_wide);
      u1_check = x1_check + (e0_check <<< 1) - e1_check;
      e1_raw_check = (u1_check > 0) ? (u1_check - q_one_wide) :
                                                      (u1_check + q_one_wide);
      if (($signed(u0_check) != $signed({result.u0[ACC_W-1], result.u0})) ||
          ($signed(e0_raw_check) != $signed({result.e0_raw[ACC_W-1], result.e0_raw})) ||
          ($signed(u1_check) != $signed({result.u1[ACC_W-1], result.u1})) ||
          ($signed(e1_raw_check) != $signed({result.e1_raw[ACC_W-1], result.e1_raw})))
        result.no_wrap = 1'b0;
      if ((u0_check < -U_ABS_BOUND) || (u0_check > U_ABS_BOUND) ||
          (u1_check < -U_ABS_BOUND) || (u1_check > U_ABS_BOUND) ||
          (e0_raw_check < -E_RAW_ABS_BOUND) ||
          (e0_raw_check > E_RAW_ABS_BOUND) ||
          (e1_raw_check < -E_RAW_ABS_BOUND) ||
          (e1_raw_check > E_RAW_ABS_BOUND))
        result.in_bounds = 1'b0;
      if ((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))
        result.clamp_positive = 1'b1;
      if ((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))
        result.clamp_negative = 1'b1;
      ef2_pair_lookahead = result;
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
    arithmetic_no_wrap_comb = 1'b1;
    arithmetic_bounds_comb = 1'b1;
    x_i_check = '0;
    x_q_check = '0;
    err1_i_check = '0;
    err2_i_check = '0;
    err1_q_check = '0;
    err2_q_check = '0;
    u_i_check = '0;
    u_q_check = '0;
    e_i_raw_check = '0;
    e_q_raw_check = '0;
    q_one_check = $signed({Q_ONE[ACC_W-1], Q_ONE});
    pair_i = '0;
    pair_q = '0;
    y_i_positive = 1'b0;
    y_q_positive = 1'b0;

    if (PAIR_LOOKAHEAD) begin
      for (int lane = 0; lane < CHANNELS; lane = lane + 2) begin
        pair_i = ef2_pair_lookahead(
          in_i_poly_vec[lane*W +: W], in_i_poly_vec[(lane+1)*W +: W],
          work_err1_i, work_err2_i);
        pair_q = ef2_pair_lookahead(
          in_q_poly_vec[lane*W +: W], in_q_poly_vec[(lane+1)*W +: W],
          work_err1_q, work_err2_q);
        if (!pair_i.no_wrap || !pair_q.no_wrap)
          arithmetic_no_wrap_comb = 1'b0;
        if (!pair_i.in_bounds || !pair_q.in_bounds)
          arithmetic_bounds_comb = 1'b0;
        if (pair_i.clamp_positive || pair_q.clamp_positive)
          clamp_positive_comb = 1'b1;
        if (pair_i.clamp_negative || pair_q.clamp_negative)
          clamp_negative_comb = 1'b1;

        // Even lane polarity, followed by the opposite odd-lane polarity.
        raw_word_comb[2*lane]       = pair_i.q0_positive;
        raw_word_comb[2*lane + 1]   = !pair_q.q0_positive;
        raw_word_comb[2*(lane+1)]   = !pair_i.q1_positive;
        raw_word_comb[2*(lane+1)+1] = pair_q.q1_positive;
        work_err2_i = pair_i.e0_state;
        work_err1_i = pair_i.e1_state;
        work_err2_q = pair_q.e0_state;
        work_err1_q = pair_q.e1_state;
      end
    end else begin
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

      // Recompute each arithmetic stage with one extra signed bit. Comparing
      // this value to the RTL-width result proves no ACC_W wrap for all lanes.
      x_i_check = $signed({x_i_wide[ACC_W-1], x_i_wide});
      x_q_check = $signed({x_q_wide[ACC_W-1], x_q_wide});
      err1_i_check = $signed({err1_i_wide[ACC_W-1], err1_i_wide});
      err2_i_check = $signed({err2_i_wide[ACC_W-1], err2_i_wide});
      err1_q_check = $signed({err1_q_wide[ACC_W-1], err1_q_wide});
      err2_q_check = $signed({err2_q_wide[ACC_W-1], err2_q_wide});
      u_i_check = x_i_check + (err1_i_check <<< 1) - err2_i_check;
      u_q_check = x_q_check + (err1_q_check <<< 1) - err2_q_check;
      e_i_raw_check = (u_i_check > 0) ? (u_i_check - q_one_check) :
                                                       (u_i_check + q_one_check);
      e_q_raw_check = (u_q_check > 0) ? (u_q_check - q_one_check) :
                                                       (u_q_check + q_one_check);
      if ((u_i_check < -U_ABS_BOUND) || (u_i_check > U_ABS_BOUND) ||
          (u_q_check < -U_ABS_BOUND) || (u_q_check > U_ABS_BOUND) ||
          (e_i_raw_check < -E_RAW_ABS_BOUND) || (e_i_raw_check > E_RAW_ABS_BOUND) ||
          (e_q_raw_check < -E_RAW_ABS_BOUND) || (e_q_raw_check > E_RAW_ABS_BOUND))
        arithmetic_bounds_comb = 1'b0;

      y_i_positive = (u_i > 0);
      y_q_positive = (u_q > 0);
      e_i_raw = y_i_positive ? (u_i - Q_ONE) : (u_i + Q_ONE);
      e_q_raw = y_q_positive ? (u_q - Q_ONE) : (u_q + Q_ONE);
      if (($signed(u_i_check) != $signed({u_i[ACC_W-1], u_i})) ||
          ($signed(u_q_check) != $signed({u_q[ACC_W-1], u_q})) ||
          ($signed(e_i_raw_check) != $signed({e_i_raw[ACC_W-1], e_i_raw})) ||
          ($signed(e_q_raw_check) != $signed({e_q_raw[ACC_W-1], e_q_raw})))
        arithmetic_no_wrap_comb = 1'b0;
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
