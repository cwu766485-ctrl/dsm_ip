`timescale 1ns/1ps
`default_nettype none

module tb_dpd_poly7_bittrue;
  localparam int W = 16;
  localparam int N_IN = 256;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic signed [W-1:0] stimulus_i [0:N_IN-1];
  logic signed [W-1:0] stimulus_q [0:N_IN-1];
  logic signed [W-1:0] expected_i [0:N_IN-1];
  logic signed [W-1:0] expected_q [0:N_IN-1];
  logic signed [15:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im, c7_re, c7_im;
  logic signed [W-1:0] i_in, q_in;
  logic in_valid, out_ready;
  wire in_ready, out_valid;
  wire signed [W-1:0] i_out, q_out;
  wire [31:0] sample_count, saturation_count;
  integer in_count, out_count, cycle_count, mismatch_count, fout;

  always #5 clk = ~clk;

  dpd_poly #(.W(W), .COEFF_W(16), .COEFF_FRAC(14), .POLY_ORDER(7)) dut (
    .clk(clk), .rst_n(rst_n), .enable(1'b1),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .c7_re(c7_re), .c7_im(c7_im),
    .i_in(i_in), .q_in(q_in), .in_valid(in_valid), .in_ready(in_ready),
    .i_out(i_out), .q_out(q_out), .out_valid(out_valid), .out_ready(out_ready),
    .sample_count(sample_count), .saturation_count(saturation_count)
  );

  initial begin
    integer fin, fexp, fcoef, code, nread, iv, qv, sat_unused;
    integer c1r, c1i, c3r, c3i, c5r, c5i, c7r, c7i;
    string line;
    fin = $fopen("dpd7_input_iq.csv", "r");
    if (fin == 0) $fatal(1, "cannot open dpd7_input_iq.csv");
    code = $fgets(line, fin);
    for (int n = 0; n < N_IN; n = n + 1) begin
      code = $fscanf(fin, "%d,%d,%d\n", nread, iv, qv);
      if (code != 3) $fatal(1, "bad input csv row %0d", n);
      stimulus_i[n] = iv; stimulus_q[n] = qv;
    end
    $fclose(fin);
    fexp = $fopen("dpd7_expected_iq.csv", "r");
    if (fexp == 0) $fatal(1, "cannot open dpd7_expected_iq.csv");
    code = $fgets(line, fexp);
    for (int n = 0; n < N_IN; n = n + 1) begin
      code = $fscanf(fexp, "%d,%d,%d,%d\n", nread, iv, qv, sat_unused);
      if (code != 4) $fatal(1, "bad expected csv row %0d", n);
      expected_i[n] = iv; expected_q[n] = qv;
    end
    $fclose(fexp);
    fcoef = $fopen("dpd7_coefficients.csv", "r");
    if (fcoef == 0) $fatal(1, "cannot open dpd7_coefficients.csv");
    code = $fgets(line, fcoef);
    code = $fscanf(fcoef, "%d,%d,%d,%d,%d,%d,%d,%d\n", c1r, c1i, c3r, c3i, c5r, c5i, c7r, c7i);
    if (code != 8) $fatal(1, "bad seventh-order coefficient csv");
    $fclose(fcoef);
    c1_re = c1r; c1_im = c1i; c3_re = c3r; c3_im = c3i;
    c5_re = c5r; c5_im = c5i; c7_re = c7r; c7_im = c7i;
    fout = $fopen("dpd7_rtl_iq.csv", "w");
    if (fout == 0) $fatal(1, "cannot create dpd7_rtl_iq.csv");
    $fwrite(fout, "n,i_q1_15,q_q1_15\n");
    out_ready = 1'b1;
    repeat (8) @(posedge clk);
    rst_n = 1'b1;
    wait (out_count == N_IN);
    repeat (3) @(posedge clk);
    if (sample_count != N_IN) $fatal(1, "sample count mismatch");
    if (mismatch_count != 0) $fatal(1, "seventh-order bit-true mismatch count %0d", mismatch_count);
    $fclose(fout);
    $display("DPD polynomial seventh-order PASS: %0d samples", out_count);
    $finish;
  end

  always_comb begin
    in_valid = rst_n && in_count < N_IN && in_ready;
    i_in = (in_count < N_IN) ? stimulus_i[in_count] : '0;
    q_in = (in_count < N_IN) ? stimulus_q[in_count] : '0;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      in_count <= 0; out_count <= 0; cycle_count <= 0; mismatch_count <= 0;
    end
    else begin
      cycle_count <= cycle_count + 1;
      if (cycle_count > 10000) $fatal(1, "seventh-order timeout");
      if (in_valid && in_ready) in_count <= in_count + 1;
      if (out_valid && out_ready) begin
        $fwrite(fout, "%0d,%0d,%0d\n", out_count, i_out, q_out);
        if ((i_out !== expected_i[out_count]) || (q_out !== expected_q[out_count])) begin
          mismatch_count <= mismatch_count + 1;
          if (mismatch_count < 8) begin
            $display("MISMATCH n=%0d rtl=(%0d,%0d) expected=(%0d,%0d)",
                     out_count, i_out, q_out, expected_i[out_count], expected_q[out_count]);
            $display("  RTL state r2=%0d r4=%0d r6=%0d gain=(%0d,%0d) raw=(%0d,%0d)",
                     dut.r2_s2, dut.r4_s3, dut.r6_s4, dut.gain_re_s5,
                     dut.gain_im_s5, dut.dpd_i_wide_s7, dut.dpd_q_wide_s7);
          end
        end
        out_count <= out_count + 1;
      end
    end
  end
endmodule

`default_nettype wire
