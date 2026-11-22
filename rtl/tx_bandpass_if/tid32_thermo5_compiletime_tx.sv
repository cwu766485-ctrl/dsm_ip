`timescale 1ns/1ps
`default_nettype none

// Product top with one synthesis-time DSM selection. AXI-Lite retains RUN/STOP
// and DPD coefficient configuration; runtime architecture registers are absent.
// One common asynchronous reset aborts the complete transmitter epoch. Reset
// release is synchronized independently to each clock domain.
module tid32_thermo5_compiletime_tx #(
  parameter int DSM_ARCH = 0,
  parameter int W = 16,
  parameter int GAIN_W = 16,
  parameter int DPD_MAX_TAPS = 1,
  parameter int INTERP_TAPS = 2,
  parameter bit INTERP_CENTERED_CUBIC = 1'b1,
  parameter bit BYPASS_DPD = 1'b0,
  parameter bit FPGA_USE_XPM_FIFO = 1'b1
) (
  input wire logic s_axil_aclk,
  input wire logic common_aresetn,
  input wire logic [7:0] s_axil_awaddr,
  input wire logic s_axil_awvalid,
  output wire logic s_axil_awready,
  input wire logic [31:0] s_axil_wdata,
  input wire logic [3:0] s_axil_wstrb,
  input wire logic s_axil_wvalid,
  output wire logic s_axil_wready,
  output wire logic [1:0] s_axil_bresp,
  output wire logic s_axil_bvalid,
  input wire logic s_axil_bready,
  input wire logic [7:0] s_axil_araddr,
  input wire logic s_axil_arvalid,
  output wire logic s_axil_arready,
  output wire logic [31:0] s_axil_rdata,
  output wire logic [1:0] s_axil_rresp,
  output wire logic s_axil_rvalid,
  input wire logic s_axil_rready,
  input wire logic s_axis_aclk,
  input wire logic s_axis_tvalid,
  output wire logic s_axis_tready,
  input wire logic s_axis_tlast,
  input wire logic signed [14*W-1:0] s_axis_i_vec,
  input wire logic signed [14*W-1:0] s_axis_q_vec,
  input wire logic s_axis_tuser_frame_start,
  input wire logic signed [GAIN_W-1:0] s_axis_tuser_frame_gain,
  output wire logic s_axis_fifo_full,
  input wire logic core_clk,
  output wire logic core_underflow,
  output wire logic core_protocol_error,
  output wire logic core_run_request,
  output wire logic core_tx_active,
  output wire logic [3:0] pa_valid,
  output wire logic [63:0] pa_data [0:3],
  input wire logic [3:0] pa_ready,
  output wire logic cfg_busy,
  output wire logic cfg_done,
  output wire logic cfg_error,
  output wire logic [1:0] active_dsm_arch,
  output wire logic pa_contract_weighted,
  output wire logic [3:0] pa_channel_mask,
  output wire logic dsm_switch_busy,
  output wire logic pa_frame_start,
  output wire logic pa_frame_end,
  output wire logic pa_tail,
  output wire logic [15:0] pa_config_id
);
  wire logic s_axil_aresetn_local;
  wire logic s_axis_aresetn_local;
  wire logic core_aresetn_local;

  dsm_reset_sync u_axil_reset_sync (
    .clk(s_axil_aclk), .arst_n(common_aresetn), .srst_n(s_axil_aresetn_local)
  );
  dsm_reset_sync u_axis_reset_sync (
    .clk(s_axis_aclk), .arst_n(common_aresetn), .srst_n(s_axis_aresetn_local)
  );
  dsm_reset_sync u_core_reset_sync (
    .clk(core_clk), .arst_n(common_aresetn), .srst_n(core_aresetn_local)
  );

  initial begin
    if (DSM_ARCH < 0 || DSM_ARCH > 2)
      $error("DSM_ARCH must be 0 (EF1), 1 (EF2), or 2 (MASH 1-1)");
  end

  tid32_thermo5_axi_lite_axis_frontend_tx #(
    .W(W),.GAIN_W(GAIN_W),.STEP(DSM_ARCH==0 ? 7168 : 5120),
    .DPD_MAX_TAPS(DPD_MAX_TAPS),.INTERP_TAPS(INTERP_TAPS),
    .INTERP_CENTERED_CUBIC(INTERP_CENTERED_CUBIC),.BYPASS_DPD(BYPASS_DPD),
    .FPGA_USE_XPM_FIFO(FPGA_USE_XPM_FIFO),.COMMON_RESET_EPOCH(1'b1),
    .TIDSM_ORDER(2),
    .ENABLE_RUNTIME_DSM(1'b0),.STATIC_DSM_ARCH(DSM_ARCH)
  ) u_product (
    .s_axil_aclk(s_axil_aclk),.s_axil_aresetn(s_axil_aresetn_local),
    .s_axil_awaddr(s_axil_awaddr),.s_axil_awvalid(s_axil_awvalid),.s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),.s_axil_wstrb(s_axil_wstrb),.s_axil_wvalid(s_axil_wvalid),.s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),.s_axil_bvalid(s_axil_bvalid),.s_axil_bready(s_axil_bready),
    .s_axil_araddr(s_axil_araddr),.s_axil_arvalid(s_axil_arvalid),.s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),.s_axil_rresp(s_axil_rresp),.s_axil_rvalid(s_axil_rvalid),.s_axil_rready(s_axil_rready),
    .s_axis_aclk(s_axis_aclk),.s_axis_aresetn(s_axis_aresetn_local),
    .s_axis_tvalid(s_axis_tvalid),.s_axis_tready(s_axis_tready),.s_axis_tlast(s_axis_tlast),
    .s_axis_i_vec(s_axis_i_vec),.s_axis_q_vec(s_axis_q_vec),
    .s_axis_tuser_frame_start(s_axis_tuser_frame_start),.s_axis_tuser_frame_gain(s_axis_tuser_frame_gain),
    .s_axis_fifo_full(s_axis_fifo_full),.core_clk(core_clk),.core_aresetn(core_aresetn_local),
    .core_underflow(core_underflow),.core_protocol_error(core_protocol_error),
    .core_run_request(core_run_request),.core_tx_active(core_tx_active),
    .pa_valid(pa_valid),.pa_data(pa_data),.pa_ready(pa_ready),
    .cfg_busy(cfg_busy),.cfg_done(cfg_done),.cfg_error(cfg_error),
    .active_dsm_arch(active_dsm_arch),.pa_contract_weighted(pa_contract_weighted),
    .pa_channel_mask(pa_channel_mask),.dsm_switch_busy(dsm_switch_busy),
    .pa_frame_start(pa_frame_start),.pa_frame_end(pa_frame_end),.pa_tail(pa_tail),
    .pa_config_id(pa_config_id)
  );
endmodule

`default_nettype wire
