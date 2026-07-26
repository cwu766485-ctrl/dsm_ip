`timescale 1ns/1ps
`default_nettype none

module tb_dpd_feature_gates;
  localparam integer N = 20;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic [1:0] mode;
  logic signed [15:0] i_in;
  logic signed [15:0] q_in;
  logic in_valid;
  wire in_ready;
  wire signed [15:0] i_out;
  wire signed [15:0] q_out;
  wire out_valid;
  logic out_ready = 1'b1;
  integer input_count;
  integer output_count;
  logic signed [15:0] expected_i [0:N-1];
  logic signed [15:0] expected_q [0:N-1];

  always #5 clk = ~clk;

  // Product-minimal configuration: unsupported runtime modes must become
  // deterministic bypass rather than leaving a disconnected datapath.
  dpd_frontend #(
    .ENABLE_DPD_POLY(0),
    .ENABLE_DPD_LUT(0),
    .ENABLE_DPD_MEMORY(0)
  ) dut (
    .clk(clk), .rst_n(rst_n), .mode(mode),
    .c1_re(16'sd16384), .c1_im(16'sd0), .c3_re(16'sd0), .c3_im(16'sd0),
    .c5_re(16'sd0), .c5_im(16'sd0), .c7_re(16'sd0), .c7_im(16'sd0),
    .mp_active_taps(3'd1), .mp_coeff_we(1'b0), .mp_commit(1'b0),
    .mp_coeff_tap(3'd0), .mp_coeff_order(2'd0),
    .mp_coeff_re(16'sd0), .mp_coeff_im(16'sd0),
    .mp_coeff_rdata_re(), .mp_coeff_rdata_im(), .mp_active_bank(),
    .lut_we(1'b0), .lut_commit(1'b0), .lut_waddr(4'd0),
    .lut_wgain_re(16'sd0), .lut_wgain_im(16'sd0), .lut_raddr(4'd0),
    .lut_rgain_re(), .lut_rgain_im(), .lut_active_bank(),
    .safety_enable(1'b0), .safety_clear(1'b0), .safety_fault(),
    .mp_commit_rejected(), .lut_commit_rejected(),
    .i_in(i_in), .q_in(q_in), .in_valid(in_valid), .in_ready(in_ready),
    .i_out(i_out), .q_out(q_out), .out_valid(out_valid), .out_ready(out_ready),
    .sample_count(), .saturation_count()
  );

  always_comb begin
    in_valid = rst_n && (input_count < N);
    i_in = (input_count * 97) - 900;
    q_in = 700 - (input_count * 53);
    // Exercise bypass, polynomial, LUT, and memory mode requests.
    mode = input_count[1:0];
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      input_count <= 0;
      output_count <= 0;
    end else begin
      if (in_valid && in_ready) begin
        expected_i[input_count] <= i_in;
        expected_q[input_count] <= q_in;
        input_count <= input_count + 1;
      end
      if (out_valid && out_ready) begin
        if (i_out !== expected_i[output_count] || q_out !== expected_q[output_count])
          $fatal(1, "feature gate bypass mismatch n=%0d got=(%0d,%0d) expected=(%0d,%0d)",
                 output_count, i_out, q_out, expected_i[output_count], expected_q[output_count]);
        output_count <= output_count + 1;
      end
    end
  end

  initial begin
    repeat (6) @(posedge clk);
    rst_n = 1'b1;
    wait (output_count == N);
    $display("DPD feature-gate PASS samples=%0d", output_count);
    $finish;
  end
endmodule

`default_nettype wire
