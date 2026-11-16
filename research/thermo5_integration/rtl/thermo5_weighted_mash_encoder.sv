`timescale 1ns/1ps
`default_nettype none

// Converts the two raw MASH quantizer streams into the actual two-plane
// 1:2 weighted PA contract.  The output levels are q1+q2-z^-1*q2 in
// {-3,-1,+1,+3}; PA0 has weight 1 and PA1 has weight 2.  Fs/4 lane polarity
// follows tid32_cartesian_fs4_gt_tx, so these are physical packed bitstreams,
// not the unweighted stage outputs.
module thermo5_weighted_mash_encoder #(
  parameter int CHANNELS = 32
) (
  input wire logic clk,
  input wire logic rst_n,
  input wire logic in_valid,
  output wire logic in_ready,
  input wire logic [2*CHANNELS-1:0] in_stage1_data,
  input wire logic [2*CHANNELS-1:0] in_stage2_data,
  output wire logic out_valid,
  input wire logic out_ready,
  output wire logic [2*CHANNELS-1:0] out_pa0_data,
  output wire logic [2*CHANNELS-1:0] out_pa1_data
);
  logic signed [1:0] prev_i_q2, prev_q_q2;
  logic [2*CHANNELS-1:0] pa0_q, pa1_q;
  logic valid_q;
  logic [2*CHANNELS-1:0] next_pa0, next_pa1;
  logic signed [1:0] next_prev_i_q2, next_prev_q_q2;

  function automatic integer decode_component(
    input logic [2*CHANNELS-1:0] word,
    input integer lane,
    input integer component
  );
    logic bit_value;
    begin
      bit_value = word[2*lane + component];
      if (component == 0)
        decode_component = ((lane % 2) == 0) ? (bit_value ? 1 : -1)
                                               : (bit_value ? -1 : 1);
      else
        decode_component = ((lane % 2) == 0) ? (bit_value ? -1 : 1)
                                               : (bit_value ? 1 : -1);
    end
  endfunction

  function automatic logic encode_component(
    input logic positive,
    input integer lane,
    input integer component
  );
    begin
      if (component == 0)
        encode_component = ((lane % 2) == 0) ? positive : ~positive;
      else
        encode_component = ((lane % 2) == 0) ? ~positive : positive;
    end
  endfunction

  always_comb begin : p_encode
    integer lane;
    integer q1_i, q1_q, q2_i, q2_q, y_i, y_q;
    logic signed [1:0] rolling_prev_i_q2, rolling_prev_q_q2;
    logic positive0, positive1;
    next_pa0 = '0;
    next_pa1 = '0;
    next_prev_i_q2 = prev_i_q2;
    next_prev_q_q2 = prev_q_q2;
    rolling_prev_i_q2 = prev_i_q2;
    rolling_prev_q_q2 = prev_q_q2;
    for (lane = 0; lane < CHANNELS; lane = lane + 1) begin
      q1_i = decode_component(in_stage1_data, lane, 0);
      q1_q = decode_component(in_stage1_data, lane, 1);
      q2_i = decode_component(in_stage2_data, lane, 0);
      q2_q = decode_component(in_stage2_data, lane, 1);
      y_i = q1_i + q2_i - rolling_prev_i_q2;
      y_q = q1_q + q2_q - rolling_prev_q_q2;
      // 1:2 bipolar encoding: y = pa0 + 2*pa1.
      positive0 = (y_i == -1) || (y_i == 3);
      positive1 = (y_i == 1) || (y_i == 3);
      next_pa0[2*lane] = encode_component(positive0, lane, 0);
      next_pa1[2*lane] = encode_component(positive1, lane, 0);
      positive0 = (y_q == -1) || (y_q == 3);
      positive1 = (y_q == 1) || (y_q == 3);
      next_pa0[2*lane+1] = encode_component(positive0, lane, 1);
      next_pa1[2*lane+1] = encode_component(positive1, lane, 1);
      rolling_prev_i_q2 = q2_i;
      rolling_prev_q_q2 = q2_q;
      next_prev_i_q2 = q2_i;
      next_prev_q_q2 = q2_q;
    end
  end

  assign in_ready = !valid_q || out_ready;
  assign out_valid = valid_q;
  assign out_pa0_data = pa0_q;
  assign out_pa1_data = pa1_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      prev_i_q2 <= -2'sd1;
      prev_q_q2 <= -2'sd1;
      pa0_q <= '0;
      pa1_q <= '0;
      valid_q <= 1'b0;
    end else begin
      if (in_ready) valid_q <= in_valid;
      if (in_valid && in_ready) begin
        pa0_q <= next_pa0;
        pa1_q <= next_pa1;
        prev_i_q2 <= next_prev_i_q2;
        prev_q_q2 <= next_prev_q_q2;
      end
    end
  end
endmodule

`default_nettype wire
