`timescale 1ns/1ps
`default_nettype none

package thermo5_gt_parent_fault_tb_pkg;
  bit model_link_good = 1'b0;
endpackage

// Minimal simulation replacements for the board-only clock buffer and GT
// Wizard. Health outputs are controllable so the parent loss/recovery policy
// can run in Linux VCS without vendor simulation libraries.
module IBUFDS_GTE4 (
  input  wire I,
  input  wire IB,
  input  wire CEB,
  output wire O,
  output wire ODIV2
);
  assign O = I & ~CEB;
  assign ODIV2 = 1'b0;
endmodule

module thermo5_qsfp_gt14_probe (
  input  wire [0:0]   gtwiz_userclk_tx_reset_in,
  output wire [0:0]   gtwiz_userclk_tx_srcclk_out,
  output wire [0:0]   gtwiz_userclk_tx_usrclk_out,
  output wire [0:0]   gtwiz_userclk_tx_usrclk2_out,
  output wire [0:0]   gtwiz_userclk_tx_active_out,
  input  wire [0:0]   gtwiz_userclk_rx_reset_in,
  output wire [0:0]   gtwiz_userclk_rx_srcclk_out,
  output wire [0:0]   gtwiz_userclk_rx_usrclk_out,
  output wire [0:0]   gtwiz_userclk_rx_usrclk2_out,
  output wire [0:0]   gtwiz_userclk_rx_active_out,
  input  wire [0:0]   gtwiz_reset_clk_freerun_in,
  input  wire [0:0]   gtwiz_reset_all_in,
  input  wire [0:0]   gtwiz_reset_tx_pll_and_datapath_in,
  input  wire [0:0]   gtwiz_reset_tx_datapath_in,
  input  wire [0:0]   gtwiz_reset_rx_pll_and_datapath_in,
  input  wire [0:0]   gtwiz_reset_rx_datapath_in,
  output wire [0:0]   gtwiz_reset_rx_cdr_stable_out,
  output wire [0:0]   gtwiz_reset_tx_done_out,
  output wire [0:0]   gtwiz_reset_rx_done_out,
  input  wire [255:0] gtwiz_userdata_tx_in,
  output wire [255:0] gtwiz_userdata_rx_out,
  input  wire [11:0]  loopback_in,
  input  wire [3:0]   rxslide_in,
  input  wire [0:0]   gtrefclk00_in,
  output wire [0:0]   qpll0outclk_out,
  output wire [0:0]   qpll0outrefclk_out,
  input  wire [3:0]   gthrxn_in,
  input  wire [3:0]   gthrxp_in,
  output wire [3:0]   gthtxn_out,
  output wire [3:0]   gthtxp_out,
  output wire [3:0]   gtpowergood_out,
  output wire [3:0]   rxpmaresetdone_out,
  output wire [3:0]   txpmaresetdone_out
);
  wire model_good = thermo5_gt_parent_fault_tb_pkg::model_link_good &&
                    !gtwiz_reset_all_in[0];
  assign gtwiz_userclk_tx_srcclk_out = gtwiz_reset_clk_freerun_in;
  assign gtwiz_userclk_tx_usrclk_out = gtwiz_reset_clk_freerun_in;
  assign gtwiz_userclk_tx_usrclk2_out = gtwiz_reset_clk_freerun_in;
  assign gtwiz_userclk_tx_active_out = {model_good && !gtwiz_userclk_tx_reset_in[0]};
  assign gtwiz_userclk_rx_srcclk_out = gtwiz_reset_clk_freerun_in;
  assign gtwiz_userclk_rx_usrclk_out = gtwiz_reset_clk_freerun_in;
  assign gtwiz_userclk_rx_usrclk2_out = gtwiz_reset_clk_freerun_in;
  assign gtwiz_userclk_rx_active_out = 1'b0;
  assign gtwiz_reset_rx_cdr_stable_out = 1'b0;
  assign gtwiz_reset_tx_done_out = {model_good};
  assign gtwiz_reset_rx_done_out = 1'b0;
  assign gtwiz_userdata_rx_out = '0;
  assign qpll0outclk_out = 1'b0;
  assign qpll0outrefclk_out = 1'b0;
  assign gthtxp_out = {4{gtwiz_userdata_tx_in[0]}};
  assign gthtxn_out = ~gthtxp_out;
  assign gtpowergood_out = {4{model_good}};
  assign rxpmaresetdone_out = '0;
  assign txpmaresetdone_out = {4{model_good}};
endmodule

module tb_thermo5_gt_parent_link_fault;
  import thermo5_gt_parent_fault_tb_pkg::*;

  logic axi_clk125 = 1'b0;
  logic axil_clk100 = 1'b0;
  logic freerun_clk200 = 1'b0;
  logic reset_n = 1'b0;
  logic fabric_clocks_stable = 1'b1;
  logic mgtrefclk125_p = 1'b0;
  logic mgtrefclk125_n = 1'b1;
  logic [3:0] qsfp_rx_p = '0;
  logic [3:0] qsfp_rx_n = '0;
  wire [3:0] qsfp_tx_p, qsfp_tx_n;
  logic s_axis_tvalid = 1'b0;
  wire s_axis_tready;
  logic s_axis_tlast = 1'b0;
  logic signed [223:0] s_axis_i_vec = '0;
  logic signed [223:0] s_axis_q_vec = '0;
  logic s_axis_frame_start = 1'b0;
  logic signed [15:0] s_axis_frame_gain = 16'sd16384;
  logic [7:0] s_axil_awaddr = '0;
  logic s_axil_awvalid = 1'b0;
  wire s_axil_awready;
  logic [31:0] s_axil_wdata = '0;
  logic [3:0] s_axil_wstrb = '0;
  logic s_axil_wvalid = 1'b0;
  wire s_axil_wready;
  wire [1:0] s_axil_bresp;
  wire s_axil_bvalid;
  logic s_axil_bready = 1'b0;
  logic [7:0] s_axil_araddr = '0;
  logic s_axil_arvalid = 1'b0;
  wire s_axil_arready;
  wire [31:0] s_axil_rdata;
  wire [1:0] s_axil_rresp;
  wire s_axil_rvalid;
  logic s_axil_rready = 1'b0;
  wire s_axis_fifo_full;
  wire core_underflow, core_protocol_error, core_clk218;
  wire link_ready, pa_enable, stream_fault;
  wire [255:0] gt_rxdata;
  integer accepted_words = 0;
  integer active_pa_words = 0;
  integer timeout_count;
  integer lane;

  always #4.0 axi_clk125 = ~axi_clk125;
  always #5.0 axil_clk100 = ~axil_clk100;
  always #2.5 freerun_clk200 = ~freerun_clk200;
  always #4.0 mgtrefclk125_p = ~mgtrefclk125_p;
  always @(posedge core_clk218)
    if (reset_n && pa_enable) active_pa_words <= active_pa_words + 1;

  thermo5_qsfp_gt14_parent #(
    .FPGA_USE_XPM_FIFO(1'b0)
  ) dut (.*);

  task automatic axil_run_write(input bit run_value);
    bit aw_done, w_done;
    begin
      aw_done = 1'b0;
      w_done = 1'b0;
      @(negedge axil_clk100);
      s_axil_awaddr = 8'h00;
      s_axil_awvalid = 1'b1;
      s_axil_wdata = run_value ? 32'h0000_0001 : 32'h0000_0000;
      s_axil_wstrb = 4'hf;
      s_axil_wvalid = 1'b1;
      while (!aw_done || !w_done) begin
        @(posedge axil_clk100);
        if (s_axil_awvalid && s_axil_awready) aw_done = 1'b1;
        if (s_axil_wvalid && s_axil_wready) w_done = 1'b1;
        @(negedge axil_clk100);
        if (aw_done) s_axil_awvalid = 1'b0;
        if (w_done) s_axil_wvalid = 1'b0;
      end
      s_axil_bready = 1'b0;
      timeout_count = 0;
      while (!s_axil_bvalid && timeout_count < 100) begin
        @(posedge axil_clk100);
        timeout_count = timeout_count + 1;
      end
      if (!s_axil_bvalid || s_axil_bresp != 2'b00)
        $fatal(1, "AXI-Lite RUN write failed value=%0d bvalid=%b bresp=%b awready=%b wready=%b axil_reset=%b link=%b",
          run_value, s_axil_bvalid, s_axil_bresp, s_axil_awready,
          s_axil_wready, dut.axil_rst_n, link_ready);
      @(negedge axil_clk100);
      s_axil_bready = 1'b1;
      @(posedge axil_clk100);
      @(negedge axil_clk100);
      s_axil_bready = 1'b0;
    end
  endtask

  task automatic send_packet(input integer first_word, input integer count);
    integer n;
    begin
      for (n = 0; n < count; n = n + 1) begin
        @(negedge axi_clk125);
        s_axis_tvalid = 1'b1;
        s_axis_tlast = (n == count-1);
        s_axis_frame_start = (n == 0);
        s_axis_frame_gain = 16'sd16384;
        for (lane = 0; lane < 8; lane = lane + 1) begin
          s_axis_i_vec[lane*16 +: 16] = first_word + n*8 + lane;
          s_axis_q_vec[lane*16 +: 16] = -(first_word + n*8 + lane);
        end
        do @(posedge axi_clk125); while (!s_axis_tready);
        accepted_words = accepted_words + 1;
      end
      @(negedge axi_clk125);
      s_axis_tvalid = 1'b0;
      s_axis_tlast = 1'b0;
      s_axis_frame_start = 1'b0;
      s_axis_i_vec = '0;
      s_axis_q_vec = '0;
    end
  endtask

  task automatic wait_for_link(input bit expected);
    begin
      timeout_count = 0;
      while ((link_ready !== expected) && timeout_count < 200) begin
        @(posedge freerun_clk200);
        timeout_count = timeout_count + 1;
      end
      if (link_ready !== expected)
        $fatal(1, "link_ready timeout expected=%0d observed=%b", expected, link_ready);
    end
  endtask

  initial begin : test_sequence
    model_link_good = 1'b1;
    repeat (8) @(posedge freerun_clk200);
    reset_n = 1'b1;
    wait_for_link(1'b1);
    wait (dut.axil_rst_n && dut.rst125_n && dut.rst218_n);
    repeat (2) @(posedge axil_clk100);

    axil_run_write(1'b1);
    fork : interrupted_packet
      send_packet(16, 32);
      begin
        wait (pa_enable === 1'b1);
        repeat (4) @(posedge core_clk218);
        @(negedge core_clk218);
        model_link_good = 1'b0;
      end
    join_any
    disable interrupted_packet;
    s_axis_tvalid = 1'b0;
    #0.1;
    if (pa_enable !== 1'b0)
      $fatal(1, "PA enable did not drop immediately on raw GT health loss");

    wait_for_link(1'b0);
    timeout_count = 0;
    while (!stream_fault && timeout_count < 50) begin
      @(posedge freerun_clk200);
      timeout_count = timeout_count + 1;
    end
    if (!stream_fault)
      $fatal(1, "active-packet GT loss was not retained as stream_fault");

    model_link_good = 1'b1;
    wait_for_link(1'b1);
    repeat (8) @(posedge freerun_clk200);
    if (!stream_fault || pa_enable)
      $fatal(1, "fault recovery re-enabled PA before external reset");

    reset_n = 1'b0;
    repeat (6) @(posedge freerun_clk200);
    if (stream_fault || pa_enable)
      $fatal(1, "external reset did not clear sticky fault and blank PA");
    reset_n = 1'b1;
    wait_for_link(1'b1);
    wait (dut.axil_rst_n && dut.rst125_n && dut.rst218_n);
    repeat (2) @(posedge axil_clk100);

    axil_run_write(1'b1);
    send_packet(256, 32);
    timeout_count = 0;
    while (!pa_enable && timeout_count < 2000) begin
      @(posedge core_clk218);
      timeout_count = timeout_count + 1;
    end
    if (!pa_enable || stream_fault || core_protocol_error)
      $fatal(1, "clean reset/restart did not restore link traffic");
    if (active_pa_words < 5)
      $fatal(1, "test did not observe active PA traffic before/after fault");

    $display("THERMO5_GT_PARENT_LINK_FAULT_PASS pa_immediate_blank=1 fault_sticky=1 reset_recovery=1 accepted=%0d pa_words=%0d",
      accepted_words, active_pa_words);
    $finish;
  end
endmodule

`default_nettype wire
