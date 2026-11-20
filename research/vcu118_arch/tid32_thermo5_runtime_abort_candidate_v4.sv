`timescale 1ns/1ps
`default_nettype none
// Product entry point: default EF2; AXI-Lite 0x40 selects EF1/EF2/MASH while stopped.
module tid32_thermo5_runtime_abort_candidate_v4 #(
  parameter int W = 16,
  parameter int GAIN_W = 16,
  parameter int STEP = 5120,
  parameter int DPD_MAX_TAPS = 1,
  parameter int INTERP_TAPS = 2,
  parameter bit INTERP_CENTERED_CUBIC = 1'b1,
  parameter bit BYPASS_DPD = 1'b0,
  parameter bit FPGA_USE_XPM_FIFO = 1'b1
) (
  input  wire logic         s_axil_aclk,
  input  wire logic         s_axil_aresetn,
  input  wire logic [7:0]   s_axil_awaddr,
  input  wire logic         s_axil_awvalid,
  output wire logic         s_axil_awready,
  input  wire logic [31:0]  s_axil_wdata,
  input  wire logic [3:0]   s_axil_wstrb,
  input  wire logic         s_axil_wvalid,
  output wire logic         s_axil_wready,
  output wire logic [1:0]   s_axil_bresp,
  output wire logic         s_axil_bvalid,
  input  wire logic         s_axil_bready,
  input  wire logic [7:0]   s_axil_araddr,
  input  wire logic         s_axil_arvalid,
  output wire logic         s_axil_arready,
  output wire logic [31:0]  s_axil_rdata,
  output wire logic [1:0]   s_axil_rresp,
  output wire logic         s_axil_rvalid,
  input  wire logic         s_axil_rready,

  input  wire logic                            s_axis_aclk,
  input  wire logic                            s_axis_aresetn,
  input  wire logic                            s_axis_tvalid,
  output wire logic                            s_axis_tready,
  input  wire logic                            s_axis_tlast,
  input  wire logic signed [14*W-1:0]          s_axis_i_vec,
  input  wire logic signed [14*W-1:0]          s_axis_q_vec,
  input  wire logic                            s_axis_tuser_frame_start,
  input  wire logic signed [GAIN_W-1:0]        s_axis_tuser_frame_gain,
  output wire logic                            s_axis_fifo_full,

  input  wire logic                            core_clk,
  input  wire logic                            core_aresetn,
  output wire logic                            core_underflow,
  output wire logic                            core_protocol_error,
  // Core-clocked view of software RUN for adjacent always-running output
  // logic such as the GT serializer boundary.
  output wire logic                            core_run_request,
  // Remains high after RUN is cleared until all accepted frame data has
  // drained through the four-plane output.
  output wire logic                            core_tx_active,
  output wire logic [3:0]                      pa_valid,
  output wire logic [63:0]                     pa_data [0:3],
  input  wire logic [3:0]                      pa_ready,
  output wire logic                            cfg_busy,
  output wire logic                            cfg_done,
  output wire logic                            cfg_error,
  output wire logic [1:0]                      active_dsm_arch,
  output wire logic                            pa_contract_weighted,
  output wire logic [3:0]                      pa_channel_mask,
  output wire logic                            dsm_switch_busy,
  output wire logic                            pa_frame_start,pa_frame_end,pa_tail,
  output wire logic [15:0]                     pa_config_id,
  // Parent serializer/PA-enable logic must use this abort epoch reset.
  output wire logic                            serializer_epoch_aresetn,
  output wire logic                            source_epoch_aresetn
);

  // Research-only: any input reset aborts the source/Core/serializer epoch;
  // AXI-Lite itself remains responsive when only Core reset is asserted.
  wire logic abort_arst_n = s_axil_aresetn && s_axis_aresetn && core_aresetn;
  wire logic axil_epoch_n, axis_epoch_n, core_epoch_n;
  wire logic [3:0] pa_valid_internal;
  // AXI-Lite has its own reset contract. Core-only reset must leave the AXI
  // transport alive so an accepted response can complete.
  dsm_reset_sync axil_reset_sync (.clk(s_axil_aclk),.arst_n(s_axil_aresetn),.srst_n(axil_epoch_n));
  dsm_reset_sync axis_abort_sync (.clk(s_axis_aclk),.arst_n(abort_arst_n),.srst_n(axis_epoch_n));
  dsm_reset_sync core_abort_sync (.clk(core_clk),.arst_n(abort_arst_n),.srst_n(core_epoch_n));
  // The local synchronizer outputs already assert asynchronously from the
  // shared abort reset and release only after two local clock edges. Keep each
  // exported epoch in its destination domain instead of reintroducing the
  // unrelated reset inputs as a combinational output fan-in.
  assign serializer_epoch_aresetn = core_epoch_n;
  assign source_epoch_aresetn = axis_epoch_n;
  // The product backend valid registers are asynchronously reset by
  // core_epoch_n. Keep the primary output registered-domain driven instead
  // of adding a redundant combinational reset cone at the boundary.
  assign pa_valid = pa_valid_internal;

  tid32_thermo5_axi_lite_axis_frontend_tx #(
    .W(W),.GAIN_W(GAIN_W),.STEP(STEP),.DPD_MAX_TAPS(DPD_MAX_TAPS),
    .INTERP_TAPS(INTERP_TAPS),.INTERP_CENTERED_CUBIC(INTERP_CENTERED_CUBIC),
    .BYPASS_DPD(BYPASS_DPD),.FPGA_USE_XPM_FIFO(FPGA_USE_XPM_FIFO),
    .TIDSM_ORDER(2),.ENABLE_RUNTIME_DSM(1'b1)
  ) u_product(.s_axil_aresetn(axil_epoch_n),.s_axis_aresetn(axis_epoch_n),.core_aresetn(core_epoch_n),
              .pa_valid(pa_valid_internal),.*);
endmodule
`default_nettype wire
