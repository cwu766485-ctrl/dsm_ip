`timescale 1ns/1ps
`default_nettype none

module tb_dpd_frontend;
  localparam int W = 16;
  localparam int N_IN = 256;
  localparam int MAX_CYCLES = 10000;

  logic clk;
  logic rst_n;
  logic [1:0] mode;

  logic signed [W-1:0] stim_i [0:N_IN-1];
  logic signed [W-1:0] stim_q [0:N_IN-1];

  logic signed [15:0] c1_re;
  logic signed [15:0] c1_im;
  logic signed [15:0] c3_re;
  logic signed [15:0] c3_im;
  logic signed [15:0] c5_re;
  logic signed [15:0] c5_im;

  logic signed [W-1:0] i_in;
  logic signed [W-1:0] q_in;
  logic in_valid;
  wire in_ready;
  wire signed [W-1:0] i_out;
  wire signed [W-1:0] q_out;
  wire out_valid;
  logic out_ready;
  wire [31:0] sample_count;
  wire [31:0] saturation_count;
  wire signed [15:0] lut_rgain_re;
  wire signed [15:0] lut_rgain_im;

  int unsigned in_count;
  int unsigned out_count;
  int unsigned cycle_count;
  integer fout;

  initial clk = 1'b0;
  always #5 clk = ~clk;

  dpd_frontend #(
    .W(W),
    .COEFF_W(16),
    .COEFF_FRAC(14),
    .LUT_AW(4)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .mode(mode),
    .c1_re(c1_re),
    .c1_im(c1_im),
    .c3_re(c3_re),
    .c3_im(c3_im),
    .c5_re(c5_re),
    .c5_im(c5_im),
    .lut_we(1'b0),
    .lut_commit(1'b0),
    .lut_waddr(4'd0),
    .lut_wgain_re(16'sd16384),
    .lut_wgain_im(16'sd0),
    .lut_raddr(4'd0),
    .lut_rgain_re(lut_rgain_re),
    .lut_rgain_im(lut_rgain_im),
    .lut_active_bank(),
    .i_in(i_in),
    .q_in(q_in),
    .in_valid(in_valid),
    .in_ready(in_ready),
    .i_out(i_out),
    .q_out(q_out),
    .out_valid(out_valid),
    .out_ready(out_ready),
    .sample_count(sample_count),
    .saturation_count(saturation_count)
  );

  initial begin
    integer fin;
    integer fcoef;
    integer code;
    string line;
    int idx_read;
    int ii;
    int qq;
    int c1r_i;
    int c1i_i;
    int c3r_i;
    int c3i_i;
    int c5r_i;
    int c5i_i;
    int fgets_code;

    fin = $fopen("dpd_input_iq.csv", "r");
    if (fin == 0) $fatal(1, "cannot open dpd_input_iq.csv");
    fgets_code = $fgets(line, fin);
    for (int n = 0; n < N_IN; n = n + 1) begin
      code = $fscanf(fin, "%d,%d,%d\n", idx_read, ii, qq);
      if (code != 3) $fatal(1, "bad input csv at row %0d", n);
      stim_i[n] = signed'(ii);
      stim_q[n] = signed'(qq);
    end
    $fclose(fin);

    fcoef = $fopen("dpd_coefficients.csv", "r");
    if (fcoef == 0) $fatal(1, "cannot open dpd_coefficients.csv");
    fgets_code = $fgets(line, fcoef);
    code = $fscanf(fcoef, "%d,%d,%d,%d,%d,%d\n",
                   c1r_i, c1i_i, c3r_i, c3i_i, c5r_i, c5i_i);
    if (code != 6) $fatal(1, "bad coefficient csv");
    $fclose(fcoef);

    c1_re = signed'(c1r_i);
    c1_im = signed'(c1i_i);
    c3_re = signed'(c3r_i);
    c3_im = signed'(c3i_i);
    c5_re = signed'(c5r_i);
    c5_im = signed'(c5i_i);

    fout = $fopen("dpd_rtl_iq.csv", "w");
    if (fout == 0) $fatal(1, "cannot open dpd_rtl_iq.csv");
    $fwrite(fout, "n,i_q1_15,q_q1_15\n");

    rst_n = 1'b0;
    mode = 2'd1;
    out_ready = 1'b1;

    repeat (8) @(posedge clk);
    rst_n = 1'b1;

    wait (out_count == N_IN);
    repeat (4) @(posedge clk);
    if (sample_count != N_IN) $fatal(1, "DPD frontend sample_count mismatch");
    $fclose(fout);
    $display("TB DPD frontend done: %0d samples saturation_count=%0d", out_count, saturation_count);
    $finish;
  end

  always_comb begin
    in_valid = rst_n && (in_count < N_IN) && in_ready;
    i_in = (in_count < N_IN) ? stim_i[in_count] : '0;
    q_in = (in_count < N_IN) ? stim_q[in_count] : '0;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      in_count <= 0;
      out_count <= 0;
      cycle_count <= 0;
    end else begin
      cycle_count <= cycle_count + 1;
      if (cycle_count > MAX_CYCLES) $fatal(1, "DPD frontend bit-true timeout");

      if (in_valid && in_ready) begin
        in_count <= in_count + 1;
      end

      if (out_valid && out_ready) begin
        $fwrite(fout, "%0d,%0d,%0d\n", out_count, i_out, q_out);
        out_count <= out_count + 1;
      end
    end
  end
endmodule

`default_nettype wire
