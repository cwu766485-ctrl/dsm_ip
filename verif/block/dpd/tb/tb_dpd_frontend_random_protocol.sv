`timescale 1ns/1ps
`default_nettype none

// Bypass is the exact local protocol oracle: under arbitrary valid/ready
// timing every accepted I/Q sample must emerge in order after the aligned pipe.
module tb_dpd_frontend_random_protocol;
  localparam int N = 113;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic [1:0] mode = 2'd0;
  logic signed [15:0] i_in = '0, q_in = '0;
  logic in_valid = 1'b0, out_ready = 1'b0;
  logic mp_coeff_we = 1'b0, mp_commit = 1'b0;
  logic [2:0] mp_coeff_tap = '0;
  logic [1:0] mp_coeff_order = '0;
  logic signed [15:0] mp_coeff_re = '0, mp_coeff_im = '0;
  logic safety_clear = 1'b0;
  wire in_ready, out_valid, busy, mp_active_bank, safety_fault, mp_commit_rejected;
  wire signed [15:0] i_out, q_out;
  logic signed [15:0] expected_i [0:N-1];
  logic signed [15:0] expected_q [0:N-1];
  integer sent = 0;
  integer received = 0;
  integer stall_count = 0;
  integer lfsr = 32'h3141_5926;

  always #5 clk = ~clk;

  function automatic integer next_lfsr(input integer value);
    begin
      next_lfsr = (value << 1) ^ (((value >> 31) ^ (value >> 21) ^
                                    (value >> 1) ^ value) & 1);
    end
  endfunction

  function automatic logic signed [15:0] stimulus(input integer n, input logic is_q);
    integer raw;
    begin
      case (n)
        0: stimulus = 16'sh8000;
        1: stimulus = 16'sh7fff;
        2: stimulus = 16'sd0;
        default: begin
          raw = is_q ? (n * -771 + 613) : (n * 1237 - 1009);
          stimulus = raw[15:0];
        end
      endcase
    end
  endfunction

  dpd_frontend dut (
    .clk(clk), .rst_n(rst_n), .mode(mode),
    .c1_re(16'sd16384), .c1_im(16'sd0), .c3_re(16'sd0), .c3_im(16'sd0),
    .c5_re(16'sd0), .c5_im(16'sd0), .c7_re(16'sd0), .c7_im(16'sd0),
    .mp_active_taps(3'd4), .mp_coeff_we(mp_coeff_we), .mp_commit(mp_commit),
    .mp_coeff_tap(mp_coeff_tap), .mp_coeff_order(mp_coeff_order),
    .mp_coeff_re(mp_coeff_re), .mp_coeff_im(mp_coeff_im),
    .mp_coeff_rdata_re(), .mp_coeff_rdata_im(), .mp_active_bank(mp_active_bank),
    .lut_we(1'b0), .lut_commit(1'b0), .lut_waddr('0),
    .lut_wgain_re('0), .lut_wgain_im('0), .lut_raddr('0),
    .lut_rgain_re(), .lut_rgain_im(), .lut_active_bank(),
    .safety_enable(1'b1), .safety_clear(safety_clear), .safety_fault(safety_fault),
    .mp_commit_rejected(mp_commit_rejected), .lut_commit_rejected(),
    .i_in(i_in), .q_in(q_in), .in_valid(in_valid), .in_ready(in_ready),
    .i_out(i_out), .q_out(q_out), .out_valid(out_valid), .out_ready(out_ready),
    .effective_mode_out(), .busy(busy), .sample_count(), .saturation_count()
  );

  always @(posedge clk) begin
    if (rst_n) begin
      if (in_valid && in_ready) begin
        expected_i[sent] = i_in;
        expected_q[sent] = q_in;
        sent = sent + 1;
      end
      if (out_valid && out_ready) begin
        if (i_out !== expected_i[received] || q_out !== expected_q[received])
          $fatal(1, "DPD bypass ordering mismatch n=%0d got=(%0d,%0d) expected=(%0d,%0d)",
                 received, i_out, q_out, expected_i[received], expected_q[received]);
        received = received + 1;
      end
      if (out_valid && !out_ready) stall_count = stall_count + 1;
    end
  end

  initial begin
    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    while (received < N) begin
      @(negedge clk);
      lfsr = next_lfsr(lfsr);
      out_ready = lfsr[1] | lfsr[5];
      in_valid = (sent < N) && lfsr[0];
      i_in = stimulus(sent, 1'b0);
      q_in = stimulus(sent, 1'b1);
    end
    @(negedge clk);
    in_valid = 1'b0;
    out_ready = 1'b1;
    wait (!busy);

    // Exercise sticky reject then explicit recovery on the inactive bank.
    mp_coeff_re = 16'sd30000;
    mp_coeff_we = 1'b1;
    @(negedge clk);
    mp_coeff_we = 1'b0;
    mp_commit = 1'b1;
    @(negedge clk);
    mp_commit = 1'b0;
    @(negedge clk);
    if (!mp_commit_rejected || mp_active_bank !== 1'b0)
      $fatal(1, "random DPD unsafe commit was not rejected");
    safety_clear = 1'b1;
    @(negedge clk);
    safety_clear = 1'b0;
    mp_coeff_re = 16'sd16384;
    mp_coeff_we = 1'b1;
    @(negedge clk);
    mp_coeff_we = 1'b0;
    mp_commit = 1'b1;
    @(negedge clk);
    mp_commit = 1'b0;
    @(negedge clk);
    if (mp_active_bank !== 1'b1 || safety_fault)
      $fatal(1, "random DPD safe commit/recovery failed");
    if (stall_count == 0) $fatal(1, "random DPD test did not create a stall");
    $display("DPD_RANDOM_PROTOCOL_PASS samples=%0d stalls=%0d", N, stall_count);
    $finish;
  end
endmodule

`default_nettype wire
