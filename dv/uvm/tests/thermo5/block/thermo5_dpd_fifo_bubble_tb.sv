`timescale 1ns/1ps
module thermo5_dpd_fifo_bubble_tb;
  logic clk=0, rst_n=0, src_valid=0, sink_ready=0;
  always #5 clk=~clk;
  wire src_ready, dpd_valid, dpd_ready, sink_valid;
  wire signed [15:0] dpd_i, dpd_q;
  dpd_memory_poly #(.MAX_TAPS(1), .USE_EXTERNAL_TAPS(1)) dpd (
    .clk(clk), .rst_n(rst_n), .in_valid(src_valid), .in_ready(src_ready),
    .active_taps(3'd1), .c1_re(16'sd16384), .c1_im(16'sd0),
    .c3_re(16'sd0), .c3_im(16'sd0), .c5_re(16'sd0), .c5_im(16'sd0),
    .i_in(16'sd9), .q_in(16'sd17), .i_tap_vec(16'sd9), .q_tap_vec(16'sd17),
    .out_valid(dpd_valid), .out_ready(dpd_ready), .i_out(dpd_i), .q_out(dpd_q),
    .sample_count(), .saturation_count()
  );
  wire signed [15:0] out_i, out_q;
  thermo5_vector_registered_ready_fifo #(.LANES(1),.META_W(1)) fifo (
    .clk(clk),.rst_n(rst_n),.in_ready(dpd_ready),.in_valid(dpd_valid),
    .in_meta(1'b0),.in_i_vec(dpd_i),.in_q_vec(dpd_q),
    .out_valid(sink_valid),.out_ready(sink_ready),.out_meta(),
    .out_i_vec(out_i),.out_q_vec(out_q)
  );
  int inputs, outputs, hits;
  always @(posedge clk) if (rst_n) begin
    if (src_valid && src_ready) inputs++;
    if (!dpd_ready && !dpd_valid && fifo.count_q==2) hits++;
    if (sink_valid && sink_ready) begin
      if (out_i !== 16'sd9 || out_q !== 16'sd17) $fatal(1,"payload mismatch");
      outputs++;
    end
  end
  initial begin
    repeat(2) @(negedge clk);
    rst_n=1; src_valid=1;
    repeat(2) @(negedge clk);
    src_valid=0;
    repeat(16) @(negedge clk);
    if (hits==0 || inputs!=2) $fatal(1,"no bubble/stall witness");
    sink_ready=1;
    repeat(8) @(negedge clk);
    if (outputs!=inputs) $fatal(1,"transaction count mismatch");
    $display("R6_BUBBLE_SLICE_PASS hits=%0d in=%0d out=%0d",hits,inputs,outputs);
    $finish;
  end
endmodule
