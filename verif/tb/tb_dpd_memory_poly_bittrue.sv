`timescale 1ns/1ps
`default_nettype none

module tb_dpd_memory_poly_bittrue;
  localparam int N_IN = 256;
  logic clk;
  logic rst_n;
  logic [2:0] active_taps;
  logic signed [63:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im;
  logic signed [15:0] stim_i [0:N_IN-1];
  logic signed [15:0] stim_q [0:N_IN-1];
  logic signed [15:0] i_in, q_in;
  logic in_valid;
  wire in_ready;
  wire signed [15:0] i_out, q_out;
  wire out_valid;
  integer input_count;
  integer output_count;
  integer output_file;

  initial clk = 1'b0;
  always #5 clk = ~clk;

  dpd_memory_poly dut (
    .clk(clk), .rst_n(rst_n), .active_taps(active_taps),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .i_in(i_in), .q_in(q_in),
    .in_valid(in_valid), .in_ready(in_ready), .i_out(i_out), .q_out(q_out),
    .out_valid(out_valid), .out_ready(1'b1), .sample_count(),
    .saturation_count()
  );

  initial begin
    integer input_file, coeff_file, code, ignored, ii, qq, tap_count;
    integer values [0:23];
    string line;
    input_file = $fopen("dpd_mp_input_iq.csv", "r");
    if (input_file == 0) $fatal(1, "cannot open memory-polynomial input");
    ignored = $fgets(line, input_file);
    for (int n = 0; n < N_IN; n++) begin
      code = $fscanf(input_file, "%d,%d,%d\n", ignored, ii, qq);
      if (code != 3) $fatal(1, "bad memory-polynomial input row %0d", n);
      stim_i[n] = signed'(ii);
      stim_q[n] = signed'(qq);
    end
    $fclose(input_file);
    coeff_file = $fopen("dpd_mp_coefficients.csv", "r");
    if (coeff_file == 0) $fatal(1, "cannot open memory-polynomial coefficients");
    ignored = $fgets(line, coeff_file);
    code = $fscanf(coeff_file,
      "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n",
      tap_count, values[0], values[1], values[2], values[3], values[4], values[5],
      values[6], values[7], values[8], values[9], values[10], values[11],
      values[12], values[13], values[14], values[15], values[16], values[17],
      values[18], values[19], values[20], values[21], values[22], values[23]);
    if (code != 25) $fatal(1, "bad memory-polynomial coefficient row");
    $fclose(coeff_file);
    active_taps = tap_count[2:0];
    for (int tap = 0; tap < 4; tap++) begin
      c1_re[(tap*16) +: 16] = signed'(values[tap*6]);
      c1_im[(tap*16) +: 16] = signed'(values[tap*6+1]);
      c3_re[(tap*16) +: 16] = signed'(values[tap*6+2]);
      c3_im[(tap*16) +: 16] = signed'(values[tap*6+3]);
      c5_re[(tap*16) +: 16] = signed'(values[tap*6+4]);
      c5_im[(tap*16) +: 16] = signed'(values[tap*6+5]);
    end
    output_file = $fopen("dpd_mp_rtl_iq.csv", "w");
    $fwrite(output_file, "n,i_q1_15,q_q1_15\n");
    rst_n = 1'b0;
    repeat (6) @(posedge clk);
    rst_n = 1'b1;
    wait (output_count == N_IN);
    $fclose(output_file);
    $display("DPD memory-polynomial bit-true dump complete");
    $finish;
  end

  always_comb begin
    in_valid = rst_n && (input_count < N_IN) && in_ready;
    i_in = (input_count < N_IN) ? stim_i[input_count] : 16'sd0;
    q_in = (input_count < N_IN) ? stim_q[input_count] : 16'sd0;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      input_count <= 0;
      output_count <= 0;
    end else begin
      if (in_valid && in_ready) input_count <= input_count + 1;
      if (out_valid) begin
      $fwrite(output_file, "%0d,%0d,%0d\n", output_count, i_out, q_out);
        output_count <= output_count + 1;
      end
    end
  end
endmodule

`default_nettype wire
