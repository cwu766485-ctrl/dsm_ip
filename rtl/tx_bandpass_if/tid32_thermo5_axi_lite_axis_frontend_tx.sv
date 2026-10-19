`timescale 1ns/1ps
`default_nettype none

// Thermo5 system wrapper with an AXI4-Lite control plane. The existing
// tid32_thermo5_axis_frontend_tx remains the frozen parallel-config SKU;
// this wrapper adds software-controlled DPD coefficients and run control.
module tid32_thermo5_axi_lite_axis_frontend_tx #(
  parameter int W = 16,
  parameter int GAIN_W = 16,
  parameter int STEP = 7168,
  parameter int DPD_MAX_TAPS = 4,
  parameter int INTERP_TAPS = 2,
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
  output wire logic [3:0]                      pa_valid,
  output wire logic [63:0]                     pa_data [0:3],
  input  wire logic [3:0]                      pa_ready,
  output wire logic                            cfg_busy,
  output wire logic                            cfg_done,
  output wire logic                            cfg_error
);
  logic core_enable;
  logic [2:0] dpd_active_taps;
  logic signed [63:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im;
  logic core_valid, core_ready, core_frame_start;
  logic signed [8*W-1:0] core_i_vec, core_q_vec;
  logic signed [GAIN_W-1:0] core_frame_gain;
  logic dpd_config_boundary;

  thermo5_dpd_axi_lite_cfg #(.MAX_TAPS(DPD_MAX_TAPS)) u_cfg (
    .s_axil_aclk(s_axil_aclk), .s_axil_aresetn(s_axil_aresetn),
    .s_axil_awaddr(s_axil_awaddr), .s_axil_awvalid(s_axil_awvalid), .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata), .s_axil_wstrb(s_axil_wstrb), .s_axil_wvalid(s_axil_wvalid), .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp), .s_axil_bvalid(s_axil_bvalid), .s_axil_bready(s_axil_bready),
    .s_axil_araddr(s_axil_araddr), .s_axil_arvalid(s_axil_arvalid), .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata), .s_axil_rresp(s_axil_rresp), .s_axil_rvalid(s_axil_rvalid), .s_axil_rready(s_axil_rready),
    .core_clk(core_clk), .core_aresetn(core_aresetn),
    .dpd_config_boundary(dpd_config_boundary), .core_enable(core_enable),
    .dpd_active_taps(dpd_active_taps), .c1_re(c1_re), .c1_im(c1_im),
    .c3_re(c3_re), .c3_im(c3_im), .c5_re(c5_re), .c5_im(c5_im),
    .cfg_busy(cfg_busy), .cfg_done(cfg_done), .cfg_error(cfg_error)
  );

  assign core_run_request = core_enable;

  dsm_axis14_to_core8_cdc #(
    .W(W), .GAIN_W(GAIN_W), .USE_XPM_FIFO(FPGA_USE_XPM_FIFO)
  ) u_cdc (
    .s_axis_aclk(s_axis_aclk), .s_axis_aresetn(s_axis_aresetn),
    .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready),
    .s_axis_i_vec(s_axis_i_vec), .s_axis_q_vec(s_axis_q_vec),
    .s_axis_tuser_frame_start(s_axis_tuser_frame_start),
    .s_axis_tuser_frame_gain(s_axis_tuser_frame_gain), .s_axis_fifo_full(s_axis_fifo_full),
    .core_clk(core_clk), .core_aresetn(core_aresetn), .core_enable(core_enable), .core_drain(1'b0),
    .core_valid(core_valid), .core_ready(core_ready), .core_i_vec(core_i_vec), .core_q_vec(core_q_vec),
    .core_frame_start(core_frame_start), .core_frame_gain(core_frame_gain),
    .core_underflow(core_underflow), .core_protocol_error(core_protocol_error)
  );

  tid32_thermo5_frontend_tx #(
    .W(W), .IN_LANES(8), .DPD_LANES(16), .GAIN_W(GAIN_W), .STEP(STEP),
    .MAX_TAPS(DPD_MAX_TAPS), .INTERP_TAPS(INTERP_TAPS), .BYPASS_DPD(BYPASS_DPD)
  ) u_frontend (
    .clk(core_clk), .rst_n(core_aresetn), .enable(core_enable),
    .in_valid(core_valid), .in_ready(core_ready), .in_frame_start(core_frame_start),
    .in_frame_gain(core_frame_gain), .in_i_vec(core_i_vec), .in_q_vec(core_q_vec),
    .dpd_active_taps(dpd_active_taps), .c1_re(c1_re[DPD_MAX_TAPS*16-1:0]),
    .c1_im(c1_im[DPD_MAX_TAPS*16-1:0]), .c3_re(c3_re[DPD_MAX_TAPS*16-1:0]),
    .c3_im(c3_im[DPD_MAX_TAPS*16-1:0]), .c5_re(c5_re[DPD_MAX_TAPS*16-1:0]),
    .c5_im(c5_im[DPD_MAX_TAPS*16-1:0]), .pa_valid(pa_valid), .pa_data(pa_data),
    .dpd_config_boundary(dpd_config_boundary), .pa_ready(pa_ready)
  );

  initial begin
    if (DPD_MAX_TAPS < 1 || DPD_MAX_TAPS > 4)
      $error("DPD_MAX_TAPS must be in [1,4]; got %0d", DPD_MAX_TAPS);
  end
endmodule

`default_nettype wire
