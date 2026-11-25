//------------------------------------------------------------------------------
// 32-sample-per-clock MASH 1-1 Cartesian product output adapter.
//
// The scalar MASH recurrence is unrolled in lane order. State therefore
// advances as one chronological sample stream across each 32-lane word and
// continues into the next word. Four 64-bit output planes use the same raw
// I/Q and Fs/4 bit order as the Thermo5 serializer boundary. Their proposed
// logical weights are {-3,-1,+1,+3}; physical PA support for those weights is
// an integration contract and is not implied by this RTL module.
//------------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module tid32_mash11_weighted_pa_tx #(
  parameter int W = 16,
  parameter int CHANNELS = 32,
  parameter int ACC_W = 18,
  parameter int IN_SHIFT = 0,
  parameter bit SATURATE = 1'b1
) (
  input  wire logic                         clk,
  input  wire logic                         rst_n,
  input  wire logic                         in_valid,
  output wire logic                         in_ready,
  input  wire logic signed [CHANNELS*W-1:0] in_i_vec,
  input  wire logic signed [CHANNELS*W-1:0] in_q_vec,
  output wire logic [3:0]                   pa_valid,
  output logic [2*CHANNELS-1:0]             pa_data [0:3],
  input  wire logic [3:0]                   pa_ready
);
  localparam logic signed [W-1:0] Q_POS = {1'b0, {(W-1){1'b1}}};
  localparam logic signed [W-1:0] Q_NEG = -Q_POS;
  localparam logic signed [ACC_W-1:0] V_MAX = {1'b0, {(ACC_W-1){1'b1}}};
  localparam logic signed [ACC_W-1:0] V_MIN = {1'b1, {(ACC_W-1){1'b0}}};

  typedef struct packed {
    logic signed [ACC_W-1:0] e1;
    logic signed [ACC_W-1:0] e2;
    logic signed [ACC_W-1:0] e1_to_stage2;
    logic signed [2:0] stage1_pm_prev;
    logic signed [2:0] stage2_pm_prev;
  } mash_state_t;

  typedef struct packed {
    mash_state_t state_next;
    logic signed [2:0] combined_level;
    logic signed [2:0] stage1_pm;
    logic signed [2:0] stage2_pm;
  } mash_step_t;

  mash_state_t state_i_q, state_q_q;
  mash_state_t state_i_next, state_q_next;
  mash_state_t state_i_work, state_q_work;
  mash_step_t step_i, step_q;
  logic [2*CHANNELS-1:0] pa_data_next [0:3];
  logic out_valid_q;
  wire logic all_pa_ready = &pa_ready;
  wire logic accept_word = in_valid && in_ready;

`ifndef SYNTHESIS
  covergroup quantizer_input_range_cg with function sample(int unsigned range_bin,
                                                             bit stage1_positive,
                                                             bit stage2_positive);
    option.per_instance = 1;
    cp_input_range: coverpoint range_bin {
      bins minimum_rail={0}; bins negative_large={1}; bins negative_small={2};
      bins zero={3}; bins positive_small={4}; bins positive_large={5};
      bins maximum_rail={6};
    }
    cp_stage1: coverpoint stage1_positive { bins negative={0}; bins positive={1}; }
    cp_stage2: coverpoint stage2_positive { bins negative={0}; bins positive={1}; }
    x_input_range_stage1: cross cp_input_range, cp_stage1;
    x_stage1_stage2: cross cp_stage1, cp_stage2;
  endgroup
  quantizer_input_range_cg quantizer_input_range_cov;
`endif

  function automatic int unsigned classify_input_range(
    input logic signed [W-1:0] sample
  );
    int signed value, quarter_rail, minimum_rail, maximum_rail;
    begin
      value=sample;
      quarter_rail=1 << (W-2);
      minimum_rail=-(1 << (W-1));
      maximum_rail=(1 << (W-1))-1;
      if (value==minimum_rail) return 0;
      if (value < -quarter_rail) return 1;
      if (value < 0) return 2;
      if (value==0) return 3;
      if (value <= quarter_rail) return 4;
      if (value < maximum_rail) return 5;
      return 6;
    end
  endfunction

  function automatic logic signed [ACC_W-1:0] limit_acc(
    input logic signed [ACC_W:0] value
  );
    if (SATURATE) begin
      if (value > $signed({V_MAX[ACC_W-1], V_MAX}))
        limit_acc = V_MAX;
      else if (value < $signed({V_MIN[ACC_W-1], V_MIN}))
        limit_acc = V_MIN;
      else
        limit_acc = value[ACC_W-1:0];
    end else begin
      limit_acc = value[ACC_W-1:0];
    end
  endfunction

  function automatic mash_step_t mash_advance(
    input mash_state_t state,
    input logic signed [W-1:0] sample
  );
    mash_step_t result;
    logic signed [W-1:0] sample_shifted;
    logic signed [W-1:0] quantizer_rail;
    logic signed [ACC_W-1:0] sample_ext;
    logic signed [ACC_W-1:0] quantizer_ext;
    logic signed [ACC_W-1:0] v1, v2, e1_next, e2_next;
    logic signed [ACC_W:0] v1_sum, v2_sum;
    logic signed [2:0] stage1_pm, stage2_pm;
    logic stage1_positive, stage2_positive;
    begin
      sample_shifted = (IN_SHIFT == 0) ? sample : (sample >>> IN_SHIFT);
      sample_ext = {{(ACC_W-W){sample_shifted[W-1]}}, sample_shifted};

      v1_sum = $signed({sample_ext[ACC_W-1], sample_ext}) +
               $signed({state.e1[ACC_W-1], state.e1});
      v1 = limit_acc(v1_sum);
      stage1_positive = (v1 >= 0);
      stage1_pm = stage1_positive ? 3'sd1 : -3'sd1;
      quantizer_rail = stage1_positive ? Q_POS : Q_NEG;
      quantizer_ext = {{(ACC_W-W){quantizer_rail[W-1]}}, quantizer_rail};
      e1_next = v1 - quantizer_ext;

      // Match dsm_core_mash11: stage 2 consumes the previous enabled sample's
      // stage-1 residue, then its own registered error.
      v2_sum = $signed({state.e1_to_stage2[ACC_W-1], state.e1_to_stage2}) +
               $signed({state.e2[ACC_W-1], state.e2});
      v2 = limit_acc(v2_sum);
      stage2_positive = (v2 >= 0);
      stage2_pm = stage2_positive ? 3'sd1 : -3'sd1;
      quantizer_rail = stage2_positive ? Q_POS : Q_NEG;
      quantizer_ext = {{(ACC_W-W){quantizer_rail[W-1]}}, quantizer_rail};
      e2_next = v2 - quantizer_ext;

      result.combined_level = state.stage1_pm_prev +
                              (stage2_pm - state.stage2_pm_prev);
      result.stage1_pm = stage1_pm;
      result.stage2_pm = stage2_pm;
      result.state_next.e1 = e1_next;
      result.state_next.e2 = e2_next;
      result.state_next.e1_to_stage2 = e1_next;
      result.state_next.stage1_pm_prev = stage1_pm;
      result.state_next.stage2_pm_prev = stage2_pm;
      mash_advance = result;
    end
  endfunction

  // Map the exact combined MASH symbol to four weighted PA controls. The
  // startup +2 code is (-1)+(+3), preserving the legacy reset transient.
  function automatic logic weighted_plane_bit(
    input logic signed [2:0] level,
    input int unsigned plane
  );
    begin
      weighted_plane_bit = 1'b0;
      case (level)
        -3'sd3: weighted_plane_bit = (plane == 0);
        -3'sd1: weighted_plane_bit = (plane == 1);
         3'sd1: weighted_plane_bit = (plane == 2);
         3'sd2: weighted_plane_bit = (plane == 1) || (plane == 3);
         3'sd3: weighted_plane_bit = (plane == 3);
        default: weighted_plane_bit = 1'b0;
      endcase
    end
  endfunction

  assign in_ready = !out_valid_q || all_pa_ready;
  assign pa_valid = {4{out_valid_q}};

  always_comb begin
    state_i_work = state_i_q;
    state_q_work = state_q_q;
    for (int plane = 0; plane < 4; plane++)
      pa_data_next[plane] = '0;

    for (int lane = 0; lane < CHANNELS; lane++) begin
      step_i = mash_advance(state_i_work, in_i_vec[lane*W +: W]);
      step_q = mash_advance(state_q_work, in_q_vec[lane*W +: W]);
      state_i_work = step_i.state_next;
      state_q_work = step_q.state_next;

      for (int plane = 0; plane < 4; plane++) begin
        // Preserve the existing serializer's bit-zero-earliest Fs/4 mapping:
        // I[even], ~Q[even], ~I[odd], Q[odd].
        if ((lane % 2) == 0) begin
          pa_data_next[plane][2*lane] =
            weighted_plane_bit(step_i.combined_level, plane);
          pa_data_next[plane][2*lane + 1] =
            ~weighted_plane_bit(step_q.combined_level, plane);
        end else begin
          pa_data_next[plane][2*lane] =
            ~weighted_plane_bit(step_i.combined_level, plane);
          pa_data_next[plane][2*lane + 1] =
            weighted_plane_bit(step_q.combined_level, plane);
        end
      end
    end
    state_i_next = state_i_work;
    state_q_next = state_q_work;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_i_q.e1 <= '0;
      state_i_q.e2 <= '0;
      state_i_q.e1_to_stage2 <= '0;
      state_i_q.stage1_pm_prev <= 3'sd1;
      state_i_q.stage2_pm_prev <= '0;
      state_q_q.e1 <= '0;
      state_q_q.e2 <= '0;
      state_q_q.e1_to_stage2 <= '0;
      state_q_q.stage1_pm_prev <= 3'sd1;
      state_q_q.stage2_pm_prev <= '0;
      out_valid_q <= 1'b0;
      for (int plane = 0; plane < 4; plane++)
        pa_data[plane] <= '0;
    end else if (in_ready) begin
      out_valid_q <= accept_word;
      if (accept_word) begin
        state_i_q <= state_i_next;
        state_q_q <= state_q_next;
        for (int plane = 0; plane < 4; plane++)
          pa_data[plane] <= pa_data_next[plane];
      end
    end
  end

  initial begin
    if (W < 2 || ACC_W < W || CHANNELS < 2 || (CHANNELS % 2) != 0)
      $error("MASH product requires W >= 2, ACC_W >= W and even CHANNELS >= 2");
    if (IN_SHIFT < 0 || IN_SHIFT >= W)
      $error("IN_SHIFT must be in [0,W-1]");
`ifndef SYNTHESIS
    quantizer_input_range_cov=new();
`endif
  end

`ifndef SYNTHESIS
  always @(posedge clk) begin : sample_mash_quantizer_crosses
    if (rst_n && accept_word) begin
      mash_state_t cov_i_state, cov_q_state;
      cov_i_state=state_i_q;
      cov_q_state=state_q_q;
      for (int lane=0; lane<CHANNELS; lane++) begin
        mash_step_t cov_i, cov_q;
        logic signed [W-1:0] sample_i, sample_q;
        sample_i=in_i_vec[lane*W +: W];
        sample_q=in_q_vec[lane*W +: W];
        cov_i=mash_advance(cov_i_state,sample_i);
        cov_q=mash_advance(cov_q_state,sample_q);
        cov_i_state=cov_i.state_next;
        cov_q_state=cov_q.state_next;
        quantizer_input_range_cov.sample(classify_input_range(sample_i),
                                          cov_i.stage1_pm>0,
                                          cov_i.stage2_pm>0);
        quantizer_input_range_cov.sample(classify_input_range(sample_q),
                                          cov_q.stage1_pm>0,
                                          cov_q.stage2_pm>0);
      end
    end
  end

  property p_output_holds_when_backpressured;
    @(posedge clk) disable iff (!rst_n)
      (out_valid_q && !all_pa_ready) |=>
        (out_valid_q && $stable(pa_data[0]) && $stable(pa_data[1]) &&
         $stable(pa_data[2]) && $stable(pa_data[3]));
  endproperty
  assert property (p_output_holds_when_backpressured)
    else $error("MASH weighted PA word changed during backpressure");

  property p_accepted_vector_produces_output;
    @(posedge clk) disable iff (!rst_n)
      (in_valid && in_ready) |=> out_valid_q;
  endproperty
  assert property (p_accepted_vector_produces_output)
    else $error("MASH accepted vector did not produce a PA word");

  cover property (@(posedge clk) disable iff (!rst_n)
    (in_valid && in_ready) ##1 (out_valid_q && all_pa_ready));
`endif
endmodule

`default_nettype wire
