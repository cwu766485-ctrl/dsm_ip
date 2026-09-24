`timescale 1ns/1ps
`default_nettype none

module tb_gt_link_bringup_bist;
  logic clk=0, rst_n=0, enable=0, tx_ready=1, rx_ready=1;
  logic rx_valid=0, inject_error=0, inject_error_once=0, clear_errors=0, mode_prbs31=1;
  logic [63:0] rx_data=0;
  wire tx_valid, link_up, training, error_sticky;
  wire [63:0] tx_data;
  wire [31:0] error_count, word_count;

  gt_link_bringup_bist dut (.*);
  always #5 clk = ~clk;

  // One user-clock transport delay models the GT/loopback word boundary.
  always_ff @(posedge clk) begin
    rx_valid <= tx_valid;
    rx_data <= tx_data;
  end

  initial begin
    repeat (3) @(posedge clk); rst_n=1; enable=1;
    wait (link_up); repeat (32) @(posedge clk);
    if (word_count == 0 || error_sticky) $fatal(1,"PRBS31 clean loopback failed");
    // Hold the control across a complete transfer edge; this models a
    // software-triggered single-word fault injection without a race against
    // the DUT's nonblocking state update.
    inject_error=1; repeat (3) @(posedge clk); inject_error=0;
    repeat (8) @(posedge clk);
    if (!error_sticky || error_count == 0) $fatal(1,"error injection was not detected");
    clear_errors=1; @(posedge clk); clear_errors=0; enable=0;
    repeat (3) @(posedge clk); enable=1; mode_prbs31=0;
    wait (link_up); repeat (16) @(posedge clk);
    if (error_sticky) $fatal(1,"known-word recovery failed");
    $display("GT_LINK_BRINGUP_BIST_PASS prbs_words=%0d errors_detected=%0d",word_count,error_count);
    $finish;
  end
endmodule
`default_nettype wire
