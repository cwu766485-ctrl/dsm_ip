//------------------------------------------------------------------------------
// 32-channel-per-I/Q pipelined first-order Cartesian TIDSM with a 64-bit
// Fs/4 raw-GT word.
//
// This is the L=32 / 218.75-MHz form of the pipelined first-order TIDSM
// architecture described by Firmansyah, MASc thesis, equations 3.30, 3.32 and
// 3.34.  The input contains one set of 32 polyphase I samples and 32
// polyphase Q samples.  The 64 output bits form one 14-Gb/s user word:
//   I[0], ~Q[0], ~I[1], Q[1], I[2], ~Q[2], ...
// where bit zero is earliest on the serial wire.
//
// It is intentionally a new architecture, not an exact temporal expansion of
// the project's band-pass EFDSM/CRFB loops.  Its pre-summation matrix turns
// the accumulation into registered operations, keeping the feedback critical
// path to one W+1-bit addition independent of the channel count.
//------------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module tid32_cartesian_fs4_gt_tx #(
  parameter int W = 16,
  parameter int CHANNELS = 32
) (
  input  wire logic                            clk,
  input  wire logic                            rst_n,
  input  wire logic                            in_valid,
  output wire logic                            in_ready,
  // Signed Cartesian samples.  The EFM input conversion below adds 2^(W-1)
  // so that its accumulator/bit-slice implementation operates on unsigned W
  // bit values, as required by the EFM derivation.
  input  wire logic signed [CHANNELS*W-1:0]    in_i_poly_vec,
  input  wire logic signed [CHANNELS*W-1:0]    in_q_poly_vec,
  output wire logic                            gt_valid,
  input  wire logic                            gt_ready,
  output wire logic [2*CHANNELS-1:0]           gt_data
);
  logic signed [W:0] a_i [0:CHANNELS-1][0:CHANNELS-1];
  logic signed [W:0] a_q [0:CHANNELS-1][0:CHANNELS-1];
  logic signed [W:0] v_i [0:CHANNELS-1];
  logic signed [W:0] v_q [0:CHANNELS-1];
  logic [CHANNELS-1:0] y_i;
  logic [CHANNELS-1:0] y_q;
  logic [2*CHANNELS-1:0] raw_word;
  logic tid_valid;
  logic tid_ready;
  logic enable;
  integer p;
  integer q;

  initial begin
    if (CHANNELS < 2 || (CHANNELS % 2) != 0) begin
      $error("CHANNELS must be an even value of at least two");
    end
  end

  assign in_ready = tid_ready;
  assign enable = in_valid && in_ready;

  always_comb begin
    for (integer lane = 0; lane < CHANNELS; lane = lane + 1) begin
      if (lane == 0) begin
        y_i[lane] = v_i[lane][W];
        y_q[lane] = v_q[lane][W];
      end else begin
        y_i[lane] = v_i[lane][W] ^ v_i[lane-1][W];
        y_q[lane] = v_q[lane][W] ^ v_q[lane-1][W];
      end
    end

    for (integer lane = 0; lane < CHANNELS; lane = lane + 1) begin
      if ((lane % 2) == 0) begin
        raw_word[2*lane]     = y_i[lane];
        raw_word[2*lane + 1] = ~y_q[lane];
      end else begin
        raw_word[2*lane]     = ~y_i[lane];
        raw_word[2*lane + 1] = y_q[lane];
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tid_valid <= 1'b0;
      for (p = 0; p < CHANNELS; p = p + 1) begin
        v_i[p] <= '0;
        v_q[p] <= '0;
        for (q = 0; q < CHANNELS; q = q + 1) begin
          a_i[p][q] <= '0;
          a_q[p][q] <= '0;
        end
      end
    end else begin
      // A TID result exists exactly for an accepted input word.  Keeping this
      // asserted through an input bubble duplicates the previous raw-GT word
      // and corrupts the temporal sequence whenever a real feeder stalls.
      tid_valid <= enable;
      if (enable) begin
        for (p = 0; p < CHANNELS; p = p + 1) begin
          for (q = 0; q < CHANNELS; q = q + 1) begin
            if (q == 0) begin
              a_i[p][q] <= {1'b0, in_i_poly_vec[p*W +: W] ^ {1'b1, {(W-1){1'b0}}}};
              a_q[p][q] <= {1'b0, in_q_poly_vec[p*W +: W] ^ {1'b1, {(W-1){1'b0}}}};
            end else if (p == q) begin
              a_i[p][q] <= a_i[p-1][q-1] + a_i[p][q-1];
              a_q[p][q] <= a_q[p-1][q-1] + a_q[p][q-1];
            end else begin
              a_i[p][q] <= a_i[p][q-1];
              a_q[p][q] <= a_q[p][q-1];
            end
          end
          v_i[p] <= a_i[p][CHANNELS-1] + {1'b0, v_i[CHANNELS-1][W-1:0]};
          v_q[p] <= a_q[p][CHANNELS-1] + {1'b0, v_q[CHANNELS-1][W-1:0]};
        end
      end
    end
  end

  gt_tx_raw64_boundary #(.DATA_W(2*CHANNELS)) u_raw_boundary (
    .clk(clk), .rst_n(rst_n), .in_valid(tid_valid), .in_ready(tid_ready),
    .in_data(raw_word), .gt_valid(gt_valid), .gt_ready(gt_ready),
    .gt_data(gt_data)
  );
endmodule

`default_nettype wire
