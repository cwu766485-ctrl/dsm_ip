`timescale 1ns/1ps
`default_nettype none

// Arithmetic signoff is handled by the MATLAB behavioral-vector regression.
// This companion test covers random valid/invalid samples, extrema, window
// termination, clear, and the paired/drop conservation invariant.
module tb_dpd_observer_random_protocol;
  localparam integer N = 129;
  localparam integer EXPECTED_INVALID = 12;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic enable = 1'b0;
  logic start = 1'b0;
  logic clear = 1'b0;
  logic [4:0] delay_samples = 5'd0;
  logic signed [15:0] gain_re = 16'sd16384;
  logic signed [15:0] gain_im = 16'sd0;
  logic signed [15:0] temperature_q8_8 = 16'sd6400;
  logic [31:0] window_samples = N - EXPECTED_INVALID;
  logic signed [15:0] ref_i = '0, ref_q = '0;
  logic ref_valid = 1'b0;
  logic signed [15:0] obs_i = '0, obs_q = '0;
  logic obs_last = 1'b0, obs_invalid = 1'b0, obs_valid = 1'b0;
  wire obs_ready, active, done, last_seen;
  wire [31:0] paired_count, dropped_count;
  wire [63:0] error_acc;
  wire signed [15:0] latched_temperature_q8_8;
  wire [31:0] ref_mag_acc, obs_mag_acc, obs_peak, slew_acc;
  wire [15:0] clip_count, saturation_count;
  wire [31:0] spec_bin0, spec_bin1, spec_bin2, spec_adj;
  wire [4:0] overflow_flags;
  integer driven = 0;
  integer lfsr = 32'h1234_5678;
  integer invalid_count = 0;

  always #5 clk = ~clk;

  function automatic integer next_lfsr(input integer value);
    begin
      next_lfsr = (value << 1) ^ (((value >> 31) ^ (value >> 21) ^
                                    (value >> 1) ^ value) & 1);
    end
  endfunction

  function automatic logic signed [15:0] sample(input integer n, input bit is_q);
    integer raw;
    begin
      if (n == 0) sample = 16'sh8000;
      else if (n == 1) sample = 16'sh7fff;
      else begin
        raw = is_q ? (n * -883 + 239) : (n * 1429 - 611);
        sample = raw[15:0];
      end
    end
  endfunction

  dpd_observer dut (
    .clk(clk), .rst_n(rst_n), .enable(enable), .start(start), .clear(clear),
    .delay_samples(delay_samples), .gain_re(gain_re), .gain_im(gain_im),
    .temperature_q8_8(temperature_q8_8), .window_samples(window_samples),
    .ref_i(ref_i), .ref_q(ref_q), .ref_valid(ref_valid), .obs_i(obs_i), .obs_q(obs_q),
    .obs_last(obs_last), .obs_invalid(obs_invalid), .obs_valid(obs_valid),
    .obs_ready(obs_ready), .active(active), .done(done), .last_seen(last_seen),
    .paired_count(paired_count), .dropped_count(dropped_count), .error_acc(error_acc),
    .latched_temperature_q8_8(latched_temperature_q8_8), .ref_mag_acc(ref_mag_acc),
    .obs_mag_acc(obs_mag_acc), .obs_peak(obs_peak), .clip_count(clip_count),
    .saturation_count(saturation_count), .slew_acc(slew_acc), .spec_bin0(spec_bin0),
    .spec_bin1(spec_bin1), .spec_bin2(spec_bin2), .spec_adj(spec_adj),
    .overflow_flags(overflow_flags)
  );

  initial begin
    repeat (5) @(negedge clk);
    rst_n = 1'b1;
    enable = 1'b1;
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;
    while (driven < N) begin
      @(negedge clk);
      lfsr = next_lfsr(lfsr);
      if (lfsr[0] && obs_ready) begin
        ref_i = sample(driven, 1'b0);
        ref_q = sample(driven, 1'b1);
        obs_i = sample(driven + 3, 1'b0);
        obs_q = sample(driven + 3, 1'b1);
        ref_valid = 1'b1;
        obs_valid = 1'b1;
        obs_invalid = ((driven % 11) == 3) && (driven != N-1);
        obs_last = (driven == N-1);
        if (obs_invalid) invalid_count = invalid_count + 1;
        driven = driven + 1;
      end else begin
        ref_valid = 1'b0;
        obs_valid = 1'b0;
        obs_invalid = 1'b0;
        obs_last = 1'b0;
      end
    end
    @(negedge clk);
    ref_valid = 1'b0;
    obs_valid = 1'b0;
    obs_invalid = 1'b0;
    obs_last = 1'b0;
    wait (done);
    repeat (2) @(posedge clk);
    if (active || !last_seen || invalid_count != EXPECTED_INVALID ||
        paired_count != (N - invalid_count) || dropped_count != invalid_count ||
        paired_count + dropped_count != N)
      $fatal(1, "observer random conservation/window mismatch pairs=%0d drops=%0d", paired_count, dropped_count);
    if (latched_temperature_q8_8 != temperature_q8_8 || overflow_flags != 5'd0)
      $fatal(1, "observer random metadata/overflow mismatch");

    clear = 1'b1;
    @(negedge clk);
    clear = 1'b0;
    @(negedge clk);
    if (paired_count != 0 || dropped_count != 0 || error_acc != 0 || done)
      $fatal(1, "observer clear failed");
    $display("DPD_OBSERVER_RANDOM_PROTOCOL_PASS samples=%0d invalid=%0d", N, invalid_count);
    $finish;
  end
endmodule

`default_nettype wire
