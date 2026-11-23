`timescale 1ns/1ps
`default_nettype none
// One actual product-width DPD lane. The ghost valid pipeline is reset by the
// same common epoch and advances only when the DUT accepts a pipeline step.
// It checks validity provenance; it does not prove arithmetic or system FIFO.
module formal_dpd_reset_epoch (
  input wire clk, por_n, epoch_n, in_valid, out_ready,
  input wire signed [15:0] i_in, q_in,
  input wire signed [15:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im
);
  wire rst_n = por_n && epoch_n;
  wire in_ready, out_valid;
  reg [10:0] epoch_valid;
  dpd_memory_poly #(.MAX_TAPS(1), .USE_EXTERNAL_TAPS(1)) dut (
    .clk(clk), .rst_n(rst_n), .active_taps(3'd1),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .i_in(i_in), .q_in(q_in),
    .i_tap_vec(i_in), .q_tap_vec(q_in), .in_valid(in_valid),
    .in_ready(in_ready), .i_out(), .q_out(), .out_valid(out_valid),
    .out_ready(out_ready), .sample_count(), .saturation_count()
  );
  always @(posedge clk or negedge rst_n)
    if (!rst_n) epoch_valid <= '0;
    else if (in_ready) epoch_valid <= {epoch_valid[9:0], in_valid};

  a_epoch_valid: assert property (@(posedge clk) disable iff (!por_n)
    out_valid == epoch_valid[10]);
  a_reset_clears: assert property (@(posedge clk) disable iff (!por_n)
    !epoch_n |-> !out_valid);
  c_abort_inflight: cover property (@(posedge clk) disable iff (!por_n)
    (|epoch_valid) ##1 !epoch_n);
  c_restart_output: cover property (@(posedge clk) disable iff (!por_n)
    !epoch_n ##1 epoch_n && in_valid && in_ready ##[11:25] out_valid);
  c_stall: cover property (@(posedge clk) disable iff (!rst_n)
    out_valid && !out_ready ##1 out_valid && !out_ready);
endmodule
`default_nettype wire
