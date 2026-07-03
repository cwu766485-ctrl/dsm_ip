`timescale 1ns/1ps
`default_nettype none

module tb_p0_lp2;
  `include "tb_p0_common.svh"
  `include "tb_p0_assertions.svh"

  logic clk, rst_n, enable;
  logic sample_valid;
  logic [ADDR_W-1:0] rom_addr;
  logic i_bit, q_bit;
  logic rf_valid, rf_bit;
  logic signed [W-1:0] i_dbg, q_dbg;
  logic use_nco;
  logic [23:0] phase_inc;

  string out_bits;
  string out_summary;

  p0_top_lp2 #(
    .W(W), .ADDR_W(ADDR_W), .DEPTH(DEPTH),
    .MEM_I_FILE("rom_i.mem"),
    .MEM_Q_FILE("rom_q.mem")
  ) dut (
    .clk(clk), .rst_n(rst_n), .enable(enable),
    .use_nco(use_nco),
    .phase_inc(phase_inc),
    .sample_valid(sample_valid),
    .rom_addr(rom_addr),
    .i_bit(i_bit), .q_bit(q_bit),
    .rf_valid(rf_valid), .rf_bit(rf_bit),
    .i_dbg(i_dbg), .q_dbg(q_dbg)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  integer f_bits;
  int unsigned bb_count, cycle_count;

  initial begin
    out_bits = plusarg_or_default("OUT_BITS", "sim_bits_01_lp2.txt");
    out_summary = plusarg_or_default("OUT_SUMMARY", "summary_tb_p0_lp2.csv");
    rst_n = 1'b0;
    enable = 1'b0;
    use_nco = 1'b0;
    phase_inc = 24'h400000;
    f_bits = $fopen(out_bits, "w");
    if (f_bits == 0) begin
      $display("ERROR: cannot open %s", out_bits);
      $finish;
    end
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    enable = 1'b1;
    wait (bb_count >= N_SAMPLES);
    enable = 1'b0;
    repeat (3) @(posedge clk);
    $fclose(f_bits);
    tb_write_summary(out_summary, "tb_p0_lp2", bb_count);
    $display("TB P0 LP2 done: %0d samples", bb_count);
    if (tb_error_count != 0) $fatal(1, "TB P0 LP2 self-check failed with %0d errors", tb_error_count);
    $finish;
  end

  `P0_SIGNDOMAIN_CHECKS

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      bb_count <= 0;
      cycle_count <= 0;
    end else begin
      cycle_count <= cycle_count + 1;
      if (cycle_count > MAX_CYCLES) begin
        $display("ERROR: timeout");
        $finish;
      end
      if (sample_valid && bb_count < N_SAMPLES) begin
        $fwrite(f_bits, "%0d %0d\n", i_bit, q_bit);
        bb_count <= bb_count + 1;
      end
    end
  end
endmodule

`default_nettype wire
