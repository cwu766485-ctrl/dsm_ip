`timescale 1ns/1ps
`default_nettype none

module tb_thermo5_fitted_dpd;
  localparam int W = 16;
  localparam int LANES = 16;
  localparam int MAX_SAMPLES = 200000;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic [2:0] active_taps;
  logic signed [63:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im;
  logic in_valid;
  logic in_ready;
  logic [1:0] in_meta;
  logic signed [LANES*W-1:0] in_i_vec, in_q_vec;
  logic out_valid;
  logic out_ready = 1'b1;
  logic [1:0] out_meta;
  logic signed [LANES*W-1:0] out_i_vec, out_q_vec;
  logic [15:0] input_i [0:MAX_SAMPLES-1];
  logic [15:0] input_q [0:MAX_SAMPLES-1];
  logic [15:0] expected_i [0:MAX_SAMPLES-1];
  logic [15:0] expected_q [0:MAX_SAMPLES-1];
  logic [15:0] coefficient_mem [0:23];
  int sample_count;
  int active_sample_count;
  int accepted_words = 0;
  int checked_words = 0;
  int checked_samples = 0;
  string vector_dir;
  string path;

  always #5 clk = ~clk;

  dpd_vector16_memory_poly #(.W(W), .LANES(LANES), .MAX_TAPS(4)) dut (
    .clk(clk), .rst_n(rst_n), .active_taps(active_taps),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im),
    .in_valid(in_valid), .in_ready(in_ready), .in_meta(in_meta),
    .in_i_vec(in_i_vec), .in_q_vec(in_q_vec),
    .out_valid(out_valid), .out_ready(out_ready), .out_meta(out_meta),
    .out_i_vec(out_i_vec), .out_q_vec(out_q_vec)
  );

  initial begin
    int fd;
    if (!$value$plusargs("VECTOR_DIR=%s", vector_dir))
      $fatal(1, "VECTOR_DIR plusarg is required");
    if (!$value$plusargs("SAMPLES=%d", sample_count))
      $fatal(1, "SAMPLES plusarg is required");
    if (!$value$plusargs("ACTIVE_TAPS=%d", active_sample_count))
      $fatal(1, "ACTIVE_TAPS plusarg is required");
    if (sample_count <= 0 || sample_count > MAX_SAMPLES || sample_count % LANES)
      $fatal(1, "SAMPLES must be a positive multiple of 16 no greater than %0d", MAX_SAMPLES);
    if (active_sample_count < 1 || active_sample_count > 4)
      $fatal(1, "ACTIVE_TAPS must be in [1,4]");

    path = $sformatf("%s/input_i.mem", vector_dir); $readmemh(path, input_i);
    path = $sformatf("%s/input_q.mem", vector_dir); $readmemh(path, input_q);
    path = $sformatf("%s/expected_i.mem", vector_dir); $readmemh(path, expected_i);
    path = $sformatf("%s/expected_q.mem", vector_dir); $readmemh(path, expected_q);
    path = $sformatf("%s/coefficients.mem", vector_dir); $readmemh(path, coefficient_mem);

    active_taps = active_sample_count[2:0];
    for (int tap = 0; tap < 4; tap++) begin
      c1_re[tap*16 +: 16] = coefficient_mem[tap];
      c1_im[tap*16 +: 16] = coefficient_mem[4+tap];
      c3_re[tap*16 +: 16] = coefficient_mem[8+tap];
      c3_im[tap*16 +: 16] = coefficient_mem[12+tap];
      c5_re[tap*16 +: 16] = coefficient_mem[16+tap];
      c5_im[tap*16 +: 16] = coefficient_mem[20+tap];
    end

    in_valid = 1'b0;
    in_meta = '0;
    in_i_vec = '0;
    in_q_vec = '0;
    repeat (5) @(negedge clk);
    rst_n = 1'b1;

    for (int first = 0; first < sample_count; first += LANES) begin
      @(negedge clk);
      in_valid = 1'b1;
      in_meta = (first == 0) ? 2'b01 :
                ((first + LANES == sample_count) ? 2'b10 : 2'b00);
      for (int lane = 0; lane < LANES; lane++) begin
        in_i_vec[lane*W +: W] = input_i[first+lane];
        in_q_vec[lane*W +: W] = input_q[first+lane];
      end
      @(posedge clk);
      if (!in_ready) $fatal(1, "unexpected input backpressure with out_ready=1");
      accepted_words++;
    end
    @(negedge clk);
    in_valid = 1'b0;
    in_meta = '0;

    repeat (MAX_SAMPLES / LANES + 64) begin
      @(negedge clk);
      if (checked_samples == sample_count) break;
    end
    if (checked_samples != sample_count)
      $fatal(1, "timeout: checked %0d/%0d samples", checked_samples, sample_count);
    if (checked_words != accepted_words)
      $fatal(1, "word count mismatch: accepted=%0d checked=%0d",
             accepted_words, checked_words);
    $display("THERMO5_FITTED_DPD_RTL_BITTRUE_PASS taps=%0d words=%0d samples=%0d",
             active_taps, checked_words, checked_samples);
    $finish;
  end

  always @(posedge clk) begin
    if (rst_n && out_valid && out_ready) begin
      for (int lane = 0; lane < LANES; lane++) begin
        if (out_i_vec[lane*W +: W] !== expected_i[checked_samples+lane] ||
            out_q_vec[lane*W +: W] !== expected_q[checked_samples+lane])
          $fatal(1, "bit-true mismatch sample=%0d lane=%0d got=(%04x,%04x) expected=(%04x,%04x)",
                 checked_samples+lane, lane,
                 out_i_vec[lane*W +: W], out_q_vec[lane*W +: W],
                 expected_i[checked_samples+lane], expected_q[checked_samples+lane]);
      end
      checked_samples += LANES;
      checked_words++;
    end
  end
endmodule

`default_nettype wire
