`timescale 1ns/1ps
`default_nettype none

module tb_p0_mash11_mb;
  `include "tb_p0_common.svh"
  `include "tb_p0_assertions.svh"

  logic clk, rst_n, enable;
  logic sample_valid;
  logic dsm_valid;
  logic [ADDR_W-1:0] rom_addr;
  logic i_bit, q_bit;
  logic signed [2:0] i_yout, q_yout;
  logic rf_valid;
  logic signed [W-1:0] rf_signed;
  logic signed [W-1:0] i_dbg, q_dbg;
  logic use_nco;
  logic [23:0] phase_inc;

  string out_yout;
  string out_summary;

  p0_top_mash11_mb #(
    .W(W), .ADDR_W(ADDR_W), .DEPTH(DEPTH),
    .MEM_I_FILE("rom_i.mem"),
    .MEM_Q_FILE("rom_q.mem")
  ) dut (
    .clk(clk), .rst_n(rst_n), .enable(enable),
    .use_nco(use_nco),
    .phase_inc(phase_inc),
    .sample_valid(sample_valid),
    .dsm_valid(dsm_valid),
    .rom_addr(rom_addr),
    .i_bit(i_bit), .q_bit(q_bit),
    .i_yout(i_yout), .q_yout(q_yout),
    .rf_valid(rf_valid),
    .rf_signed(rf_signed),
    .i_dbg(i_dbg), .q_dbg(q_dbg)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  integer f_yout;
  int unsigned bb_count, cycle_count;

  initial begin
    out_yout = plusarg_or_default("OUT_YOUT", "sim_yout_signed_mash11_mb.txt");
    out_summary = plusarg_or_default("OUT_SUMMARY", "summary_tb_p0_mash11_mb.csv");
    rst_n = 1'b0;
    enable = 1'b0;
    use_nco = 1'b0;
    phase_inc = 24'h400000;
    f_yout = $fopen(out_yout, "w");
    if (f_yout == 0) begin
      $display("ERROR: cannot open %s", out_yout);
      $finish;
    end
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    enable = 1'b1;
    wait (bb_count >= N_SAMPLES);
    enable = 1'b0;
    repeat (3) @(posedge clk);
    $fclose(f_yout);
    tb_write_summary(out_summary, "tb_p0_mash11_mb", bb_count);
    $display("TB P0 MASH11_MB done: %0d samples", bb_count);
    if (tb_error_count != 0) $fatal(1, "TB P0 MASH11_MB self-check failed with %0d errors", tb_error_count);
    $finish;
  end

  `P0_MASH_CHECKS(-3, 3)

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
      if (dsm_valid && bb_count < N_SAMPLES) begin
        $fwrite(f_yout, "%0d %0d\n", i_yout, q_yout);
        bb_count <= bb_count + 1;
      end
    end
  end
endmodule

`default_nettype wire
