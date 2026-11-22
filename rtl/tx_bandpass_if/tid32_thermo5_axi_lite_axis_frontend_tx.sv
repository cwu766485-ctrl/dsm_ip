`timescale 1ns/1ps
`default_nettype none

// Thermo5 system wrapper with an AXI4-Lite control plane. The existing
// tid32_thermo5_axis_frontend_tx remains the frozen parallel-config SKU;
// this wrapper adds software-controlled DPD coefficients and run control.
module tid32_thermo5_axi_lite_axis_frontend_tx #(
  parameter int W = 16,
  parameter int GAIN_W = 16,
  parameter int STEP = 5120,
  parameter int DPD_MAX_TAPS = 4,
  parameter int INTERP_TAPS = 2,
  parameter bit INTERP_CENTERED_CUBIC = 1'b1,
  parameter bit BYPASS_DPD = 1'b0,
  parameter bit FPGA_USE_XPM_FIFO = 1'b1,
  parameter bit COMMON_RESET_EPOCH = 1'b0,
  parameter int TIDSM_ORDER = 2,
  parameter bit ENABLE_RUNTIME_DSM = 1'b0,
  parameter int STATIC_DSM_ARCH = -1
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
  output wire logic [15:0]                     pa_config_id
);
  logic core_enable, run_request_async;
  logic [2:0] dpd_active_taps;
  logic signed [63:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im;
  logic core_valid, core_ready, core_frame_start, core_frame_end;
  logic signed [8*W-1:0] core_i_vec, core_q_vec;
  logic signed [GAIN_W-1:0] core_frame_gain;
  logic dpd_config_boundary;
  logic cdc_s_ready, cdc_s_valid, core_data_empty, core_prefill_ready;
  logic cdc_protocol_error;
  logic core_datapath_enable, core_draining;
  logic core_prefill_seen_q;
  logic [7:0] outstanding_words_q;
  logic core_tx_active_q;
  logic [1:0] runtime_arch;
  logic runtime_reset,arch_switch_pending;
  logic [15:0] runtime_config_id;
  (* ASYNC_REG="TRUE" *) logic arch_lock_s1,arch_lock_s2;
  (* ASYNC_REG="TRUE" *) logic arch_locked_c1,arch_locked_c2,arch_locked_c3;
  logic pre_valid,pre_ready,pre_fs,pre_fe,pre_tail;
  logic signed [32*W-1:0] pre_i,pre_q;
  logic [15:0] pre_config,pre_epoch;
  logic [3:0] legacy_pa_valid;
  logic [63:0] legacy_pa_data[0:3];
  logic backend_overflow;
  wire runtime_idle = !core_tx_active && core_data_empty && !core_valid &&
                      outstanding_words_q==0 && !pre_valid && !(|pa_valid) &&
                      !core_protocol_error;
  (* ASYNC_REG = "TRUE" *) logic run_s1, run_s2;
  (* ASYNC_REG = "TRUE" *) logic ingress_closed_c1, ingress_closed_c2, ingress_closed_c3;
  logic run_seen_s;
  logic source_frame_open_q, source_frame_error_q;
  // The TID32 / 56-word GT-user contract fixes one stop-safe quantum at
  // 32 AXI beats. AXIS packets may contain any positive number of quanta.
  localparam int SOURCE_BEATS_PER_QUANTUM = 32;
  logic [4:0] source_phase_q;
  logic ingress_closed_s;
  logic ingress_closed_status_s;
  logic tx_active_status_c, draining_status_c;
  logic [2:0] status_hold_count_q;
  (* ASYNC_REG = "TRUE" *) logic source_error_c1, source_error_c2;
  wire logic source_accept = s_axis_tvalid && s_axis_tready;
  wire logic core_accept = core_valid && core_ready;
  wire logic output_accept = ((pa_valid & pa_channel_mask)==pa_channel_mask) &&
                             ((pa_ready & pa_channel_mask)==pa_channel_mask);
  wire logic drain_complete = ingress_closed_c3 && core_data_empty &&
                              (outstanding_words_q == 0) && !core_valid && !(|pa_valid);
  wire logic source_ingress_open = (run_s2 || !run_seen_s || source_frame_open_q) &&
                                   !arch_lock_s2;
  assign ingress_closed_s = !run_s2 && run_seen_s && !source_frame_open_q;

  // Before the first RUN, preserve FIFO prefill. After RUN falls, continue
  // accepting only the already-open AXIS packet through its legal TLAST.
  assign s_axis_tready = cdc_s_ready && source_ingress_open;
  assign cdc_s_valid = s_axis_tvalid && source_ingress_open;

  always_ff @(posedge s_axis_aclk or negedge s_axis_aresetn) begin
    if (!s_axis_aresetn) begin
      run_s1 <= 1'b0;
      run_s2 <= 1'b0;
      run_seen_s <= 1'b0;
      source_frame_open_q <= 1'b0;
      source_frame_error_q <= 1'b0;
      source_phase_q <= '0;
      ingress_closed_status_s <= 1'b0;
      arch_lock_s1<=0;arch_lock_s2<=0;
    end else begin
      run_s1 <= run_request_async;
      run_s2 <= run_s1;
      arch_lock_s1<=arch_switch_pending;arch_lock_s2<=arch_lock_s1;
      ingress_closed_status_s <= ingress_closed_s;

      if (run_s2) run_seen_s <= 1'b1;

      if (source_accept) begin
        if (s_axis_tlast && source_phase_q == SOURCE_BEATS_PER_QUANTUM-1)
          source_frame_open_q <= 1'b0;
        else
          source_frame_open_q <= 1'b1;

        if (s_axis_tlast && source_phase_q != SOURCE_BEATS_PER_QUANTUM-1)
          source_frame_error_q <= 1'b1;

        if (source_phase_q == SOURCE_BEATS_PER_QUANTUM-1)
          source_phase_q <= '0;
        else
          source_phase_q <= source_phase_q + 1'b1;
      end
    end
  end

  // Source-domain frame errors are diagnostic status. Synchronize the sticky
  // indication into the core domain before combining it with gearbox errors.
  always_ff @(posedge core_clk or negedge core_aresetn) begin
    if (!core_aresetn) begin
      source_error_c1 <= 1'b0;
      source_error_c2 <= 1'b0;
    end else begin
      source_error_c1 <= source_frame_error_q;
      source_error_c2 <= source_error_c1;
    end
  end
  assign core_protocol_error = cdc_protocol_error | source_error_c2 | backend_overflow;

  /*
   * Stop/drain follows accepted AXI-Stream TLAST. Legal packet lengths are
   * positive multiples of 32 source beats, preserving the 56-output-word
   * GT-user granularity and the 56-sample gearbox alignment. An early TLAST
   * is sticky-diagnosed but does not close ingress or alter beat alignment.
   */

  // The extra synchronizer stage is conservative relative to the FIFO's
  // two-stage write-pointer synchronization.
  always_ff @(posedge core_clk or negedge core_aresetn) begin
    if (!core_aresetn) begin
      ingress_closed_c1 <= 1'b0;
      ingress_closed_c2 <= 1'b0;
      ingress_closed_c3 <= 1'b0;
    end else begin
      ingress_closed_c1 <= ingress_closed_status_s;
      ingress_closed_c2 <= ingress_closed_c1;
      ingress_closed_c3 <= ingress_closed_c2;
    end
  end

  // RUN is a request. Retain the core enable and GT user activity through
  // drain; startup waits until the FIFO's synchronized read-domain occupancy
  // shows two source beats owned by this run.
  always_ff @(posedge core_clk or negedge core_aresetn) begin
    if (!core_aresetn) begin
      core_tx_active_q <= 1'b0;
      core_prefill_seen_q <= 1'b0;
      tx_active_status_c <= 1'b0;
      draining_status_c <= 1'b0;
      status_hold_count_q <= '0;
      outstanding_words_q <= '0;
    end else begin
      // Hold each sampled status level for four core clocks so slow AXI can
      // observe it; transient changes may coalesce because these are levels.
      if (status_hold_count_q != 0) begin
        status_hold_count_q <= status_hold_count_q - 1'b1;
      end else if ({draining_status_c, tx_active_status_c} !=
                   {core_draining, core_tx_active}) begin
        {draining_status_c, tx_active_status_c} <= {core_draining, core_tx_active};
        status_hold_count_q <= 3'd3;
      end
      case ({core_accept, output_accept})
        2'b10: if (!(&outstanding_words_q)) outstanding_words_q <= outstanding_words_q + 1'b1;
        2'b01: if (outstanding_words_q != 0) outstanding_words_q <= outstanding_words_q - 1'b1;
        default: ;
      endcase

      if (!core_tx_active_q)
        core_prefill_seen_q <= 1'b0;
      else if (core_prefill_ready)
        core_prefill_seen_q <= 1'b1;

      if (core_enable)
        core_tx_active_q <= 1'b1;
      else if (core_tx_active_q && drain_complete)
        core_tx_active_q <= 1'b0;
    end
  end

  assign core_draining = core_tx_active_q && !core_enable;
  assign core_datapath_enable = core_tx_active_q &&
                                (core_prefill_seen_q || core_prefill_ready || core_draining);
  assign core_tx_active = core_enable || core_tx_active_q;

  always_ff @(posedge core_clk or negedge core_aresetn) begin
    if(!core_aresetn) begin arch_locked_c1<=0;arch_locked_c2<=0;arch_locked_c3<=0;end
    else begin
      arch_locked_c1<=arch_lock_s2;arch_locked_c2<=arch_locked_c1;arch_locked_c3<=arch_locked_c2;
    end
  end

  thermo5_dpd_axi_lite_cfg #(.MAX_TAPS(DPD_MAX_TAPS),
    .ENABLE_RUNTIME_DSM(ENABLE_RUNTIME_DSM)) u_cfg (
    .s_axil_aclk(s_axil_aclk), .s_axil_aresetn(s_axil_aresetn),
    .s_axil_awaddr(s_axil_awaddr), .s_axil_awvalid(s_axil_awvalid), .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata), .s_axil_wstrb(s_axil_wstrb), .s_axil_wvalid(s_axil_wvalid), .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp), .s_axil_bvalid(s_axil_bvalid), .s_axil_bready(s_axil_bready),
    .s_axil_araddr(s_axil_araddr), .s_axil_arvalid(s_axil_arvalid), .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata), .s_axil_rresp(s_axil_rresp), .s_axil_rvalid(s_axil_rvalid), .s_axil_rready(s_axil_rready),
    .core_clk(core_clk), .core_aresetn(core_aresetn),
    .dpd_config_boundary(dpd_config_boundary), .core_tx_active(tx_active_status_c),
    .core_draining(draining_status_c), .core_enable(core_enable),
    .run_request(run_request_async),
    .dpd_active_taps(dpd_active_taps), .c1_re(c1_re), .c1_im(c1_im),
    .c3_re(c3_re), .c3_im(c3_im), .c5_re(c5_re), .c5_im(c5_im),
    .cfg_busy(cfg_busy), .cfg_done(cfg_done), .cfg_error(cfg_error),
    .dsm_switch_idle(runtime_idle),.dsm_source_locked(arch_locked_c3),
    .dsm_switch_pending(arch_switch_pending),.dsm_switch_busy(dsm_switch_busy),
    .dsm_arch(runtime_arch),.dsm_reset_pulse(runtime_reset),.dsm_config_id(runtime_config_id)
  );

  assign core_run_request = core_enable;

  dsm_axis14_to_core8_cdc #(
    .W(W), .GAIN_W(GAIN_W), .USE_XPM_FIFO(FPGA_USE_XPM_FIFO),
    .COMMON_RESET_EPOCH(COMMON_RESET_EPOCH)
  ) u_cdc (
    .s_axis_aclk(s_axis_aclk), .s_axis_aresetn(s_axis_aresetn),
    .s_axis_tvalid(cdc_s_valid), .s_axis_tready(cdc_s_ready),
    .s_axis_i_vec(s_axis_i_vec), .s_axis_q_vec(s_axis_q_vec),
    .s_axis_tuser_frame_start(s_axis_tuser_frame_start),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tuser_frame_gain(s_axis_tuser_frame_gain), .s_axis_fifo_full(s_axis_fifo_full),
    .core_clk(core_clk), .core_aresetn(core_aresetn),
    .core_enable(core_datapath_enable), .core_drain(core_draining),
    .core_valid(core_valid), .core_ready(core_ready), .core_i_vec(core_i_vec), .core_q_vec(core_q_vec),
    .core_prefill_ready(core_prefill_ready),
    .core_frame_start(core_frame_start), .core_frame_end(core_frame_end),
    .core_frame_gain(core_frame_gain),
    .core_data_empty(core_data_empty), .core_underflow(core_underflow),
    .core_protocol_error(cdc_protocol_error)
  );

  tid32_thermo5_frontend_tx #(
    .W(W), .IN_LANES(8), .DPD_LANES(16), .GAIN_W(GAIN_W), .STEP(STEP),
    .TIDSM_ORDER(TIDSM_ORDER),
    .MAX_TAPS(DPD_MAX_TAPS), .INTERP_TAPS(INTERP_TAPS),
    .INTERP_CENTERED_CUBIC(INTERP_CENTERED_CUBIC), .BYPASS_DPD(BYPASS_DPD),
    .USE_EXTERNAL_DSM(ENABLE_RUNTIME_DSM || (STATIC_DSM_ARCH >= 0))
  ) u_frontend (
    .clk(core_clk), .rst_n(core_aresetn), .enable(core_datapath_enable),
    .in_valid(core_valid), .in_ready(core_ready), .in_frame_start(core_frame_start),
    .in_frame_end(core_frame_end),
    .in_config_id(runtime_config_id),.in_reset_epoch(16'd0),
    .in_frame_gain(core_frame_gain), .in_i_vec(core_i_vec), .in_q_vec(core_q_vec),
    .dpd_active_taps(dpd_active_taps), .c1_re(c1_re[DPD_MAX_TAPS*16-1:0]),
    .c1_im(c1_im[DPD_MAX_TAPS*16-1:0]), .c3_re(c3_re[DPD_MAX_TAPS*16-1:0]),
    .c3_im(c3_im[DPD_MAX_TAPS*16-1:0]), .c5_re(c5_re[DPD_MAX_TAPS*16-1:0]),
    .c5_im(c5_im[DPD_MAX_TAPS*16-1:0]), .pa_valid(legacy_pa_valid), .pa_data(legacy_pa_data),
    .dpd_config_boundary(dpd_config_boundary), .pa_ready(pa_ready),
    .pre_dsm_valid(pre_valid),.pre_dsm_ready(pre_ready),.pre_dsm_i_vec(pre_i),.pre_dsm_q_vec(pre_q),
    .pre_dsm_frame_start(pre_fs),.pre_dsm_frame_end(pre_fe),.pre_dsm_tail(pre_tail),
    .pre_dsm_config_id(pre_config),.pre_dsm_reset_epoch(pre_epoch)
  );

  assign active_dsm_arch = ENABLE_RUNTIME_DSM ? runtime_arch :
                           (STATIC_DSM_ARCH >= 0 ? 2'(STATIC_DSM_ARCH) :
                            (TIDSM_ORDER==1 ? 2'd0 : 2'd1));
  generate
    if(ENABLE_RUNTIME_DSM) begin : g_runtime_dsm
      thermo5_runtime_dsm_backend #(.W(W),.STEP_EF2(STEP)) u_backend(
        .clk(core_clk),.rst_n(core_aresetn),.reset_arch(runtime_reset),.arch(runtime_arch),
        .in_valid(pre_valid),.in_ready(pre_ready),.in_i_vec(pre_i),.in_q_vec(pre_q),
        .in_frame_start(pre_fs),.in_frame_end(pre_fe),.in_tail(pre_tail),
        .in_config_id(pre_config),.in_epoch(pre_epoch),
        .pa_valid(pa_valid),.pa_ready(pa_ready),.pa_data(pa_data),
        .out_frame_start(pa_frame_start),.out_frame_end(pa_frame_end),.out_tail(pa_tail),
        .out_config_id(pa_config_id),.out_epoch(),
        .weighted_contract(pa_contract_weighted),.channel_mask(pa_channel_mask),
        .overflow_error(backend_overflow));
    end else if(STATIC_DSM_ARCH >= 0) begin : g_compiletime_dsm
      thermo5_compiletime_dsm_backend #(.W(W),.DSM_ARCH(STATIC_DSM_ARCH)) u_backend(
        .clk(core_clk),.rst_n(core_aresetn),
        .in_valid(pre_valid),.in_ready(pre_ready),.in_i_vec(pre_i),.in_q_vec(pre_q),
        .in_frame_start(pre_fs),.in_frame_end(pre_fe),.in_tail(pre_tail),
        .in_config_id(pre_config),.in_epoch(pre_epoch),
        .pa_valid(pa_valid),.pa_ready(pa_ready),.pa_data(pa_data),
        .out_frame_start(pa_frame_start),.out_frame_end(pa_frame_end),.out_tail(pa_tail),
        .out_config_id(pa_config_id),.out_epoch(),
        .weighted_contract(pa_contract_weighted),.channel_mask(pa_channel_mask),
        .overflow_error(backend_overflow));
    end else begin : g_legacy_static_dsm
      assign pa_valid=legacy_pa_valid;
      for(genvar p=0;p<4;p=p+1) assign pa_data[p]=legacy_pa_data[p];
      assign pa_contract_weighted=0;assign pa_channel_mask=4'hf;
      assign pre_ready=0;assign backend_overflow=0;
      assign pa_frame_start=0;assign pa_frame_end=0;assign pa_tail=0;assign pa_config_id=0;
    end
  endgenerate

  initial begin
    if (DPD_MAX_TAPS < 1 || DPD_MAX_TAPS > 4)
      $error("DPD_MAX_TAPS must be in [1,4]; got %0d", DPD_MAX_TAPS);
    if (STATIC_DSM_ARCH < -1 || STATIC_DSM_ARCH > 2)
      $error("STATIC_DSM_ARCH must be -1 (legacy/runtime) or 0/1/2; got %0d", STATIC_DSM_ARCH);
  end

endmodule

`default_nettype wire
