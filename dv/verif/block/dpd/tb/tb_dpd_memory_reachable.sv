`timescale 1ns/1ps
`default_nettype none

// Separate programmable-DPD stress configuration. It must not be merged into
// frozen thermo5/DPD1 code coverage or mistaken for its bit-true OFDM result.
module tb_dpd_memory_reachable;
  localparam int N = 6;
  logic clk = 0, rst_n = 0;
  logic [2:0] active_taps = 1;
  logic signed [15:0] c1_re = 16'sd32767, c1_im = 0;
  logic signed [15:0] c3_re = 0, c3_im = 0, c5_re = 0, c5_im = 0;
  logic signed [15:0] i_in = 0, q_in = 0;
  logic in_valid = 0, out_ready = 0;
  wire in_ready, out_valid;
  wire signed [15:0] i_out, q_out;
  wire [31:0] sample_count, saturation_count;
  integer sent = 0, received = 0, cycles = 0, idle_blocked = 0;
  integer sat_observed = 0, stalls = 0;
  logic signed [15:0] expected_i [0:N-1], expected_q [0:N-1];

  always #5 clk = ~clk;
  dpd_memory_poly #(.MAX_TAPS(1)) dut (
    .clk, .rst_n, .active_taps, .c1_re, .c1_im, .c3_re, .c3_im,
    .c5_re, .c5_im, .i_in, .q_in, .i_tap_vec(i_in), .q_tap_vec(q_in),
    .in_valid, .in_ready, .i_out, .q_out, .out_valid, .out_ready,
    .sample_count, .saturation_count);

  always @(posedge clk) begin
    if (rst_n) begin
      cycles <= cycles + 1;
      if (cycles > 200) $fatal(1, "DPD reachable timeout");
      if (!out_ready && !out_valid) idle_blocked <= idle_blocked + 1;
      if (out_valid && !out_ready) stalls <= stalls + 1;
      if (out_valid && (dut.sat_i || dut.sat_q)) sat_observed <= sat_observed + 1;
      if (in_valid && in_ready) begin
        // All nonzero stimuli are beyond the Q1.15 output range at gain ~2.
        expected_i[sent] = i_in < 0 ? -16'sd32768 :
                         i_in > 0 ? 16'sd32767 : 16'sd0;
        expected_q[sent] = q_in < 0 ? -16'sd32768 :
                           q_in > 0 ? 16'sd32767 : 16'sd0;
        sent <= sent + 1;
      end
      if (out_valid && out_ready) begin
        if (received >= sent || i_out !== expected_i[received] ||
            q_out !== expected_q[received])
          $fatal(1, "DPD saturation mismatch n=%0d got=%0d/%0d exp=%0d/%0d",
                 received, i_out, q_out, expected_i[received], expected_q[received]);
        received <= received + 1;
      end
    end
  end

  initial begin
    repeat (3) @(negedge clk);
    rst_n = 1;
    repeat (3) @(negedge clk); // out_ready=0, empty pipeline
    for (int n = 0; n < N; n++) begin
      @(negedge clk);
      in_valid = 1;
      i_in = n[0] ? -16'sd24000 : 16'sd24000;
      if (n == 2) i_in = 0;
      if (n >= 4) i_in = 0;
      q_in = (n == 4) ? 16'sd24000 :
             (n == 5) ? -16'sd24000 : 16'sd0;
    end
    @(negedge clk); in_valid = 0;
    repeat (20) @(negedge clk); // keep a saturated output stalled
    out_ready = 1;
    wait (received == N);
    @(negedge clk);
    if (sample_count != N || saturation_count != N-1 ||
        !idle_blocked || !sat_observed || !stalls)
      $fatal(1, "missing DPD bins count=%0d sat=%0d idle=%0d seen=%0d stall=%0d",
             sample_count, saturation_count, idle_blocked, sat_observed, stalls);
    $display("DPD_MEMORY_REACHABLE_PASS words=%0d saturation=%0d idle_blocked=%0d stalls=%0d",
             received, saturation_count, idle_blocked, stalls);
    $finish;
  end
endmodule
`default_nettype wire
