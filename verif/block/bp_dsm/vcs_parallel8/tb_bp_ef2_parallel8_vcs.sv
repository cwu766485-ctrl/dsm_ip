`timescale 1ns/1ps
`default_nettype none

// Self-contained VCS regression for the eight-sample temporal unroll.
// The reference is deliberately written as a scalar recurrence so the test
// does not compare the DUT against a copy of its own vectorized implementation.
module tb_bp_ef2_parallel8_vcs;
  localparam int W = 16;
  localparam int ACC_W = 28;
  localparam int LANES = 8;
  localparam int VECTORS = 32;
  localparam longint signed Y_POS = 32767;
  localparam longint signed Y_NEG = -32767;
  localparam longint signed ACC_MAX = (1 <<< (ACC_W-1)) - 1;
  localparam longint signed ACC_MIN = -(1 <<< (ACC_W-1));

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic enable = 1'b0;
  logic [LANES*W-1:0] x_vec = '0;
  wire [LANES-1:0] y_vec;
  wire signed [LANES*W-1:0] y_signed_vec;
  wire out_valid;
  wire signed [ACC_W-1:0] v_state;

  integer x_samples [0:LANES*VECTORS-1];
  integer exp_bit [0:LANES*VECTORS-1];
  integer exp_signed [0:LANES*VECTORS-1];
  integer exp_state [0:VECTORS-1];
  integer accepted_vectors;
  integer checked_vectors;
  integer mismatch_count;
  integer n;
  integer lane;
  integer raw;
  integer quantized;
  integer ref_e1;
  integer ref_e2;

  bp_ef2_parallel8 #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b1)) dut (
    .clk(clk), .rst_n(rst_n), .enable(enable), .x_vec(x_vec),
    .y_vec(y_vec), .y_signed_vec(y_signed_vec), .out_valid(out_valid),
    .v_state(v_state)
  );

  always #5 clk = ~clk;

  initial begin : build_scalar_golden
    accepted_vectors = VECTORS;
    ref_e1 = 0;
    ref_e2 = 0;
    for (n = 0; n < LANES*VECTORS; n = n + 1) begin
      // Deterministic signed stimulus with independent extrema coverage.
      x_samples[n] = ((n * 7919 + 12345) % 65536) - 32768;
      if (n == 0) x_samples[n] = -32768;
      if (n == 37) x_samples[n] = 32767;
      raw = x_samples[n] - ref_e2;
      if (raw > ACC_MAX) raw = ACC_MAX;
      if (raw < ACC_MIN) raw = ACC_MIN;
      exp_bit[n] = (raw >= 0);
      exp_signed[n] = exp_bit[n] ? Y_POS : Y_NEG;
      quantized = exp_signed[n];
      exp_state[n / LANES] = raw;
      ref_e2 = ref_e1;
      ref_e1 = raw - quantized;
    end
  end

  initial begin : drive_vectors
    wait (accepted_vectors == VECTORS);
    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    for (n = 0; n < VECTORS; n = n + 1) begin
      // A deterministic idle gap tests that enable=0 holds the feedback state.
      if ((n % 7) == 3) begin
        @(negedge clk);
        #1 enable = 1'b0;
      end
      @(negedge clk);
      for (lane = 0; lane < LANES; lane = lane + 1)
        x_vec[lane*W +: W] = x_samples[n*LANES + lane];
      #1 enable = 1'b1;
    end
    @(negedge clk);
    #1 enable = 1'b0;
    repeat (2) @(negedge clk);
    if (checked_vectors != VECTORS)
      $fatal(1, "checked vectors mismatch: got=%0d expected=%0d",
        checked_vectors, VECTORS);
    if (mismatch_count != 0)
      $fatal(1, "parallel8 mismatches=%0d", mismatch_count);
    $display("BP_EF2_PARALLEL8_VCS_BITTRUE_PASS vectors=%0d samples=%0d",
      VECTORS, LANES*VECTORS);
    $finish;
  end

  always @(negedge clk) begin : check_outputs
    if (rst_n && enable && out_valid && checked_vectors < VECTORS) begin
      for (lane = 0; lane < LANES; lane = lane + 1) begin
        if (y_vec[lane] !== exp_bit[checked_vectors*LANES + lane]) begin
          $error("bit mismatch vector=%0d lane=%0d actual=%0d expected=%0d",
            checked_vectors, lane, y_vec[lane],
            exp_bit[checked_vectors*LANES + lane]);
          mismatch_count = mismatch_count + 1;
        end
        if ($signed(y_signed_vec[lane*W +: W]) !==
            exp_signed[checked_vectors*LANES + lane]) begin
          $error("signed mismatch vector=%0d lane=%0d actual=%0d expected=%0d",
            checked_vectors, lane,
            $signed(y_signed_vec[lane*W +: W]),
            exp_signed[checked_vectors*LANES + lane]);
          mismatch_count = mismatch_count + 1;
        end
      end
      if ($signed(v_state) !== exp_state[checked_vectors]) begin
        $error("state mismatch vector=%0d actual=%0d expected=%0d",
          checked_vectors, $signed(v_state), exp_state[checked_vectors]);
        mismatch_count = mismatch_count + 1;
      end
      checked_vectors = checked_vectors + 1;
    end
  end
endmodule

`default_nettype wire
