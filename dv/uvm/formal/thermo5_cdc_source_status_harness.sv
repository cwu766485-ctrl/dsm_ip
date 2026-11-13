`timescale 1ns/1ps
`default_nettype none

// Product-bound legal source driver for the AXI-Lite TX packet-quantum
// contract. TLAST is generated only on accepted beat 31; no source protocol
// assumptions are added to the Formal environment.
module thermo5_cdc_source_status_harness (
  input logic axil_clk,
  input logic source_clk,
  input logic core_clk,
  input logic rst_n,
  input logic [3:0] pa_ready
);
  logic [7:0] awaddr;
  logic awvalid, awready;
  logic [31:0] wdata;
  logic [3:0] wstrb;
  logic wvalid, wready;
  logic [1:0] bresp;
  logic bvalid;
  logic [7:0] araddr;
  logic arvalid, arready;
  logic [31:0] rdata;
  logic [1:0] rresp;
  logic rvalid;
  logic signed [223:0] source_i, source_q;
  logic source_valid, source_ready, source_last, source_frame_start;
  logic signed [15:0] source_gain;
  logic source_fifo_full;
  logic core_underflow, core_protocol_error;
  logic core_run_request, core_tx_active;
  logic [3:0] pa_valid;
  logic [63:0] pa_data [0:3];
  logic cfg_busy, cfg_done, cfg_error;

  logic aw_sent, w_sent, run_write_done;
  logic [5:0] source_beat;

  assign awaddr = 8'h00;
  assign wdata = 32'h0000_0001;
  assign wstrb = 4'b0001;
  assign awvalid = !aw_sent;
  assign wvalid = !w_sent;
  assign araddr = '0;
  assign arvalid = 1'b0;

  always_ff @(posedge axil_clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_sent <= 1'b0;
      w_sent <= 1'b0;
      run_write_done <= 1'b0;
    end else begin
      if (awvalid && awready) aw_sent <= 1'b1;
      if (wvalid && wready) w_sent <= 1'b1;
      if (bvalid) run_write_done <= 1'b1;
    end
  end

  assign source_valid = run_write_done && (source_beat < 32);
  assign source_last = (source_beat == 31);
  assign source_frame_start = (source_beat == 0);
  assign source_i = '0;
  assign source_q = '0;
  assign source_gain = 16'sd16384;

  always_ff @(posedge source_clk or negedge rst_n) begin
    if (!rst_n) source_beat <= '0;
    else if (source_valid && source_ready) source_beat <= source_beat + 1'b1;
  end

  tid32_thermo5_axi_lite_axis_frontend_tx #(
    .W(16), .GAIN_W(16), .STEP(5120), .DPD_MAX_TAPS(1),
    .INTERP_TAPS(2), .INTERP_CENTERED_CUBIC(1'b1),
    .BYPASS_DPD(1'b0), .FPGA_USE_XPM_FIFO(1'b0), .TIDSM_ORDER(2)
  ) dut (
    .s_axil_aclk(axil_clk), .s_axil_aresetn(rst_n),
    .s_axil_awaddr(awaddr), .s_axil_awvalid(awvalid), .s_axil_awready(awready),
    .s_axil_wdata(wdata), .s_axil_wstrb(wstrb), .s_axil_wvalid(wvalid), .s_axil_wready(wready),
    .s_axil_bresp(bresp), .s_axil_bvalid(bvalid), .s_axil_bready(1'b1),
    .s_axil_araddr(araddr), .s_axil_arvalid(arvalid), .s_axil_arready(arready),
    .s_axil_rdata(rdata), .s_axil_rresp(rresp), .s_axil_rvalid(rvalid), .s_axil_rready(1'b1),
    .s_axis_aclk(source_clk), .s_axis_aresetn(rst_n),
    .s_axis_tvalid(source_valid), .s_axis_tready(source_ready),
    .s_axis_tlast(source_last), .s_axis_i_vec(source_i), .s_axis_q_vec(source_q),
    .s_axis_tuser_frame_start(source_frame_start),
    .s_axis_tuser_frame_gain(source_gain), .s_axis_fifo_full(source_fifo_full),
    .core_clk(core_clk), .core_aresetn(rst_n),
    .core_underflow(core_underflow), .core_protocol_error(core_protocol_error),
    .core_run_request(core_run_request), .core_tx_active(core_tx_active),
    .pa_valid(pa_valid), .pa_data(pa_data), .pa_ready(pa_ready),
    .cfg_busy(cfg_busy), .cfg_done(cfg_done), .cfg_error(cfg_error)
  );

  a_closed_source_register: assert property (@(posedge source_clk) disable iff(!rst_n)
    $past(rst_n) |-> dut.ingress_closed_status_s == $past(dut.ingress_closed_s));
  a_fifo_prefill_threshold: assert property (@(posedge core_clk) disable iff(!rst_n)
    dut.core_prefill_ready == (dut.u_cdc.fifo_rd_count >= 2));
  a_startup_gate: assert property (@(posedge core_clk) disable iff(!rst_n)
    dut.core_datapath_enable |-> (dut.core_prefill_seen_q || dut.core_prefill_ready || dut.core_draining));
  a_prefill_sticky_while_active: assert property (@(posedge core_clk) disable iff(!rst_n)
    dut.core_tx_active_q && dut.core_prefill_seen_q && !dut.drain_complete |=> dut.core_prefill_seen_q);
  a_status_change_starts_hold: assert property (@(posedge core_clk) disable iff(!rst_n)
    $changed({dut.draining_status_c, dut.tx_active_status_c}) |->
      dut.status_hold_count_q == 3);
  a_status_hold_stable: assert property (@(posedge core_clk) disable iff(!rst_n)
    dut.status_hold_count_q != 0 |=>
      $stable({dut.draining_status_c, dut.tx_active_status_c}));
  c_prefill: cover property (@(posedge core_clk) disable iff(!rst_n)
    dut.core_prefill_ready && dut.core_datapath_enable);
  c_status_hold: cover property (@(posedge core_clk) disable iff(!rst_n)
    dut.status_hold_count_q == 3);
  c_output: cover property (@(posedge core_clk) disable iff(!rst_n) |pa_valid);
endmodule
`default_nettype wire
