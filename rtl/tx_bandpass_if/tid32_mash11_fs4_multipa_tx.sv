//------------------------------------------------------------------------------
// Two-stage MASH-style transmitter built from two pipelined first-order
// Cartesian TIDSM stages.
//
// Each stage is the L=32, Fs/4 TID architecture.  Stage 2 consumes the
// stage-1 quantization residual after the fixed TID word latency.  Both
// one-bit stage streams are deliberately preserved for two aligned PA / GT
// branches; this module does not hard-limit their digital cancellation to a
// single bit.
//
// This is a new fixed-point architecture.  It is not the legacy low-pass
// dsm_core_mash11 and it must be qualified against its own MATLAB oracle.
//------------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module tid32_mash11_fs4_multipa_tx #(
  parameter int W = 16,
  parameter int CHANNELS = 32,
  // L=32 first-order TIDSM has a scalar-equivalent stream delay of 1,056
  // samples, i.e. 33 complete input words.  The two additional entries align
  // that algorithmic delay to the two registered raw-GT boundaries used by
  // the two TID stages.  This is not a combinational state-chain expansion.
  parameter int STAGE_DELAY_WORDS = 35
) (
  input  wire logic                         clk,
  input  wire logic                         rst_n,
  input  wire logic                         in_valid,
  output wire logic                         in_ready,
  input  wire logic signed [CHANNELS*W-1:0] in_i_poly_vec,
  input  wire logic signed [CHANNELS*W-1:0] in_q_poly_vec,
  output wire logic                         pa_valid,
  output wire logic [2*CHANNELS-1:0]        pa_stage1_data,
  output wire logic [2*CHANNELS-1:0]        pa_stage2_data
);
  localparam logic signed [W-1:0] Q_POS = {1'b0, {(W-1){1'b1}}};
  localparam logic signed [W-1:0] Q_NEG = -Q_POS;

  logic s1_in_ready, s1_valid;
  logic [2*CHANNELS-1:0] s1_data;
  logic s1_to_s2_valid;
  logic [2*CHANNELS-1:0] s1_to_s2_data;
  logic s2_in_ready, s2_valid;
  logic [2*CHANNELS-1:0] s2_data;
  logic signed [CHANNELS*W-1:0] i_delay [0:STAGE_DELAY_WORDS-1];
  logic signed [CHANNELS*W-1:0] q_delay [0:STAGE_DELAY_WORDS-1];
  logic [2*CHANNELS-1:0] s1_delay [0:STAGE_DELAY_WORDS-1];
  logic input_delay_valid;
  logic signed [CHANNELS*W-1:0] residual_i_vec;
  logic signed [CHANNELS*W-1:0] residual_q_vec;
  // Fs/4 raw mapping at reset: {I0=0,~Q0=1,~I1=1,Q1=0,...}.
  localparam logic [2*CHANNELS-1:0] RESET_STAGE2_WORD = {CHANNELS/2{4'b0110}};
  logic [1:0] reset_phase_words;
  logic [1:0] output_fifo_count;
  logic [2*CHANNELS-1:0] output_fifo_s1 [0:1];
  logic [2*CHANNELS-1:0] output_fifo_s2 [0:1];
  logic pa_valid_reg;
  logic [2*CHANNELS-1:0] pa_stage1_data_reg, pa_stage2_data_reg;
  integer d;

  initial begin
    if (CHANNELS < 2 || (CHANNELS % 2) != 0) $error("CHANNELS must be even and at least two");
    if (STAGE_DELAY_WORDS < 1) $error("STAGE_DELAY_WORDS must be positive");
  end

  // Both TID blocks accept one complete polyphase word each fabric clock.  The
  // internal GT-boundary registers are always drained into the next stage / PA
  // boundary; board-level backpressure belongs at the actual GT user ports.
  assign in_ready = s1_in_ready;

  tid32_cartesian_fs4_gt_tx #(.W(W), .CHANNELS(CHANNELS)) u_stage1 (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(s1_in_ready),
    .in_i_poly_vec(in_i_poly_vec), .in_q_poly_vec(in_q_poly_vec),
    .gt_valid(s1_valid), .gt_ready(1'b1), .gt_data(s1_data)
  );

  tid32_cartesian_fs4_gt_tx #(.W(W), .CHANNELS(CHANNELS)) u_stage2 (
    .clk(clk), .rst_n(rst_n), .in_valid(s1_to_s2_valid), .in_ready(s2_in_ready),
    .in_i_poly_vec(residual_i_vec), .in_q_poly_vec(residual_q_vec),
    .gt_valid(s2_valid), .gt_ready(1'b1), .gt_data(s2_data)
  );

  function automatic logic signed [W-1:0] sat_residual(
    input logic signed [W-1:0] x,
    input logic signed [W-1:0] q
  );
    logic signed [W:0] diff;
    begin
      diff = $signed({x[W-1], x}) - $signed({q[W-1], q});
      if (diff > $signed({1'b0, {W-1{1'b1}}})) sat_residual = {1'b0, {W-1{1'b1}}};
      else if (diff < $signed({1'b1, {W-1{1'b0}}})) sat_residual = {1'b1, {W-1{1'b0}}};
      else sat_residual = diff[W-1:0];
    end
  endfunction

  always_comb begin
    residual_i_vec = '0;
    residual_q_vec = '0;
    if (input_delay_valid) begin
      for (integer lane = 0; lane < CHANNELS; lane = lane + 1) begin
        logic i_bit, q_bit;
        logic signed [W-1:0] i_qcode, q_qcode;
        if ((lane % 2) == 0) begin
          i_bit = s1_to_s2_data[2*lane];
          q_bit = ~s1_to_s2_data[2*lane + 1];
        end else begin
          i_bit = ~s1_to_s2_data[2*lane];
          q_bit = s1_to_s2_data[2*lane + 1];
        end
        i_qcode = i_bit ? Q_POS : Q_NEG;
        q_qcode = q_bit ? Q_POS : Q_NEG;
        residual_i_vec[lane*W +: W] = sat_residual(i_delay[STAGE_DELAY_WORDS-1][lane*W +: W], i_qcode);
        residual_q_vec[lane*W +: W] = sat_residual(q_delay[STAGE_DELAY_WORDS-1][lane*W +: W], q_qcode);
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      input_delay_valid <= 1'b0;
      s1_to_s2_valid <= 1'b0;
      s1_to_s2_data <= '0;
      for (d = 0; d < STAGE_DELAY_WORDS; d = d + 1) begin
        i_delay[d] <= '0;
        q_delay[d] <= '0;
        s1_delay[d] <= '0;
      end
    end else begin
      if (in_valid && s1_in_ready) begin
        i_delay[0] <= in_i_poly_vec;
        q_delay[0] <= in_q_poly_vec;
        for (d = 1; d < STAGE_DELAY_WORDS; d = d + 1) begin
          i_delay[d] <= i_delay[d-1];
          q_delay[d] <= q_delay[d-1];
        end
      end
      if (s1_valid) begin
        input_delay_valid <= 1'b1;
        s1_to_s2_valid <= 1'b1;
        s1_to_s2_data <= s1_data;
        s1_delay[0] <= s1_data;
        for (d = 1; d < STAGE_DELAY_WORDS; d = d + 1)
          s1_delay[d] <= s1_delay[d-1];
      end else begin
        s1_to_s2_valid <= 1'b0;
      end
    end
  end

  // The two nested raw-GT boundaries have a deterministic two-word reset
  // phase.  Preserve the real words in a two-entry FIFO and emit the two
  // defined reset PA codes first, so reset-to-stream ordering is explicit and
  // the subsequent steady stream has no bubbles or dropped samples.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reset_phase_words <= '0;
      output_fifo_count <= '0;
      output_fifo_s1[0] <= '0; output_fifo_s1[1] <= '0;
      output_fifo_s2[0] <= '0; output_fifo_s2[1] <= '0;
      pa_valid_reg <= 1'b0;
      pa_stage1_data_reg <= '0;
      pa_stage2_data_reg <= '0;
    end else begin
      pa_valid_reg <= 1'b0;
      if (s2_valid) begin
        if (reset_phase_words < 2) begin
          pa_valid_reg <= 1'b1;
          pa_stage1_data_reg <= '0;
          pa_stage2_data_reg <= RESET_STAGE2_WORD;
          reset_phase_words <= reset_phase_words + 1'b1;
          if (output_fifo_count == 0) begin
            output_fifo_s1[0] <= s1_delay[STAGE_DELAY_WORDS-1];
            output_fifo_s2[0] <= s2_data;
            output_fifo_count <= 1;
          end else begin
            output_fifo_s1[1] <= s1_delay[STAGE_DELAY_WORDS-1];
            output_fifo_s2[1] <= s2_data;
            output_fifo_count <= 2;
          end
        end else begin
          if (output_fifo_count == 0) $error("TID-MASH output FIFO underflow");
          pa_valid_reg <= 1'b1;
          pa_stage1_data_reg <= output_fifo_s1[0];
          pa_stage2_data_reg <= output_fifo_s2[0];
          if (output_fifo_count == 1) begin
            output_fifo_s1[0] <= s1_delay[STAGE_DELAY_WORDS-1];
            output_fifo_s2[0] <= s2_data;
          end else begin
            output_fifo_s1[0] <= output_fifo_s1[1];
            output_fifo_s2[0] <= output_fifo_s2[1];
            output_fifo_s1[1] <= s1_delay[STAGE_DELAY_WORDS-1];
            output_fifo_s2[1] <= s2_data;
          end
        end
      end
    end
  end

  assign pa_valid = pa_valid_reg;
  assign pa_stage1_data = pa_stage1_data_reg;
  assign pa_stage2_data = pa_stage2_data_reg;
endmodule

`default_nettype wire
