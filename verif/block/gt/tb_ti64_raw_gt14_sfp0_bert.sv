`timescale 1ps/1ps
`default_nettype none

module tb_ti64_raw_gt14_sfp0_bert;
  logic refclk_p = 1'b0;
  wire  refclk_n = ~refclk_p;
  logic freerun_p = 1'b0;
  wire  freerun_n = ~freerun_p;
  logic reset_n = 1'b0;
  wire tx_p, tx_n;
  wire tx_disable;

  // 125 MHz GTH reference and 200 MHz reset-controller clock.
  always #4000 refclk_p = ~refclk_p;
  always #2500 freerun_p = ~freerun_p;

  ti64_raw_gt14_sfp0_bert_top dut (
    .gty_230_clk_n(refclk_n), .gty_230_clk_p(refclk_p),
    .pl_ddr4_clk_n(freerun_n), .pl_ddr4_clk_p(freerun_p),
    .sfp0_rx_n(tx_n), .sfp0_rx_p(tx_p),
    .sfp0_tx_n(tx_n), .sfp0_tx_p(tx_p),
    .sfp0_tx_disable(tx_disable), .reset_n(reset_n)
  );

  initial begin
    #100000 reset_n = 1'b1;
    fork
      begin
        wait (dut.link_up === 1'b1);
        wait (dut.word_count >= 32);
        if (dut.error_sticky || dut.error_count != 0)
          $fatal(1, "vendor GT PRBS31 loopback mismatch");
        $display("TI64_RAW_GT14_VENDOR_BERT_PASS words=%0d", dut.word_count);
        $finish;
      end
      begin
        #1000000000;
        $display("GT_TIMEOUT tx_ready=%b rx_ready=%b tx_active=%b rx_active=%b tx_done=%b rx_done=%b powergood=%b cdrstable=%b",
                 dut.tx_ready, dut.rx_ready,
                 dut.u_link.tx_active_i, dut.u_link.rx_active_i,
                 dut.u_link.tx_done_i, dut.u_link.rx_done_i,
                 dut.u_link.gtpowergood_unused, dut.u_link.rxcdrstable_unused);
        $display("GT_TIMEOUT state=%0d train_tx=%0d train_rx=%0d fifo_valid=%b fifo_data=%h tx_word=%h errors=%0d",
                 dut.u_bert.state_q, dut.u_bert.train_count_q,
                 dut.u_bert.rx_train_count_q, dut.fifo_rd_valid,
                 dut.fifo_rd_data, dut.bert_tx_word, dut.error_count);
        $fatal(1, "vendor GT BERT timeout");
      end
    join_any
  end
endmodule

`default_nettype wire
