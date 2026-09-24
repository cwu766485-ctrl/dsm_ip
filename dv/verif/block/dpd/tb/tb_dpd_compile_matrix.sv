`timescale 1ns/1ps
`default_nettype none

// Compile-time DPD configuration smoke regression.
// Each instance uses an identity C1 coefficient and zero nonlinear terms.
// It verifies that every supported polynomial order and memory depth accepts,
// preserves ordering, and returns the input sequence without saturation.
module tb_dpd_compile_matrix;
  localparam integer N_SAMPLES = 48;
  localparam signed [15:0] C1_IDENTITY = 16'sd16384;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic signed [15:0] i_in;
  logic signed [15:0] q_in;
  logic in_valid;
  integer in_count;
  integer out_count_poly;
  integer out_count_mem;
  integer cycle_count;

  wire p3_ready, p5_ready, p7_ready;
  wire m1_ready, m2_ready, m4_ready, m6_ready;
  wire p3_valid, p5_valid, p7_valid;
  wire m1_valid, m2_valid, m4_valid, m6_valid;
  wire signed [15:0] p3_i, p3_q, p5_i, p5_q, p7_i, p7_q;
  wire signed [15:0] m1_i, m1_q, m2_i, m2_q, m4_i, m4_q, m6_i, m6_q;
  wire [31:0] unused_count [0:13];

  always #5 clk = ~clk;

  dpd_poly #(.POLY_ORDER(3)) u_poly3 (
    .clk(clk), .rst_n(rst_n), .enable(1'b1),
    .c1_re(C1_IDENTITY), .c1_im('0), .c3_re('0), .c3_im('0),
    .c5_re('0), .c5_im('0), .c7_re('0), .c7_im('0),
    .i_in(i_in), .q_in(q_in), .in_valid(in_valid), .in_ready(p3_ready),
    .i_out(p3_i), .q_out(p3_q), .out_valid(p3_valid), .out_ready(1'b1),
    .sample_count(unused_count[0]), .saturation_count(unused_count[1])
  );

  dpd_poly #(.POLY_ORDER(5)) u_poly5 (
    .clk(clk), .rst_n(rst_n), .enable(1'b1),
    .c1_re(C1_IDENTITY), .c1_im('0), .c3_re('0), .c3_im('0),
    .c5_re('0), .c5_im('0), .c7_re('0), .c7_im('0),
    .i_in(i_in), .q_in(q_in), .in_valid(in_valid), .in_ready(p5_ready),
    .i_out(p5_i), .q_out(p5_q), .out_valid(p5_valid), .out_ready(1'b1),
    .sample_count(unused_count[2]), .saturation_count(unused_count[3])
  );

  dpd_poly #(.POLY_ORDER(7)) u_poly7 (
    .clk(clk), .rst_n(rst_n), .enable(1'b1),
    .c1_re(C1_IDENTITY), .c1_im('0), .c3_re('0), .c3_im('0),
    .c5_re('0), .c5_im('0), .c7_re('0), .c7_im('0),
    .i_in(i_in), .q_in(q_in), .in_valid(in_valid), .in_ready(p7_ready),
    .i_out(p7_i), .q_out(p7_q), .out_valid(p7_valid), .out_ready(1'b1),
    .sample_count(unused_count[4]), .saturation_count(unused_count[5])
  );

  dpd_memory_poly #(.MAX_TAPS(1)) u_mem1 (
    .clk(clk), .rst_n(rst_n), .active_taps(3'd1),
    .c1_re(C1_IDENTITY), .c1_im('0), .c3_re('0), .c3_im('0),
    .c5_re('0), .c5_im('0), .i_in(i_in), .q_in(q_in),
    .in_valid(in_valid), .in_ready(m1_ready), .i_out(m1_i), .q_out(m1_q),
    .out_valid(m1_valid), .out_ready(1'b1),
    .sample_count(unused_count[6]), .saturation_count(unused_count[7])
  );

  dpd_memory_poly #(.MAX_TAPS(2)) u_mem2 (
    .clk(clk), .rst_n(rst_n), .active_taps(3'd2),
    .c1_re({16'sd0, C1_IDENTITY}), .c1_im('0), .c3_re('0), .c3_im('0),
    .c5_re('0), .c5_im('0), .i_in(i_in), .q_in(q_in),
    .in_valid(in_valid), .in_ready(m2_ready), .i_out(m2_i), .q_out(m2_q),
    .out_valid(m2_valid), .out_ready(1'b1),
    .sample_count(unused_count[8]), .saturation_count(unused_count[9])
  );

  dpd_memory_poly #(.MAX_TAPS(4)) u_mem4 (
    .clk(clk), .rst_n(rst_n), .active_taps(3'd4),
    .c1_re({48'sd0, C1_IDENTITY}), .c1_im('0), .c3_re('0), .c3_im('0),
    .c5_re('0), .c5_im('0), .i_in(i_in), .q_in(q_in),
    .in_valid(in_valid), .in_ready(m4_ready), .i_out(m4_i), .q_out(m4_q),
    .out_valid(m4_valid), .out_ready(1'b1),
    .sample_count(unused_count[10]), .saturation_count(unused_count[11])
  );

  dpd_memory_poly #(.MAX_TAPS(6)) u_mem6 (
    .clk(clk), .rst_n(rst_n), .active_taps(3'd6),
    .c1_re({80'sd0, C1_IDENTITY}), .c1_im('0), .c3_re('0), .c3_im('0),
    .c5_re('0), .c5_im('0), .i_in(i_in), .q_in(q_in),
    .in_valid(in_valid), .in_ready(m6_ready), .i_out(m6_i), .q_out(m6_q),
    .out_valid(m6_valid), .out_ready(1'b1),
    .sample_count(unused_count[12]), .saturation_count(unused_count[13])
  );

  always_comb begin
    in_valid = rst_n && (in_count < N_SAMPLES) && p3_ready && p5_ready && p7_ready &&
               m1_ready && m2_ready && m4_ready && m6_ready;
    i_in = $signed((in_count * 97) - 2000);
    q_in = $signed(1500 - (in_count * 53));
  end

  task automatic check_pair(
    input string name,
    input logic signed [15:0] i_actual,
    input logic signed [15:0] q_actual,
    input integer index
  );
    logic signed [15:0] i_expected;
    logic signed [15:0] q_expected;
    begin
      i_expected = $signed((index * 97) - 2000);
      q_expected = $signed(1500 - (index * 53));
      if (i_actual !== i_expected || q_actual !== q_expected) begin
        $fatal(1, "%s mismatch n=%0d got=(%0d,%0d) expected=(%0d,%0d)",
               name, index, i_actual, q_actual, i_expected, q_expected);
      end
    end
  endtask

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      in_count <= 0;
      out_count_poly <= 0;
      out_count_mem <= 0;
      cycle_count <= 0;
    end else begin
      cycle_count <= cycle_count + 1;
      if (cycle_count > 2000) $fatal(1, "DPD compile matrix timeout");
      if (in_valid) in_count <= in_count + 1;
      if (p3_valid) begin
        if (!(p5_valid && p7_valid)) $fatal(1, "polynomial valid alignment failure");
        check_pair("poly3", p3_i, p3_q, out_count_poly);
        check_pair("poly5", p5_i, p5_q, out_count_poly);
        check_pair("poly7", p7_i, p7_q, out_count_poly);
        out_count_poly <= out_count_poly + 1;
      end
      if (m1_valid) begin
        if (!(m2_valid && m4_valid && m6_valid)) $fatal(1, "memory valid alignment failure");
        check_pair("mem1", m1_i, m1_q, out_count_mem);
        check_pair("mem2", m2_i, m2_q, out_count_mem);
        check_pair("mem4", m4_i, m4_q, out_count_mem);
        check_pair("mem6", m6_i, m6_q, out_count_mem);
        out_count_mem <= out_count_mem + 1;
      end
    end
  end

  initial begin
    repeat (6) @(posedge clk);
    rst_n = 1'b1;
    wait ((out_count_poly == N_SAMPLES) && (out_count_mem == N_SAMPLES));
    $display("DPD compile matrix PASS: poly=3/5/7, memory taps=1/2/4/6, samples=%0d", N_SAMPLES);
    $finish;
  end
endmodule

`default_nettype wire
