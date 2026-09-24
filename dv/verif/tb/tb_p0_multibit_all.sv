`timescale 1ns/1ps
`default_nettype none

module tb_p0_multibit_all;
  `include "tb_p0_common.svh"
  `include "tb_p0_assertions.svh"

  localparam int OUT_W = 8;
  localparam int Q_BITS = 4;
  localparam int ACC_W_MB = 16;

  logic clk;
  logic rst_n;
  logic enable;
  logic sample_valid;
  logic [ADDR_W-1:0] rom_addr;
  logic signed [W-1:0] i_dbg;
  logic signed [W-1:0] q_dbg;

  logic [6:0] i_bit;
  logic [6:0] q_bit;
  logic signed [OUT_W-1:0] i_y [0:6];
  logic signed [OUT_W-1:0] q_y [0:6];
  logic signed [ACC_W_MB-1:0] i_v1 [0:6];
  logic signed [ACC_W_MB-1:0] i_v2 [0:6];
  logic signed [ACC_W_MB-1:0] q_v1 [0:6];
  logic signed [ACC_W_MB-1:0] q_v2 [0:6];

  string out_lp1;
  string out_lp2;
  string out_ef1;
  string out_ef2;
  string out_mash11;
  string out_mash111;
  string out_mash22;
  string out_summary;

  integer f [0:6];
  int unsigned bb_count;
  int unsigned cycle_count;
  int k;

  rom_reader #(
    .W(W),
    .ADDR_W(ADDR_W),
    .DEPTH(DEPTH),
    .USE_FILE_ROM(1'b1),
    .MEM_I_FILE("rom_i.mem"),
    .MEM_Q_FILE("rom_q.mem")
  ) u_rom (
    .clk(clk),
    .rst_n(rst_n),
    .enable(enable),
    .addr(rom_addr),
    .i_data(i_dbg),
    .q_data(q_dbg),
    .valid(sample_valid)
  );

  genvar gi;
  generate
    for (gi = 0; gi < 7; gi = gi + 1) begin : g_dsm
      dsm_core_multibit #(
        .W_IN(W),
        .ACC_W(ACC_W_MB),
        .OUT_W(OUT_W),
        .Q_BITS(Q_BITS),
        .MB_ALGORITHM(gi),
        .SATURATE(1'b0)
      ) u_i (
        .clk(clk),
        .rst_n(rst_n),
        .enable(sample_valid),
        .x_in(i_dbg),
        .y_bit(i_bit[gi]),
        .y_code(i_y[gi]),
        .v1_state(i_v1[gi]),
        .v2_state(i_v2[gi])
      );

      dsm_core_multibit #(
        .W_IN(W),
        .ACC_W(ACC_W_MB),
        .OUT_W(OUT_W),
        .Q_BITS(Q_BITS),
        .MB_ALGORITHM(gi),
        .SATURATE(1'b1)
      ) u_q (
        .clk(clk),
        .rst_n(rst_n),
        .enable(sample_valid),
        .x_in(q_dbg),
        .y_bit(q_bit[gi]),
        .y_code(q_y[gi]),
        .v1_state(q_v1[gi]),
        .v2_state(q_v2[gi])
      );
    end
  endgenerate

  initial clk = 1'b0;
  always #5 clk = ~clk;

  initial begin
    out_lp1     = plusarg_or_default("OUT_LP1",     "sim_yout_signed_lp1_multibit.txt");
    out_lp2     = plusarg_or_default("OUT_LP2",     "sim_yout_signed_lp2_multibit.txt");
    out_ef1     = plusarg_or_default("OUT_EF1",     "sim_yout_signed_ef1_multibit.txt");
    out_ef2     = plusarg_or_default("OUT_EF2",     "sim_yout_signed_ef2_multibit.txt");
    out_mash11  = plusarg_or_default("OUT_MASH11",  "sim_yout_signed_mash11_multibit.txt");
    out_mash111 = plusarg_or_default("OUT_MASH111", "sim_yout_signed_mash111_multibit.txt");
    out_mash22  = plusarg_or_default("OUT_MASH22",  "sim_yout_signed_mash22_multibit.txt");
    out_summary = plusarg_or_default("OUT_SUMMARY", "summary_tb_p0_multibit_all.csv");

    f[0] = $fopen(out_lp1, "w");
    f[1] = $fopen(out_lp2, "w");
    f[2] = $fopen(out_ef1, "w");
    f[3] = $fopen(out_ef2, "w");
    f[4] = $fopen(out_mash11, "w");
    f[5] = $fopen(out_mash111, "w");
    f[6] = $fopen(out_mash22, "w");
    for (k = 0; k < 7; k = k + 1) begin
      if (f[k] == 0) $fatal(1, "cannot open multibit dump file %0d", k);
    end

    rst_n = 1'b0;
    enable = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    enable = 1'b1;
    wait (bb_count >= N_SAMPLES);
    enable = 1'b0;
    repeat (3) @(posedge clk);

    for (k = 0; k < 7; k = k + 1) begin
      $fclose(f[k]);
    end
    tb_write_summary(out_summary, "tb_p0_multibit_all", bb_count);
    $display("TB P0 multibit all done: %0d samples", bb_count);
    if (tb_error_count != 0) $fatal(1, "TB P0 multibit self-check failed with %0d errors", tb_error_count);
    $finish;
  end

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
        for (int idx = 0; idx < 7; idx = idx + 1) begin
          $fwrite(f[idx], "%0d %0d\n", i_y[idx], q_y[idx]);
        end
        bb_count <= bb_count + 1;
      end
    end
  end
endmodule

`default_nettype wire
