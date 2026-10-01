`timescale 1ns/1ps
`default_nettype none

// Frozen 2-tap arithmetic, with a deliberate empty stage-2 slot behind a
// blocked output. This is a block-level protocol test, not thermo5 OFDM proof.
module tb_interp_x2_vector_reachable;
  localparam int N = 12;
  logic clk = 0, rst_n = 0, enable = 1;
  logic in_valid = 0, out_ready = 1;
  logic signed [15:0] in_i_vec = 0, in_q_vec = 0;
  wire in_ready, out_valid;
  wire signed [31:0] out_i_vec, out_q_vec;
  integer sent = 0, received = 0, cycles = 0, bubble_blocked = 0;
  integer stalls = 0, reset_enable = 0;
  logic signed [31:0] exp_i [0:N-1], exp_q [0:N-1];
  logic signed [15:0] prev_i = 0, prev_q = 0;
  logic signed [31:0] held_i, held_q;
  logic held = 0;

  always #5 clk = ~clk;
  dsm_interp_x2_polyphase_vector #(.W(16), .LANES_IN(1),
    .INTERP_TAPS(2)) dut (.*);

  always @(posedge clk) begin
    if (!rst_n) begin
      if (enable) reset_enable <= reset_enable + 1;
    end else begin
      cycles <= cycles + 1;
      if (cycles > 200) $fatal(1, "interp reachable timeout");
      if (!dut.s2_valid && !dut.s3_ready) bubble_blocked <= bubble_blocked + 1;
      if (in_valid && in_ready) begin
        exp_i[sent] = {((in_i_vec + prev_i) / 2), in_i_vec};
        exp_q[sent] = {((in_q_vec + prev_q) / 2), in_q_vec};
        prev_i <= in_i_vec;
        prev_q <= in_q_vec;
        sent <= sent + 1;
      end
      if (out_valid && !out_ready) begin
        stalls <= stalls + 1;
        if (held && (out_i_vec !== held_i || out_q_vec !== held_q))
          $fatal(1, "interp changed stalled output");
        held_i <= out_i_vec;
        held_q <= out_q_vec;
        held <= 1;
      end else if (out_valid && out_ready) begin
        if (received >= sent || out_i_vec !== exp_i[received] ||
            out_q_vec !== exp_q[received])
          $fatal(1, "interp mismatch word=%0d got=%h/%h exp=%h/%h",
                 received, out_i_vec, out_q_vec, exp_i[received], exp_q[received]);
        received <= received + 1;
        held <= 0;
      end else held <= 0;
    end
  end

  initial begin
    // Reset with enable high is legal for this block: reset has priority.
    repeat (3) @(negedge clk);
    rst_n = 1;
    // A lone input creates valid output followed by an empty stage-2 slot.
    @(negedge clk); in_valid = 1; in_i_vec = 16'sd200; in_q_vec = -16'sd100;
    @(negedge clk); in_valid = 0;
    wait (out_valid && !dut.s2_valid);
    @(negedge clk); out_ready = 0;
    repeat (3) @(negedge clk);
    out_ready = 1;
    // Even-valued inputs keep the independent half-sample oracle exact.
    while (sent < N) begin
      @(negedge clk);
      in_valid = (cycles % 3 != 0);
      in_i_vec = 16'(200 + 4*sent);
      in_q_vec = 16'(-100 - 4*sent);
      out_ready = (cycles % 7 != 0);
    end
    @(negedge clk); in_valid = 0; out_ready = 1;
    wait (received == N);
    @(negedge clk);
    if (!bubble_blocked || !stalls || !reset_enable)
      $fatal(1, "missing targeted bins bubble=%0d stall=%0d reset_enable=%0d",
             bubble_blocked, stalls, reset_enable);
    $display("INTERP_X2_REACHABLE_PASS words=%0d bubble_blocked=%0d stalls=%0d reset_enable=%0d",
             received, bubble_blocked, stalls, reset_enable);
    $finish;
  end
endmodule
`default_nettype wire
