`timescale 1ns/1ps
`default_nettype none

// Board-level raw-GTH BERT integration.  The BERT runs in the TX user-clock
// domain.  Recovered RX words cross through the same Gray-pointer asynchronous
// FIFO used by the project CDC architecture; TX and RX user clocks are never
// assumed to be phase aligned.
module ti64_raw_gt14_sfp0_bert_top (
  input  wire logic gty_230_clk_n,
  input  wire logic gty_230_clk_p,
  input  wire logic pl_ddr4_clk_n,
  input  wire logic pl_ddr4_clk_p,
  input  wire logic sfp0_rx_n,
  input  wire logic sfp0_rx_p,
  output wire logic sfp0_tx_n,
  output wire logic sfp0_tx_p,
  output wire logic sfp0_tx_disable,
  input  wire logic reset_n
);
  logic tx_usrclk2, tx_ready;
  logic rx_usrclk2, rx_ready;
  logic [63:0] rx_word;
  logic [63:0] bert_tx_word;
  logic bert_tx_valid;
  logic fifo_wr_ready, fifo_wr_full;
  logic [63:0] fifo_rd_data;
  logic fifo_rd_valid, fifo_rd_empty;
  logic rx_ready_tx_q1, rx_ready_tx_q2;
  logic rx_slide;
  logic [3:0] align_wait_q;
  logic align_locked_q;
  logic [5:0] align_stable_q;

  (* mark_debug = "true" *) logic link_up;
  (* mark_debug = "true" *) logic training;
  (* mark_debug = "true" *) logic error_sticky;
  (* mark_debug = "true" *) logic [31:0] error_count;
  (* mark_debug = "true" *) logic [31:0] word_count;

  ti64_raw_gt14_sfp0_link u_link (
    .pl_ddr4_clk_n(pl_ddr4_clk_n), .pl_ddr4_clk_p(pl_ddr4_clk_p),
    .gty_230_clk_n(gty_230_clk_n), .gty_230_clk_p(gty_230_clk_p),
    .sfp0_rx_n(sfp0_rx_n), .sfp0_rx_p(sfp0_rx_p),
    .sfp0_tx_n(sfp0_tx_n), .sfp0_tx_p(sfp0_tx_p),
    .reset_n(reset_n), .tx_word(bert_tx_word),
    .tx_usrclk2(tx_usrclk2), .tx_ready(tx_ready),
    .rx_word(rx_word), .rx_usrclk2(rx_usrclk2), .rx_ready(rx_ready),
    .rx_slide(rx_slide)
  );

  dsm_async_fifo #(.DATA_W(64), .ADDR_W(4)) u_rx_cdc (
    .wr_clk(rx_usrclk2), .wr_rst_n(reset_n), .wr_data(rx_word),
    .wr_valid(rx_ready && align_locked_q), .wr_ready(fifo_wr_ready), .wr_full(fifo_wr_full),
    .rd_clk(tx_usrclk2), .rd_rst_n(reset_n), .rd_data(fifo_rd_data),
    .rd_valid(fifo_rd_valid), .rd_ready(1'b1), .rd_empty(fifo_rd_empty)
  );

  always_ff @(posedge tx_usrclk2 or negedge reset_n) begin
    if (!reset_n) begin
      rx_ready_tx_q1 <= 1'b0;
      rx_ready_tx_q2 <= 1'b0;
    end else begin
      rx_ready_tx_q1 <= rx_ready;
      rx_ready_tx_q2 <= rx_ready_tx_q1;
    end
  end

  // RAW mode has no comma aligner. During training, advance the RX gearbox
  // one bit at a time until the exact known word is observed.  Pulses are
  // separated to let the GT RX datapath settle.
  always_ff @(posedge rx_usrclk2 or negedge reset_n) begin
    if (!reset_n || !rx_ready) begin
      rx_slide <= 1'b0;
      align_wait_q <= '0;
      align_locked_q <= 1'b0;
      align_stable_q <= '0;
    end else begin
      rx_slide <= 1'b0;
      if (!align_locked_q && rx_word == 64'h0123_4567_89ab_cdef) begin
        align_wait_q <= '0;
        if (align_stable_q == 6'd31)
          align_locked_q <= 1'b1;
        else
          align_stable_q <= align_stable_q + 1'b1;
      end else if (!align_locked_q) begin
        align_stable_q <= '0;
        if (align_wait_q == 4'd15) begin
          rx_slide <= 1'b1;
          align_wait_q <= '0;
        end else begin
          align_wait_q <= align_wait_q + 1'b1;
        end
      end else begin
        align_wait_q <= '0;
      end
    end
  end

  gt_link_bringup_bist u_bert (
    .clk(tx_usrclk2), .rst_n(reset_n), .enable(1'b1),
    .tx_ready(tx_ready), .rx_ready(rx_ready_tx_q2),
    .rx_valid(fifo_rd_valid), .rx_data(fifo_rd_data),
    .inject_error(1'b0), .inject_error_once(1'b0),
    .clear_errors(1'b0), .mode_prbs31(1'b1),
    .tx_valid(bert_tx_valid), .tx_data(bert_tx_word),
    .link_up(link_up), .training(training),
    .error_sticky(error_sticky), .error_count(error_count),
    .word_count(word_count)
  );

  assign sfp0_tx_disable = ~tx_ready;

`ifndef SYNTHESIS
  always_ff @(posedge rx_usrclk2) begin
    if (reset_n && rx_ready)
      assert (fifo_wr_ready) else $fatal(1, "GT RX CDC FIFO overflow");
  end
`endif
endmodule

`default_nettype wire
