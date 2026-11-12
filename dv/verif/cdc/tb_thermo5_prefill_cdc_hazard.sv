`timescale 1ns/1ps
// Read-only source-flop delay sensitivity experiment on frozen product RTL.
// Delays are illustrative, not extracted timing or a product failure rate.
module tb_thermo5_prefill_cdc_hazard;
 reg ac=0,sc=0,cc=0,rst=0,v=0;
 always #5 ac=~ac;
 always #4 sc=~sc;
 always #2.286 cc=~cc;
 wire ready;
 tid32_thermo5_axi_lite_axis_frontend_tx #(.DPD_MAX_TAPS(1),.FPGA_USE_XPM_FIFO(0)) dut (
 .s_axil_aclk(ac),.s_axil_aresetn(rst),.s_axil_awaddr(8'd0),.s_axil_awvalid(1'b0),
 .s_axil_wdata(32'd0),.s_axil_wstrb(4'd0),.s_axil_wvalid(1'b0),.s_axil_bready(1'b1),
 .s_axil_araddr(8'd0),.s_axil_arvalid(1'b0),.s_axil_rready(1'b1),
 .s_axis_aclk(sc),.s_axis_aresetn(rst),.s_axis_tvalid(v),.s_axis_tready(ready),
 .s_axis_tlast(1'b0),.s_axis_i_vec(224'd0),.s_axis_q_vec(224'd0),
 .s_axis_tuser_frame_start(1'b0),.s_axis_tuser_frame_gain(16'h4000),
 .core_clk(cc),.core_aresetn(rst),.pa_ready(4'hf));
 wire slow_msb,fast_lsb;
 assign #0.100 slow_msb = dut.prefill_count_s[1];
 assign #0.020 fast_lsb = dut.prefill_count_s[0];
 wire skew_gray_lsb = slow_msb ^ fast_lsb;
 initial begin
  $dumpfile("prefill_hazard.vcd");
  $dumpvars(0,tb_thermo5_prefill_cdc_hazard);
  #1;rst=0;#22;rst=1;
  repeat(5) @(negedge sc);v=1;
  @(posedge sc);if(!ready)$fatal(1,"first beat blocked");
  @(negedge sc);
  @(posedge sc);if(!ready || dut.prefill_count_s != 1)$fatal(1,"predecessor absent");
  #0.040;
  if(dut.prefill_count_s !== 2 || dut.prefill_gray_s !== 3 || skew_gray_lsb !== 0)
   $fatal(1,"expected skew sensitivity absent");
  $display("PREFILL_HAZARD_WITNESS time_ps=%0t legal_count=01->10 ideal_gray=01->11 skew_gray_lsb=0 endpoint_lsb=1",$time);
  #0.100;if(skew_gray_lsb !== 1)$fatal(1,"settled Gray mismatch");
  @(negedge sc);v=0;
  $display("PREFILL_HAZARD_REPRO_PASS no_force=1 actual_source_handshakes=2 illustrative_skew_only=1");
  $finish;
 end
 initial begin #1000;$fatal(1,"watchdog");end
endmodule
