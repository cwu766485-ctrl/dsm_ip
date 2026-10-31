`timescale 1ns/1ps
`default_nettype none

// Product-bound legal source driver for the AXI-Lite TX packet-quantum
// contract. TLAST is generated only on accepted beat 31; no source protocol
// assumptions are added to the Formal environment.
module thermo5_source_frame_contract_harness (
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

  // This assertion targets the exact defensive error branch at line 141.
  // The legal packet-end Cover is required so the assertion is non-vacuous;
  // the matching malformed-TLAST Cover should be unreachable under this
  // deterministic legal public source sequence.
  a_no_early_tlast:
    assert property (@(posedge source_clk) disable iff (!rst_n)
      (dut.source_accept && source_last) |-> (dut.source_phase_q == 5'd31));

  c_source_accept: cover property (@(posedge source_clk) disable iff (!rst_n)
    dut.source_accept);
  c_legal_packet_end: cover property (@(posedge source_clk) disable iff (!rst_n)
    dut.source_accept && source_last && (dut.source_phase_q == 5'd31));
  c_early_tlast_target: cover property (@(posedge source_clk) disable iff (!rst_n)
    dut.source_accept && source_last && (dut.source_phase_q != 5'd31));
endmodule

`default_nettype wire
