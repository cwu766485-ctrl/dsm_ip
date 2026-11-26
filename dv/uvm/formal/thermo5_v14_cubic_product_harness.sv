`timescale 1ns/1ps
module thermo5_v14_cubic_product_harness (
  input logic core_clk, src_clk, cfg_clk, rst_n, source_offer,
  input logic [3:0] pa_ready
);
  logic [4:0] source_beat;
  logic prefill, source_hold;
  wire source_valid = source_offer || source_hold;
  wire source_ready;
  wire source_last = source_beat == 31;
  wire source_start = source_beat[1:0] == 0;

  always_ff @(posedge src_clk or negedge rst_n) begin
    if (!rst_n) begin
      source_beat <= 0;
      prefill <= 0;
      source_hold <= 0;
    end else begin
      source_hold <= source_valid && !source_ready;
      if (source_valid && source_ready) begin
        source_beat <= source_beat + 1'b1;
        if (source_beat == 15) prefill <= 1;
      end
    end
  end

  logic aw_complete, w_complete;
  wire aw_ready, w_ready;
  wire aw_valid = prefill && !aw_complete;
  wire w_valid = prefill && !w_complete;
  wire protocol_error, underflow;
  always_ff @(posedge cfg_clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_complete <= 0;
      w_complete <= 0;
    end else begin
      if (aw_valid && aw_ready) aw_complete <= 1;
      if (w_valid && w_ready) w_complete <= 1;
    end
  end

  tid32_thermo5_axi_lite_axis_frontend_tx #(
    .DPD_MAX_TAPS(1), .INTERP_TAPS(2), .INTERP_CENTERED_CUBIC(1),
    .FPGA_USE_XPM_FIFO(0), .TIDSM_ORDER(1), .DSM_ARCH(1), .STEP(7168)
  ) dut (
    .s_axil_aclk(cfg_clk), .s_axil_aresetn(rst_n), .s_axil_awaddr(8'h00),
    .s_axil_awvalid(aw_valid), .s_axil_awready(aw_ready),
    .s_axil_wdata(32'd1), .s_axil_wstrb(4'hf), .s_axil_wvalid(w_valid),
    .s_axil_wready(w_ready), .s_axil_bresp(), .s_axil_bvalid(), .s_axil_bready(1'b1),
    .s_axil_araddr('0), .s_axil_arvalid(1'b0), .s_axil_arready(),
    .s_axil_rdata(), .s_axil_rresp(), .s_axil_rvalid(), .s_axil_rready(1'b1),
    .s_axis_aclk(src_clk), .s_axis_aresetn(rst_n), .s_axis_tvalid(source_valid),
    .s_axis_tready(source_ready), .s_axis_tlast(source_last),
    .s_axis_i_vec('0), .s_axis_q_vec('0), .s_axis_tuser_frame_start(source_start),
    .s_axis_tuser_frame_gain(16'sd16384), .s_axis_fifo_full(),
    .core_clk(core_clk), .core_aresetn(rst_n), .core_underflow(underflow),
    .core_protocol_error(protocol_error), .core_run_request(), .core_tx_active(),
    .pa_valid(), .pa_data(), .pa_ready(pa_ready), .cfg_busy(), .cfg_done(), .cfg_error()
  );

  wire clean = !underflow && !protocol_error;
  wire target1 = dut.u_frontend.g_interp1_centered.u_interp_1.q_count == 1 &&
                 dut.u_frontend.g_interp1_centered.u_interp_1.pop_head &&
                 dut.u_frontend.g_interp1_centered.u_interp_1.push_input;
  wire target2 = dut.u_frontend.g_interp2_centered.u_interp_2.q_count == 1 &&
                 dut.u_frontend.g_interp2_centered.u_interp_2.pop_head &&
                 dut.u_frontend.g_interp2_centered.u_interp_2.push_input;
  c_run_prefill: cover property (@(posedge core_clk) disable iff (!rst_n)
    dut.core_datapath_enable && dut.core_valid && dut.core_ready && clean);
  c_exact_stage1: cover property (@(posedge core_clk) disable iff (!rst_n)
    dut.core_datapath_enable && target1 && clean);
  c_exact_stage2: cover property (@(posedge core_clk) disable iff (!rst_n)
    dut.core_datapath_enable && target2 && clean);
endmodule
