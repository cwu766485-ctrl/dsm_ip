`timescale 1ns/1ps
`default_nettype none

module dsm_ip_axi_top #(
  parameter integer W = 16,
  parameter integer DSM_OUT_W = 8,
  parameter integer RF_W = 16,
  parameter integer PHASE_W = 24,
  parameter integer LUT_AW = 10,
  parameter integer TW_W = 16,
  parameter integer DPD_LUT_AW = 4,
  parameter integer DPD_MP_MAX_TAPS = 4,
  parameter integer DPD_POLY_ORDER = 5,
  parameter integer ENABLE_DPD_POLY = 1,
  parameter integer ENABLE_DPD_LUT = 1,
  parameter integer ENABLE_DPD_MEMORY = 1,
  parameter integer ALGORITHM = 2,
  parameter integer DUC_MODE = 0,
  parameter integer INTERP_MODE = 0,
  parameter integer INTERP_IMPL = 0,
  parameter integer CLK_FREQ_HZ = 100000000,
  parameter integer BB_SAMPLE_RATE_HZ = 3125000,
  parameter integer SIGNAL_BW_HZ = 2539062,
  parameter integer C_S_AXI_ADDR_WIDTH = 9,
  parameter integer C_S_AXI_DATA_WIDTH = 32,
  parameter integer C_S_AXIS_TDATA_WIDTH = 32,
  parameter integer C_S_AXIS_TUSER_WIDTH = 1,
  parameter integer C_S_AXIS_OBS_TDATA_WIDTH = 32,
  parameter integer C_S_AXIS_OBS_TUSER_WIDTH = 1
) (
  input wire aclk,
  input wire aresetn,

  input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
  input wire s_axi_awvalid,
  output wire s_axi_awready,
  input wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
  input wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
  input wire s_axi_wvalid,
  output wire s_axi_wready,
  output reg [1:0] s_axi_bresp,
  output reg s_axi_bvalid,
  input wire s_axi_bready,

  input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
  input wire s_axi_arvalid,
  output reg s_axi_arready,
  output reg [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
  output reg [1:0] s_axi_rresp,
  output reg s_axi_rvalid,
  input wire s_axi_rready,

  input wire [C_S_AXIS_TDATA_WIDTH-1:0] s_axis_tdata,
  input wire s_axis_tlast,
  input wire [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
  input wire s_axis_tvalid,
  output wire s_axis_tready,

  input wire [C_S_AXIS_OBS_TDATA_WIDTH-1:0] s_axis_obs_tdata,
  input wire s_axis_obs_tlast,
  input wire [C_S_AXIS_OBS_TUSER_WIDTH-1:0] s_axis_obs_tuser,
  input wire s_axis_obs_tvalid,
  output wire s_axis_obs_tready,
  output wire obs_irq,

  output wire dsm_valid,
  output wire i_bit,
  output wire q_bit,
  output wire signed [DSM_OUT_W-1:0] i_yout,
  output wire signed [DSM_OUT_W-1:0] q_yout,
  output wire rf_valid,
  output wire rf_bit,
  output wire signed [RF_W-1:0] rf_signed,
  output wire [PHASE_W-1:0] phase_acc_dbg
);

  localparam [31:0] CORE_VERSION = 32'h0001_0005;
  localparam [6:0] ADDR_CTRL       = 7'h00;
  localparam [5:0] ADDR_STATUS     = 6'h01;
  localparam [5:0] ADDR_PHASE_INC  = 6'h02;
  localparam [5:0] ADDR_ALGORITHM  = 6'h03;
  localparam [5:0] ADDR_DUC_MODE   = 6'h04;
  localparam [5:0] ADDR_VERSION    = 6'h05;
  localparam [5:0] ADDR_IN_COUNT   = 6'h06;
  localparam [5:0] ADDR_OUT_COUNT  = 6'h07;
  localparam [5:0] ADDR_RESET_CNT  = 6'h08;
  localparam [5:0] ADDR_ERROR      = 6'h09;
  localparam [5:0] ADDR_FRONT_COUNT = 6'h0a;
  localparam [5:0] ADDR_STALL_COUNT = 6'h0b;
  localparam [5:0] ADDR_INTERP_MODE = 6'h0c;
  localparam [5:0] ADDR_FRAME_COUNT = 6'h0d;
  localparam [5:0] ADDR_LAST_TUSER  = 6'h0e;
  localparam [5:0] ADDR_USER_ERR_COUNT = 6'h0f;
  localparam [5:0] ADDR_DPD_CTRL    = 6'h10;
  localparam [5:0] ADDR_DPD_C1      = 6'h11;
  localparam [5:0] ADDR_DPD_C3      = 6'h12;
  localparam [5:0] ADDR_DPD_C5      = 6'h13;
  localparam [5:0] ADDR_DPD_COUNT   = 6'h14;
  localparam [5:0] ADDR_DPD_SAT_COUNT = 6'h15;
  localparam [5:0] ADDR_DPD_LUT_ADDR = 6'h16;
  localparam [5:0] ADDR_DPD_LUT_DATA = 6'h17;
  localparam [5:0] ADDR_DPD_LUT_COMMIT = 6'h18;
  localparam [5:0] ADDR_MON_IN_POWER = 6'h19;
  localparam [5:0] ADDR_MON_OUT_POWER = 6'h1a;
  localparam [5:0] ADDR_MON_CLIP_COUNT = 6'h1b;
  localparam [5:0] ADDR_MON_PEAK = 6'h1c;
  localparam [5:0] ADDR_MON_AVG_MAG = 6'h1d;
  localparam [5:0] ADDR_MON_EVM_PROXY = 6'h1e;
  localparam [5:0] ADDR_MON_ACPR_PROXY = 6'h1f;
  localparam [5:0] ADDR_MON_SPEC_BIN0 = 6'h20;
  localparam [5:0] ADDR_MON_SPEC_BIN1 = 6'h21;
  localparam [5:0] ADDR_MON_SPEC_BIN2 = 6'h22;
  localparam [5:0] ADDR_MON_SPEC_ADJ = 6'h23;
  localparam [5:0] ADDR_MP_SELECT = 6'h24;
  localparam [5:0] ADDR_MP_DATA = 6'h25;
  localparam [5:0] ADDR_MP_COMMIT = 6'h26;
  localparam [5:0] ADDR_OBS_CTRL = 6'h27;
  localparam [5:0] ADDR_OBS_GAIN = 6'h28;
  localparam [5:0] ADDR_OBS_WINDOW = 6'h29;
  localparam [5:0] ADDR_OBS_STATUS = 6'h2a;
  localparam [5:0] ADDR_OBS_PAIR_COUNT = 6'h2b;
  localparam [5:0] ADDR_OBS_DROP_COUNT = 6'h2c;
  localparam [5:0] ADDR_OBS_ERROR_LO = 6'h2d;
  localparam [5:0] ADDR_OBS_ERROR_HI = 6'h2e;
  localparam [6:0] ADDR_COND_CTRL = 7'h2f;
  localparam [5:0] ADDR_COND_QAM = 6'h30;
  localparam [5:0] ADDR_COND_BW = 6'h31;
  localparam [5:0] ADDR_COND_BACKOFF = 6'h32;
  localparam [5:0] ADDR_COND_ENV = 6'h33;
  localparam [5:0] ADDR_COND_MONITOR = 6'h34;
  localparam [5:0] ADDR_SEED_STATUS = 6'h35;
  localparam [5:0] ADDR_OBS_ENV = 6'h36;
  localparam [5:0] ADDR_OBS_REF_MAG = 6'h37;
  localparam [5:0] ADDR_OBS_MAG = 6'h38;
  localparam [5:0] ADDR_OBS_PEAK = 6'h39;
  localparam [5:0] ADDR_OBS_CLIP_SAT = 6'h3a;
  localparam [5:0] ADDR_OBS_SLEW = 6'h3b;
  localparam [5:0] ADDR_OBS_SPEC_BIN0 = 6'h3c;
  localparam [5:0] ADDR_OBS_SPEC_BIN1 = 6'h3d;
  localparam [5:0] ADDR_OBS_SPEC_BIN2 = 6'h3e;
  localparam [6:0] ADDR_OBS_SPEC_ADJ = 7'h3f;
  // Extended bank: preserves the legacy 0x00-0xfc byte address map.
  localparam [6:0] ADDR_DPD_C7 = 7'h40;
  localparam [6:0] ADDR_DSM_CTRL = 7'h41;
  localparam [6:0] ADDR_CAPABILITY = 7'h42;
  localparam [6:0] ADDR_EFFECTIVE_STATUS = 7'h43;
  localparam [6:0] ADDR_MP_COMMIT_STATUS = 7'h44;
  localparam [6:0] ADDR_OBS_SNAPSHOT = 7'h45;
  localparam [6:0] ADDR_OBS_SNAPSHOT_ERROR_LO = 7'h46;
  localparam [6:0] ADDR_OBS_SNAPSHOT_ERROR_HI = 7'h47;
  localparam [W-1:0] MON_CLIP_LEVEL = {1'b0, {(W-4){1'b1}}, 3'b000};

  reg [31:0] ctrl_reg;
  // Runtime DSM attenuation is intentionally limited to a signed right shift;
  // structural DSM/DUC/interpolator choices remain compile-time SKU controls.
  reg [3:0] dsm_input_shift_reg;
  reg [PHASE_W-1:0] phase_inc_reg;
  reg soft_reset_pulse;
  reg [31:0] input_sample_count;
  reg [31:0] frontend_sample_count;
  reg [31:0] output_sample_count;
  reg [31:0] input_stall_count;
  reg [31:0] software_reset_count;
  reg [31:0] error_status_reg;
  reg [31:0] input_frame_count;
  reg [31:0] user_error_count;
  reg [C_S_AXIS_TUSER_WIDTH-1:0] last_tuser_reg;
  reg [31:0] dpd_ctrl_reg;
  reg signed [15:0] dpd_c1_re_reg;
  reg signed [15:0] dpd_c1_im_reg;
  reg signed [15:0] dpd_c3_re_reg;
  reg signed [15:0] dpd_c3_im_reg;
  reg signed [15:0] dpd_c5_re_reg;
  reg signed [15:0] dpd_c5_im_reg;
  reg signed [15:0] dpd_c7_re_reg;
  reg signed [15:0] dpd_c7_im_reg;
  reg [DPD_LUT_AW-1:0] dpd_lut_addr_reg;
  reg dpd_lut_we_pulse;
  reg dpd_lut_commit_pulse;
  reg signed [15:0] dpd_lut_wgain_re_reg;
  reg signed [15:0] dpd_lut_wgain_im_reg;
  reg [2:0] mp_coeff_tap_reg;
  reg [1:0] mp_coeff_order_reg;
  reg [2:0] mp_active_taps_reg;
  reg signed [15:0] mp_coeff_re_reg;
  reg signed [15:0] mp_coeff_im_reg;
  reg mp_coeff_we_pulse;
  reg mp_commit_pulse;
  reg dpd_safety_clear_pulse;
  reg obs_enable_reg;
  reg obs_start_pulse;
  reg obs_clear_pulse;
  reg [4:0] obs_delay_reg;
  reg signed [15:0] obs_gain_re_reg;
  reg signed [15:0] obs_gain_im_reg;
  reg [31:0] obs_window_reg;
  reg obs_irq_enable_reg;
  reg condition_valid_reg;
  reg [7:0] condition_version_reg;
  reg [15:0] condition_qam_reg;
  reg [31:0] condition_bw_khz_reg;
  reg [31:0] condition_backoff_ppm_reg;
  reg signed [15:0] condition_power_reg;
  reg signed [15:0] condition_temperature_reg;
  reg [31:0] condition_monitor_reg;
  reg aw_hold_valid;
  reg [C_S_AXI_ADDR_WIDTH-1:0] aw_hold_addr;
  reg w_hold_valid;
  reg [C_S_AXI_DATA_WIDTH-1:0] w_hold_data;
  reg [(C_S_AXI_DATA_WIDTH/8)-1:0] w_hold_strb;
  reg mp_commit_pending;
  reg mp_commit_inflight;
  reg mp_commit_ack;
  reg mp_commit_failed;
  reg mp_commit_target_bank;
  reg [7:0] mp_commit_epoch;
  reg [63:0] obs_error_snapshot;
  reg obs_snapshot_valid;
  reg [31:0] mon_input_power_acc;
  reg [31:0] mon_output_power_acc;
  reg [31:0] mon_input_clip_count;
  reg [W-1:0] mon_input_peak;
  reg [RF_W-1:0] mon_output_peak;
  reg [W-1:0] mon_input_avg_mag;
  reg [RF_W-1:0] mon_output_avg_mag;
  reg [31:0] mon_evm_proxy_acc;
  reg [31:0] mon_acpr_proxy_acc;
  reg signed [RF_W-1:0] mon_rf_prev;
  reg mon_rf_prev_valid;
  reg [1:0] mon_spec_phase;
  reg signed [31:0] mon_spec_bin0_acc;
  reg signed [31:0] mon_spec_bin1_i_acc;
  reg signed [31:0] mon_spec_bin1_q_acc;
  reg signed [31:0] mon_spec_bin2_acc;
  wire dpd_safety_fault;
  wire dpd_mp_commit_rejected;
  wire dpd_lut_commit_rejected;
  wire obs_done;

  wire core_enable = ctrl_reg[0];
  wire soft_reset = soft_reset_pulse;
  wire core_rst_n = aresetn & ~soft_reset;
  wire [8:0] s_axi_awaddr_ext = {{(9-C_S_AXI_ADDR_WIDTH){1'b0}}, aw_hold_addr};
  wire [8:0] s_axi_araddr_ext = {{(9-C_S_AXI_ADDR_WIDTH){1'b0}}, s_axi_araddr};
  wire [6:0] axi_aw_word_addr = s_axi_awaddr_ext[8:2];
  wire [6:0] axi_ar_word_addr = s_axi_araddr_ext[8:2];
  wire axis_fire = s_axis_tvalid & s_axis_tready;
  wire frontend_fire;
  wire axi_write_fire = !s_axi_bvalid && aw_hold_valid && w_hold_valid;
  wire clear_status_req = axi_write_fire &
                          (axi_aw_word_addr == ADDR_CTRL) &
                          w_hold_strb[0] & w_hold_data[2];
  // A compliant AXI-Stream source may retain TVALID while a software reset
  // applies backpressure. Flag only an explicitly disabled IP, not the
  // transient CTRL.soft_reset window.
  wire stream_while_disabled = s_axis_tvalid & !core_enable;
  wire stream_stall = s_axis_tvalid & !s_axis_tready & core_enable & core_rst_n;
  assign obs_irq = obs_irq_enable_reg & obs_done;

  wire [C_S_AXIS_TDATA_WIDTH-1:0] axis_buf_tdata;
  wire axis_buf_tlast;
  wire [C_S_AXIS_TUSER_WIDTH-1:0] axis_buf_tuser;
  wire axis_buf_valid;
  wire axis_buf_ready;
  wire axis_buf_full;
  wire axis_user_error = |s_axis_tuser;
  wire signed [W-1:0] axis_i = axis_buf_tdata[W-1:0];
  wire signed [W-1:0] axis_q = axis_buf_tdata[(2*W)-1:W];
  wire [W-1:0] axis_i_abs = abs_w(axis_i);
  wire [W-1:0] axis_q_abs = abs_w(axis_q);
  wire [W:0] axis_mag_sum = {1'b0, axis_i_abs} + {1'b0, axis_q_abs};
  wire [W-1:0] axis_mag_sat = axis_mag_sum[W] ? {W{1'b1}} : axis_mag_sum[W-1:0];
  wire axis_clip = (axis_i_abs >= MON_CLIP_LEVEL) | (axis_q_abs >= MON_CLIP_LEVEL);
  wire signed [W:0] mon_input_avg_delta =
      $signed({1'b0, axis_mag_sat}) - $signed({1'b0, mon_input_avg_mag});
  wire signed [W-1:0] dpd_i;
  wire signed [W-1:0] dpd_q;
  wire signed [W-1:0] dsm_i_cfg = dpd_i >>> dsm_input_shift_reg;
  wire signed [W-1:0] dsm_q_cfg = dpd_q >>> dsm_input_shift_reg;
  wire dpd_valid;
  wire dpd_ready;
  wire [W-1:0] dpd_i_abs = abs_w(dpd_i);
  wire [W-1:0] dpd_q_abs = abs_w(dpd_q);
  wire [W:0] dpd_mag_sum = {1'b0, dpd_i_abs} + {1'b0, dpd_q_abs};
  wire [W-1:0] dpd_mag_sat = dpd_mag_sum[W] ? {W{1'b1}} : dpd_mag_sum[W-1:0];
  wire signed [W:0] dpd_i_delta = {dpd_i[W-1], dpd_i} - {axis_i[W-1], axis_i};
  wire signed [W:0] dpd_q_delta = {dpd_q[W-1], dpd_q} - {axis_q[W-1], axis_q};
  wire [W:0] dpd_i_delta_abs = abs_wp1(dpd_i_delta);
  wire [W:0] dpd_q_delta_abs = abs_wp1(dpd_q_delta);
  wire [W+1:0] evm_proxy_sum = {1'b0, dpd_i_delta_abs} + {1'b0, dpd_q_delta_abs};
  wire [31:0] dpd_sample_count;
  wire [31:0] dpd_saturation_count;
  wire [1:0] dpd_effective_mode;
  wire dpd_busy;
  wire signed [15:0] dpd_lut_rgain_re;
  wire signed [15:0] dpd_lut_rgain_im;
  wire dpd_lut_active_bank;
  wire signed [15:0] mp_coeff_rdata_re;
  wire signed [15:0] mp_coeff_rdata_im;
  wire mp_active_bank;
  wire obs_active;
  wire obs_last_seen;
  wire [31:0] obs_paired_count;
  wire [31:0] obs_dropped_count;
  wire [63:0] obs_error_acc;
  wire signed [15:0] obs_latched_temperature;
  wire [31:0] obs_ref_mag_acc;
  wire [31:0] obs_mag_acc;
  wire [31:0] obs_peak;
  wire [15:0] obs_clip_count;
  wire [15:0] obs_saturation_count;
  wire [31:0] obs_slew_acc;
  wire [31:0] obs_spec_bin0;
  wire [31:0] obs_spec_bin1;
  wire [31:0] obs_spec_bin2;
  wire [31:0] obs_spec_adj;
  wire [4:0] obs_overflow_flags;
  wire [2:0] seed_package;
  wire condition_known;
  wire seed_fallback_required;
  wire seed_local_search_required;
  wire [RF_W-1:0] rf_abs = abs_rf(rf_signed);
  wire signed [RF_W:0] rf_delta = {rf_signed[RF_W-1], rf_signed} -
                                  {mon_rf_prev[RF_W-1], mon_rf_prev};
  wire [RF_W:0] rf_delta_abs = abs_rfp1(rf_delta);
  wire signed [RF_W:0] mon_output_avg_delta =
      $signed({1'b0, rf_abs}) - $signed({1'b0, mon_output_avg_mag});
  wire signed [31:0] rf_spec_ext = {{(32-RF_W){rf_signed[RF_W-1]}}, rf_signed};
  wire [31:0] mon_spec_bin0_mag = abs_s32(mon_spec_bin0_acc);
  wire [31:0] mon_spec_bin1_i_mag = abs_s32(mon_spec_bin1_i_acc);
  wire [31:0] mon_spec_bin1_q_mag = abs_s32(mon_spec_bin1_q_acc);
  wire [31:0] mon_spec_bin2_mag = abs_s32(mon_spec_bin2_acc);
  wire [32:0] mon_spec_bin1_sum = {1'b0, mon_spec_bin1_i_mag} + {1'b0, mon_spec_bin1_q_mag};
  wire [32:0] mon_spec_adj_sum = {1'b0, mon_spec_bin0_mag} + {1'b0, mon_spec_bin2_mag};
  wire [31:0] mon_spec_bin1_mag =
      mon_spec_bin1_sum[32] ? 32'hffff_ffff : mon_spec_bin1_sum[31:0];
  wire [31:0] mon_spec_adj_mag =
      mon_spec_adj_sum[32] ? 32'hffff_ffff : mon_spec_adj_sum[31:0];

  wire dsm_input_ready;
  wire [2:0] mp_effective_taps = (mp_active_taps_reg < 3'd1) ? 3'd1 :
                                  ((mp_active_taps_reg > DPD_MP_MAX_TAPS[2:0]) ?
                                   DPD_MP_MAX_TAPS[2:0] : mp_active_taps_reg);
  wire dpd_mode_fallback = (dpd_effective_mode != dpd_ctrl_reg[1:0]);
  // A source may legally keep TVALID asserted while TREADY is low.  It has not
  // transferred that sample, so it must not prevent a pending bank change.
  wire commit_safe_boundary = !dpd_busy && !axis_buf_valid && !frontend_fire;
  wire [31:0] capability_word = {
      11'd0,
      1'b1,                    // observation asynchronous companion IP exists
      1'b1,                    // safe window-boundary MP commit supported
      1'b1,                    // runtime DSM input shift supported
      (DUC_MODE == 1),         // digital NCO DUC compiled into this SKU
      INTERP_MODE[3:0],
      ALGORITHM[3:0],
      DPD_POLY_ORDER[2:0],
      DPD_MP_MAX_TAPS[2:0],
      ENABLE_DPD_MEMORY[0],
      ENABLE_DPD_LUT[0],
      ENABLE_DPD_POLY[0]
  };

  assign s_axi_awready = !aw_hold_valid && !s_axi_bvalid;
  assign s_axi_wready = !w_hold_valid && !s_axi_bvalid;

  function [W-1:0] abs_w;
    input signed [W-1:0] value;
    begin
      if (value == {1'b1, {(W-1){1'b0}}}) begin
        abs_w = {1'b0, {(W-1){1'b1}}};
      end else if (value[W-1]) begin
        abs_w = (~value) + {{(W-1){1'b0}}, 1'b1};
      end else begin
        abs_w = value;
      end
    end
  endfunction

  function [W:0] abs_wp1;
    input signed [W:0] value;
    begin
      if (value[W]) begin
        abs_wp1 = (~value) + {{W{1'b0}}, 1'b1};
      end else begin
        abs_wp1 = value;
      end
    end
  endfunction

  function [RF_W-1:0] abs_rf;
    input signed [RF_W-1:0] value;
    begin
      if (value == {1'b1, {(RF_W-1){1'b0}}}) begin
        abs_rf = {1'b0, {(RF_W-1){1'b1}}};
      end else if (value[RF_W-1]) begin
        abs_rf = (~value) + {{(RF_W-1){1'b0}}, 1'b1};
      end else begin
        abs_rf = value;
      end
    end
  endfunction

  function [RF_W:0] abs_rfp1;
    input signed [RF_W:0] value;
    begin
      if (value[RF_W]) begin
        abs_rfp1 = (~value) + {{RF_W{1'b0}}, 1'b1};
      end else begin
        abs_rfp1 = value;
      end
    end
  endfunction

  function [31:0] abs_s32;
    input signed [31:0] value;
    begin
      if (value == 32'sh8000_0000) begin
        abs_s32 = 32'h7fff_ffff;
      end else if (value[31]) begin
        abs_s32 = (~value) + 32'd1;
      end else begin
        abs_s32 = value[31:0];
      end
    end
  endfunction

  axis_skid_buffer #(
    .DATA_W(C_S_AXIS_TDATA_WIDTH),
    .USER_W(C_S_AXIS_TUSER_WIDTH)
  ) u_axis_skid (
    .clk(aclk),
    .rst_n(aresetn),
    .clear(!core_rst_n),
    .s_data(s_axis_tdata),
    .s_last(s_axis_tlast),
    .s_user(s_axis_tuser),
    .s_valid(s_axis_tvalid & core_enable & core_rst_n &
             !mp_commit_pending & !mp_commit_inflight),
    .s_ready(axis_buf_ready),
    .m_data(axis_buf_tdata),
    .m_last(axis_buf_tlast),
    .m_user(axis_buf_tuser),
    .m_valid(axis_buf_valid),
    .m_ready(dpd_ready & core_enable & core_rst_n),
    .full(axis_buf_full)
  );

  // A requested memory-DPD commit first drains the accepted stream and then
  // holds the upstream source until the coefficient-bank swap is acknowledged.
  assign s_axis_tready = core_enable & core_rst_n & axis_buf_ready &
                         !mp_commit_pending & !mp_commit_inflight;
  assign frontend_fire = dpd_valid & dsm_input_ready & core_enable & core_rst_n;

  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      s_axi_bresp <= 2'b00;
      s_axi_bvalid <= 1'b0;
      ctrl_reg <= 32'h0000_0000;
      dsm_input_shift_reg <= 4'd0;
      phase_inc_reg <= {{(PHASE_W-24){1'b0}}, 24'h400000};
      soft_reset_pulse <= 1'b0;
      input_sample_count <= 32'd0;
      frontend_sample_count <= 32'd0;
      output_sample_count <= 32'd0;
      input_stall_count <= 32'd0;
      software_reset_count <= 32'd0;
      error_status_reg <= 32'd0;
      input_frame_count <= 32'd0;
      user_error_count <= 32'd0;
      last_tuser_reg <= {C_S_AXIS_TUSER_WIDTH{1'b0}};
      dpd_ctrl_reg <= 32'h0000_0000;
      dpd_c1_re_reg <= 16'sd16384;
      dpd_c1_im_reg <= 16'sd0;
      dpd_c3_re_reg <= 16'sd0;
      dpd_c3_im_reg <= 16'sd0;
      dpd_c5_re_reg <= 16'sd0;
      dpd_c5_im_reg <= 16'sd0;
      dpd_c7_re_reg <= 16'sd0;
      dpd_c7_im_reg <= 16'sd0;
      dpd_lut_addr_reg <= {DPD_LUT_AW{1'b0}};
      dpd_lut_we_pulse <= 1'b0;
      dpd_lut_commit_pulse <= 1'b0;
      dpd_lut_wgain_re_reg <= 16'sd16384;
      dpd_lut_wgain_im_reg <= 16'sd0;
      mp_coeff_tap_reg <= 3'd0;
      mp_coeff_order_reg <= 2'd0;
      mp_active_taps_reg <= 3'd2;
      mp_coeff_re_reg <= 16'sd0;
      mp_coeff_im_reg <= 16'sd0;
      mp_coeff_we_pulse <= 1'b0;
      mp_commit_pulse <= 1'b0;
      dpd_safety_clear_pulse <= 1'b0;
      obs_enable_reg <= 1'b0;
      obs_start_pulse <= 1'b0;
      obs_clear_pulse <= 1'b0;
      obs_delay_reg <= 5'd0;
      obs_gain_re_reg <= 16'sd16384;
      obs_gain_im_reg <= 16'sd0;
      obs_window_reg <= 32'd0;
      obs_irq_enable_reg <= 1'b0;
      condition_valid_reg <= 1'b0;
      condition_version_reg <= 8'd1;
      condition_qam_reg <= 16'd16;
      condition_bw_khz_reg <= 32'd20000;
      condition_backoff_ppm_reg <= 32'd580000;
      condition_power_reg <= 16'sd0;
      condition_temperature_reg <= 16'sd6400;
      condition_monitor_reg <= 32'd0;
      aw_hold_valid <= 1'b0;
      aw_hold_addr <= {C_S_AXI_ADDR_WIDTH{1'b0}};
      w_hold_valid <= 1'b0;
      w_hold_data <= {C_S_AXI_DATA_WIDTH{1'b0}};
      w_hold_strb <= {(C_S_AXI_DATA_WIDTH/8){1'b0}};
      mp_commit_pending <= 1'b0;
      mp_commit_inflight <= 1'b0;
      mp_commit_ack <= 1'b0;
      mp_commit_failed <= 1'b0;
      mp_commit_target_bank <= 1'b0;
      mp_commit_epoch <= 8'd0;
      obs_error_snapshot <= 64'd0;
      obs_snapshot_valid <= 1'b0;
      mon_input_power_acc <= 32'd0;
      mon_output_power_acc <= 32'd0;
      mon_input_clip_count <= 32'd0;
      mon_input_peak <= {W{1'b0}};
      mon_output_peak <= {RF_W{1'b0}};
      mon_input_avg_mag <= {W{1'b0}};
      mon_output_avg_mag <= {RF_W{1'b0}};
      mon_evm_proxy_acc <= 32'd0;
      mon_acpr_proxy_acc <= 32'd0;
      mon_rf_prev <= {RF_W{1'b0}};
      mon_rf_prev_valid <= 1'b0;
      mon_spec_phase <= 2'd0;
      mon_spec_bin0_acc <= 32'sd0;
      mon_spec_bin1_i_acc <= 32'sd0;
      mon_spec_bin1_q_acc <= 32'sd0;
      mon_spec_bin2_acc <= 32'sd0;
    end else begin
      soft_reset_pulse <= 1'b0;
      dpd_lut_we_pulse <= 1'b0;
      dpd_lut_commit_pulse <= 1'b0;
      mp_coeff_we_pulse <= 1'b0;
      mp_commit_pulse <= 1'b0;
      dpd_safety_clear_pulse <= 1'b0;
      obs_start_pulse <= 1'b0;
      obs_clear_pulse <= 1'b0;

      // AXI4-Lite AW and W are independent channels.  Capture each one once,
      // then execute exactly one write when both held channels are present.
      if (s_axi_awvalid && s_axi_awready) begin
        aw_hold_valid <= 1'b1;
        aw_hold_addr <= s_axi_awaddr;
      end
      if (s_axi_wvalid && s_axi_wready) begin
        w_hold_valid <= 1'b1;
        w_hold_data <= s_axi_wdata;
        w_hold_strb <= s_axi_wstrb;
      end

      if (mp_commit_pending && !mp_commit_inflight && commit_safe_boundary) begin
        mp_commit_pulse <= 1'b1;
        mp_commit_pending <= 1'b0;
        mp_commit_inflight <= 1'b1;
        mp_commit_target_bank <= ~mp_active_bank;
      end
      if (mp_commit_inflight) begin
        if (mp_active_bank == mp_commit_target_bank) begin
          mp_commit_inflight <= 1'b0;
          mp_commit_ack <= 1'b1;
          mp_commit_epoch <= mp_commit_epoch + 8'd1;
        end else if (dpd_mp_commit_rejected) begin
          mp_commit_inflight <= 1'b0;
          mp_commit_failed <= 1'b1;
        end
      end

      if (axis_fire) begin
        input_sample_count <= input_sample_count + 32'd1;
        mon_input_power_acc <= mon_input_power_acc + {{(32-W){1'b0}}, axis_mag_sat};
        if (axis_mag_sat > mon_input_peak) begin
          mon_input_peak <= axis_mag_sat;
        end
        mon_input_avg_mag <= mon_input_avg_mag + (mon_input_avg_delta >>> 4);
        if (axis_clip) begin
          mon_input_clip_count <= mon_input_clip_count + 32'd1;
        end
        last_tuser_reg <= s_axis_tuser;
        if (s_axis_tlast) begin
          input_frame_count <= input_frame_count + 32'd1;
        end
        if (axis_user_error) begin
          error_status_reg[1] <= 1'b1;
          user_error_count <= user_error_count + 32'd1;
        end
      end

      if (frontend_fire) begin
        frontend_sample_count <= frontend_sample_count + 32'd1;
        mon_evm_proxy_acc <= mon_evm_proxy_acc + {{(30-W){1'b0}}, evm_proxy_sum};
      end

      if (rf_valid) begin
        output_sample_count <= output_sample_count + 32'd1;
        mon_output_power_acc <= mon_output_power_acc + {{(32-RF_W){1'b0}}, rf_abs};
        if (rf_abs > mon_output_peak) begin
          mon_output_peak <= rf_abs;
        end
        mon_output_avg_mag <= mon_output_avg_mag + (mon_output_avg_delta >>> 4);
        if (mon_rf_prev_valid) begin
          mon_acpr_proxy_acc <= mon_acpr_proxy_acc + {{(31-RF_W){1'b0}}, rf_delta_abs};
        end
        mon_spec_bin0_acc <= mon_spec_bin0_acc + rf_spec_ext;
        if (mon_spec_phase[0]) begin
          mon_spec_bin2_acc <= mon_spec_bin2_acc - rf_spec_ext;
        end else begin
          mon_spec_bin2_acc <= mon_spec_bin2_acc + rf_spec_ext;
        end
        case (mon_spec_phase)
          2'd0: mon_spec_bin1_i_acc <= mon_spec_bin1_i_acc + rf_spec_ext;
          2'd1: mon_spec_bin1_q_acc <= mon_spec_bin1_q_acc - rf_spec_ext;
          2'd2: mon_spec_bin1_i_acc <= mon_spec_bin1_i_acc - rf_spec_ext;
          default: mon_spec_bin1_q_acc <= mon_spec_bin1_q_acc + rf_spec_ext;
        endcase
        mon_spec_phase <= mon_spec_phase + 2'd1;
        mon_rf_prev <= rf_signed;
        mon_rf_prev_valid <= 1'b1;
      end

      if (stream_stall) begin
        input_stall_count <= input_stall_count + 32'd1;
      end

      if (stream_while_disabled) begin
        error_status_reg[0] <= 1'b1;
      end
      if (dpd_safety_fault) error_status_reg[2] <= 1'b1;
      if (dpd_mp_commit_rejected) error_status_reg[3] <= 1'b1;
      if (dpd_lut_commit_rejected) error_status_reg[4] <= 1'b1;

      if (clear_status_req) begin
        input_sample_count <= 32'd0;
        frontend_sample_count <= 32'd0;
        output_sample_count <= 32'd0;
        input_stall_count <= 32'd0;
        error_status_reg <= 32'd0;
        input_frame_count <= 32'd0;
        user_error_count <= 32'd0;
        last_tuser_reg <= {C_S_AXIS_TUSER_WIDTH{1'b0}};
        mon_input_power_acc <= 32'd0;
        mon_output_power_acc <= 32'd0;
        mon_input_clip_count <= 32'd0;
        mon_input_peak <= {W{1'b0}};
        mon_output_peak <= {RF_W{1'b0}};
        mon_input_avg_mag <= {W{1'b0}};
        mon_output_avg_mag <= {RF_W{1'b0}};
        mon_evm_proxy_acc <= 32'd0;
        mon_acpr_proxy_acc <= 32'd0;
        mon_rf_prev <= {RF_W{1'b0}};
        mon_rf_prev_valid <= 1'b0;
        mon_spec_phase <= 2'd0;
        mon_spec_bin0_acc <= 32'sd0;
        mon_spec_bin1_i_acc <= 32'sd0;
        mon_spec_bin1_q_acc <= 32'sd0;
        mon_spec_bin2_acc <= 32'sd0;
      end

      if (axi_write_fire) begin
        aw_hold_valid <= 1'b0;
        w_hold_valid <= 1'b0;
        s_axi_bvalid <= 1'b1;
        s_axi_bresp <= 2'b00;

`define s_axi_wdata w_hold_data
`define s_axi_wstrb w_hold_strb
        case (axi_aw_word_addr)
          ADDR_CTRL: begin
            if (s_axi_wstrb[0]) begin
              ctrl_reg[0] <= s_axi_wdata[0];
              if (s_axi_wdata[1]) begin
                soft_reset_pulse <= 1'b1;
                software_reset_count <= software_reset_count + 32'd1;
              end
            end
            if (s_axi_wstrb[1]) ctrl_reg[15:8] <= s_axi_wdata[15:8];
            if (s_axi_wstrb[2]) ctrl_reg[23:16] <= s_axi_wdata[23:16];
            if (s_axi_wstrb[3]) ctrl_reg[31:24] <= s_axi_wdata[31:24];
          end
          ADDR_PHASE_INC: begin
            if (PHASE_W <= 32) begin
              phase_inc_reg <= s_axi_wdata[PHASE_W-1:0];
            end
          end
          ADDR_DSM_CTRL: begin
            if (s_axi_wstrb[0]) dsm_input_shift_reg <= s_axi_wdata[3:0];
          end
          ADDR_ERROR: begin
            error_status_reg <= error_status_reg & ~s_axi_wdata;
          end
          ADDR_DPD_CTRL: begin
            if (s_axi_wstrb[0]) dpd_ctrl_reg[7:0] <= s_axi_wdata[7:0];
            if (s_axi_wstrb[1]) dpd_ctrl_reg[15:8] <= s_axi_wdata[15:8];
            if (s_axi_wstrb[2]) dpd_ctrl_reg[23:16] <= s_axi_wdata[23:16];
            if (s_axi_wstrb[3]) dpd_ctrl_reg[31:24] <= s_axi_wdata[31:24];
            if (s_axi_wstrb[1] && s_axi_wdata[9]) dpd_safety_clear_pulse <= 1'b1;
          end
          ADDR_DPD_C1: begin
            if (s_axi_wstrb[0]) dpd_c1_re_reg[7:0] <= s_axi_wdata[7:0];
            if (s_axi_wstrb[1]) dpd_c1_re_reg[15:8] <= s_axi_wdata[15:8];
            if (s_axi_wstrb[2]) dpd_c1_im_reg[7:0] <= s_axi_wdata[23:16];
            if (s_axi_wstrb[3]) dpd_c1_im_reg[15:8] <= s_axi_wdata[31:24];
          end
          ADDR_DPD_C3: begin
            if (s_axi_wstrb[0]) dpd_c3_re_reg[7:0] <= s_axi_wdata[7:0];
            if (s_axi_wstrb[1]) dpd_c3_re_reg[15:8] <= s_axi_wdata[15:8];
            if (s_axi_wstrb[2]) dpd_c3_im_reg[7:0] <= s_axi_wdata[23:16];
            if (s_axi_wstrb[3]) dpd_c3_im_reg[15:8] <= s_axi_wdata[31:24];
          end
          ADDR_DPD_C5: begin
            if (s_axi_wstrb[0]) dpd_c5_re_reg[7:0] <= s_axi_wdata[7:0];
            if (s_axi_wstrb[1]) dpd_c5_re_reg[15:8] <= s_axi_wdata[15:8];
            if (s_axi_wstrb[2]) dpd_c5_im_reg[7:0] <= s_axi_wdata[23:16];
            if (s_axi_wstrb[3]) dpd_c5_im_reg[15:8] <= s_axi_wdata[31:24];
          end
          ADDR_DPD_C7: begin
            if (s_axi_wstrb[0]) dpd_c7_re_reg[7:0] <= s_axi_wdata[7:0];
            if (s_axi_wstrb[1]) dpd_c7_re_reg[15:8] <= s_axi_wdata[15:8];
            if (s_axi_wstrb[2]) dpd_c7_im_reg[7:0] <= s_axi_wdata[23:16];
            if (s_axi_wstrb[3]) dpd_c7_im_reg[15:8] <= s_axi_wdata[31:24];
          end
          ADDR_DPD_LUT_ADDR: begin
            if (s_axi_wstrb[0]) dpd_lut_addr_reg <= s_axi_wdata[DPD_LUT_AW-1:0];
          end
          ADDR_DPD_LUT_DATA: begin
            if (s_axi_wstrb[0]) dpd_lut_wgain_re_reg[7:0] <= s_axi_wdata[7:0];
            if (s_axi_wstrb[1]) dpd_lut_wgain_re_reg[15:8] <= s_axi_wdata[15:8];
            if (s_axi_wstrb[2]) dpd_lut_wgain_im_reg[7:0] <= s_axi_wdata[23:16];
            if (s_axi_wstrb[3]) dpd_lut_wgain_im_reg[15:8] <= s_axi_wdata[31:24];
            dpd_lut_we_pulse <= 1'b1;
          end
          ADDR_DPD_LUT_COMMIT: begin
            if (s_axi_wstrb[0] && s_axi_wdata[0]) begin
              dpd_lut_commit_pulse <= 1'b1;
            end
          end
          ADDR_MP_SELECT: begin
            if (s_axi_wstrb[0]) begin
              mp_coeff_tap_reg[1:0] <= s_axi_wdata[1:0];
              mp_coeff_order_reg <= s_axi_wdata[3:2];
              mp_coeff_tap_reg[2] <= s_axi_wdata[4];
            end
            if (s_axi_wstrb[1]) mp_active_taps_reg <= s_axi_wdata[10:8];
          end
          ADDR_MP_DATA: begin
            if (s_axi_wstrb[0]) mp_coeff_re_reg[7:0] <= s_axi_wdata[7:0];
            if (s_axi_wstrb[1]) mp_coeff_re_reg[15:8] <= s_axi_wdata[15:8];
            if (s_axi_wstrb[2]) mp_coeff_im_reg[7:0] <= s_axi_wdata[23:16];
            if (s_axi_wstrb[3]) mp_coeff_im_reg[15:8] <= s_axi_wdata[31:24];
            mp_coeff_we_pulse <= 1'b1;
          end
          ADDR_MP_COMMIT: begin
            if (s_axi_wstrb[0] && s_axi_wdata[0] && !mp_commit_pending &&
                !mp_commit_inflight) begin
              mp_commit_pending <= 1'b1;
              mp_commit_ack <= 1'b0;
              mp_commit_failed <= 1'b0;
            end
          end
          ADDR_OBS_CTRL: begin
            if (s_axi_wstrb[0]) begin
              obs_enable_reg <= s_axi_wdata[0];
              if (s_axi_wdata[1]) obs_start_pulse <= 1'b1;
              if (s_axi_wdata[2]) obs_clear_pulse <= 1'b1;
            end
            if (s_axi_wstrb[1]) obs_delay_reg <= s_axi_wdata[12:8];
            if (s_axi_wstrb[2]) obs_irq_enable_reg <= s_axi_wdata[16];
          end
          ADDR_OBS_GAIN: begin
            if (s_axi_wstrb[0]) obs_gain_re_reg[7:0] <= s_axi_wdata[7:0];
            if (s_axi_wstrb[1]) obs_gain_re_reg[15:8] <= s_axi_wdata[15:8];
            if (s_axi_wstrb[2]) obs_gain_im_reg[7:0] <= s_axi_wdata[23:16];
            if (s_axi_wstrb[3]) obs_gain_im_reg[15:8] <= s_axi_wdata[31:24];
          end
          ADDR_OBS_WINDOW: obs_window_reg <= s_axi_wdata;
          ADDR_MP_COMMIT_STATUS: begin
            if (s_axi_wstrb[0] && s_axi_wdata[0]) mp_commit_ack <= 1'b0;
            if (s_axi_wstrb[0] && s_axi_wdata[3]) mp_commit_failed <= 1'b0;
          end
          ADDR_OBS_SNAPSHOT: begin
            if (s_axi_wstrb[0] && s_axi_wdata[0]) begin
              obs_error_snapshot <= obs_error_acc;
              obs_snapshot_valid <= 1'b1;
            end
            if (s_axi_wstrb[0] && s_axi_wdata[1]) obs_snapshot_valid <= 1'b0;
          end
          ADDR_COND_CTRL: begin
            if (s_axi_wstrb[0]) condition_valid_reg <= s_axi_wdata[0];
            if (s_axi_wstrb[1]) condition_version_reg <= s_axi_wdata[15:8];
          end
          ADDR_COND_QAM: condition_qam_reg <= s_axi_wdata[15:0];
          ADDR_COND_BW: condition_bw_khz_reg <= s_axi_wdata;
          ADDR_COND_BACKOFF: condition_backoff_ppm_reg <= s_axi_wdata;
          ADDR_COND_ENV: begin
            condition_power_reg <= s_axi_wdata[15:0];
            condition_temperature_reg <= s_axi_wdata[31:16];
          end
          ADDR_COND_MONITOR: condition_monitor_reg <= s_axi_wdata;
          default: begin
          end
        endcase
`undef s_axi_wdata
`undef s_axi_wstrb
      end else if (s_axi_bvalid && s_axi_bready) begin
        s_axi_bvalid <= 1'b0;
      end
    end
  end

  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      s_axi_arready <= 1'b0;
      s_axi_rdata <= 32'h0000_0000;
      s_axi_rresp <= 2'b00;
      s_axi_rvalid <= 1'b0;
    end else begin
      s_axi_arready <= 1'b0;

      if (!s_axi_rvalid && s_axi_arvalid) begin
        s_axi_arready <= 1'b1;
        s_axi_rvalid <= 1'b1;
        s_axi_rresp <= 2'b00;
        case (axi_ar_word_addr)
          ADDR_CTRL:      s_axi_rdata <= ctrl_reg;
          ADDR_STATUS:    s_axi_rdata <= {25'b0, axis_buf_full, |error_status_reg, s_axis_tready, rf_valid, dsm_valid, soft_reset, core_enable};
          ADDR_PHASE_INC: s_axi_rdata <= {{(32-PHASE_W){1'b0}}, phase_inc_reg};
          ADDR_DSM_CTRL:  s_axi_rdata <= {28'd0, dsm_input_shift_reg};
          ADDR_ALGORITHM: s_axi_rdata <= ALGORITHM[31:0];
          ADDR_DUC_MODE:  s_axi_rdata <= DUC_MODE[31:0];
          ADDR_VERSION:   s_axi_rdata <= CORE_VERSION;
          ADDR_IN_COUNT:  s_axi_rdata <= input_sample_count;
          ADDR_OUT_COUNT: s_axi_rdata <= output_sample_count;
          ADDR_RESET_CNT: s_axi_rdata <= software_reset_count;
          ADDR_ERROR:     s_axi_rdata <= error_status_reg;
          ADDR_FRONT_COUNT: s_axi_rdata <= frontend_sample_count;
          ADDR_STALL_COUNT: s_axi_rdata <= input_stall_count;
          ADDR_INTERP_MODE: s_axi_rdata <= INTERP_MODE[31:0];
          ADDR_FRAME_COUNT: s_axi_rdata <= input_frame_count;
          ADDR_LAST_TUSER:  s_axi_rdata <= {{(32-C_S_AXIS_TUSER_WIDTH){1'b0}}, last_tuser_reg};
          ADDR_USER_ERR_COUNT: s_axi_rdata <= user_error_count;
          ADDR_DPD_CTRL:    s_axi_rdata <= dpd_ctrl_reg;
          ADDR_DPD_C1:      s_axi_rdata <= {dpd_c1_im_reg, dpd_c1_re_reg};
          ADDR_DPD_C3:      s_axi_rdata <= {dpd_c3_im_reg, dpd_c3_re_reg};
          ADDR_DPD_C5:      s_axi_rdata <= {dpd_c5_im_reg, dpd_c5_re_reg};
          ADDR_DPD_C7:      s_axi_rdata <= {dpd_c7_im_reg, dpd_c7_re_reg};
          ADDR_CAPABILITY:  s_axi_rdata <= capability_word;
          ADDR_EFFECTIVE_STATUS: s_axi_rdata <= {
              19'd0, mp_commit_failed, mp_commit_inflight, mp_commit_pending,
              dpd_mode_fallback, dpd_safety_fault, mp_effective_taps,
              mp_active_bank, dpd_effective_mode, dpd_ctrl_reg[1:0]};
          ADDR_DPD_COUNT:   s_axi_rdata <= dpd_sample_count;
          ADDR_DPD_SAT_COUNT: s_axi_rdata <= dpd_saturation_count;
          ADDR_DPD_LUT_ADDR: s_axi_rdata <= {{(32-DPD_LUT_AW){1'b0}}, dpd_lut_addr_reg};
          ADDR_DPD_LUT_DATA: s_axi_rdata <= {dpd_lut_rgain_im, dpd_lut_rgain_re};
          ADDR_DPD_LUT_COMMIT: s_axi_rdata <= {31'b0, dpd_lut_active_bank};
          ADDR_MON_IN_POWER: s_axi_rdata <= mon_input_power_acc;
          ADDR_MON_OUT_POWER: s_axi_rdata <= mon_output_power_acc;
          ADDR_MON_CLIP_COUNT: s_axi_rdata <= mon_input_clip_count;
          ADDR_MON_PEAK: s_axi_rdata <= {{(16-RF_W){1'b0}}, mon_output_peak[RF_W-1:0], {(16-W){1'b0}}, mon_input_peak[W-1:0]};
          ADDR_MON_AVG_MAG: s_axi_rdata <= {{(16-RF_W){1'b0}}, mon_output_avg_mag[RF_W-1:0], {(16-W){1'b0}}, mon_input_avg_mag[W-1:0]};
          ADDR_MON_EVM_PROXY: s_axi_rdata <= mon_evm_proxy_acc;
          ADDR_MON_ACPR_PROXY: s_axi_rdata <= mon_acpr_proxy_acc;
          ADDR_MON_SPEC_BIN0: s_axi_rdata <= mon_spec_bin0_mag;
          ADDR_MON_SPEC_BIN1: s_axi_rdata <= mon_spec_bin1_mag;
          ADDR_MON_SPEC_BIN2: s_axi_rdata <= mon_spec_bin2_mag;
          ADDR_MON_SPEC_ADJ:  s_axi_rdata <= mon_spec_adj_mag;
          ADDR_MP_SELECT: s_axi_rdata <= {21'd0, mp_active_taps_reg, 4'd0,
                                           mp_coeff_order_reg, mp_coeff_tap_reg};
          ADDR_MP_DATA: s_axi_rdata <= {mp_coeff_rdata_im, mp_coeff_rdata_re};
          ADDR_MP_COMMIT: s_axi_rdata <= {31'd0, mp_active_bank};
          ADDR_MP_COMMIT_STATUS: s_axi_rdata <= {16'd0, mp_commit_epoch,
                                                  4'd0, mp_commit_failed,
                                                  mp_commit_inflight,
                                                  mp_commit_pending,
                                                  mp_commit_ack};
          ADDR_OBS_CTRL: s_axi_rdata <= {15'd0, obs_irq_enable_reg, 3'd0, obs_delay_reg, 5'd0,
                                         obs_clear_pulse, obs_start_pulse,
                                         obs_enable_reg};
          ADDR_OBS_GAIN: s_axi_rdata <= {obs_gain_im_reg, obs_gain_re_reg};
          ADDR_OBS_WINDOW: s_axi_rdata <= obs_window_reg;
          ADDR_OBS_STATUS: s_axi_rdata <= {24'd0, obs_snapshot_valid,
                                           |obs_overflow_flags,
                                           (obs_done && (obs_dropped_count == 0) &&
                                            !(|obs_overflow_flags)),
                                           obs_last_seen, obs_done,
                                           obs_active, s_axis_obs_tready};
          ADDR_OBS_PAIR_COUNT: s_axi_rdata <= obs_paired_count;
          ADDR_OBS_DROP_COUNT: s_axi_rdata <= obs_dropped_count;
          ADDR_OBS_ERROR_LO: s_axi_rdata <= obs_error_acc[31:0];
          ADDR_OBS_ERROR_HI: s_axi_rdata <= obs_error_acc[63:32];
          ADDR_COND_CTRL: s_axi_rdata <= {16'd0, condition_version_reg, 7'd0,
                                          condition_valid_reg};
          ADDR_COND_QAM: s_axi_rdata <= {16'd0, condition_qam_reg};
          ADDR_COND_BW: s_axi_rdata <= condition_bw_khz_reg;
          ADDR_COND_BACKOFF: s_axi_rdata <= condition_backoff_ppm_reg;
          ADDR_COND_ENV: s_axi_rdata <= {condition_temperature_reg,
                                         condition_power_reg};
          ADDR_COND_MONITOR: s_axi_rdata <= condition_monitor_reg;
          ADDR_SEED_STATUS: s_axi_rdata <= {26'd0, seed_local_search_required,
                                            seed_fallback_required,
                                            condition_known, seed_package};
          ADDR_OBS_ENV: s_axi_rdata <= {8'd2, 8'd0, obs_latched_temperature};
          ADDR_OBS_REF_MAG: s_axi_rdata <= obs_ref_mag_acc;
          ADDR_OBS_MAG: s_axi_rdata <= obs_mag_acc;
          ADDR_OBS_PEAK: s_axi_rdata <= obs_peak;
          ADDR_OBS_CLIP_SAT: s_axi_rdata <= {obs_saturation_count,
                                             obs_clip_count};
          ADDR_OBS_SLEW: s_axi_rdata <= obs_slew_acc;
          ADDR_OBS_SPEC_BIN0: s_axi_rdata <= obs_spec_bin0;
          ADDR_OBS_SPEC_BIN1: s_axi_rdata <= obs_spec_bin1;
          ADDR_OBS_SPEC_BIN2: s_axi_rdata <= obs_spec_bin2;
          ADDR_OBS_SPEC_ADJ: s_axi_rdata <= obs_spec_adj;
          ADDR_OBS_SNAPSHOT: s_axi_rdata <= {31'd0, obs_snapshot_valid};
          ADDR_OBS_SNAPSHOT_ERROR_LO: s_axi_rdata <= obs_error_snapshot[31:0];
          ADDR_OBS_SNAPSHOT_ERROR_HI: s_axi_rdata <= obs_error_snapshot[63:32];
          default: s_axi_rdata <= 32'h0000_0000;
        endcase
      end else if (s_axi_rvalid && s_axi_rready) begin
        s_axi_rvalid <= 1'b0;
      end
    end
  end

  dpd_frontend #(
    .W(W),
    .COEFF_W(16),
    .COEFF_FRAC(14),
    .LUT_AW(DPD_LUT_AW),
    .MP_MAX_TAPS(DPD_MP_MAX_TAPS),
    .MP_POLY_ORDER(DPD_POLY_ORDER),
    .ENABLE_DPD_POLY(ENABLE_DPD_POLY),
    .ENABLE_DPD_LUT(ENABLE_DPD_LUT),
    .ENABLE_DPD_MEMORY(ENABLE_DPD_MEMORY)
  ) u_dpd_frontend (
    .clk(aclk),
    .rst_n(core_rst_n),
    .mode(dpd_ctrl_reg[1:0]),
    .c1_re(dpd_c1_re_reg),
    .c1_im(dpd_c1_im_reg),
    .c3_re(dpd_c3_re_reg),
    .c3_im(dpd_c3_im_reg),
    .c5_re(dpd_c5_re_reg),
    .c5_im(dpd_c5_im_reg),
    .c7_re(dpd_c7_re_reg),
    .c7_im(dpd_c7_im_reg),
    .mp_active_taps(mp_active_taps_reg),
    .mp_coeff_we(mp_coeff_we_pulse),
    .mp_commit(mp_commit_pulse),
    .mp_coeff_tap(mp_coeff_tap_reg),
    .mp_coeff_order(mp_coeff_order_reg),
    .mp_coeff_re(mp_coeff_re_reg),
    .mp_coeff_im(mp_coeff_im_reg),
    .mp_coeff_rdata_re(mp_coeff_rdata_re),
    .mp_coeff_rdata_im(mp_coeff_rdata_im),
    .mp_active_bank(mp_active_bank),
    .lut_we(dpd_lut_we_pulse),
    .lut_commit(dpd_lut_commit_pulse),
    .lut_waddr(dpd_lut_addr_reg),
    .lut_wgain_re(dpd_lut_wgain_re_reg),
    .lut_wgain_im(dpd_lut_wgain_im_reg),
    .lut_raddr(dpd_lut_addr_reg),
    .lut_rgain_re(dpd_lut_rgain_re),
    .lut_rgain_im(dpd_lut_rgain_im),
    .lut_active_bank(dpd_lut_active_bank),
    .safety_enable(dpd_ctrl_reg[8]),
    .safety_clear(dpd_safety_clear_pulse),
    .safety_fault(dpd_safety_fault),
    .mp_commit_rejected(dpd_mp_commit_rejected),
    .lut_commit_rejected(dpd_lut_commit_rejected),
    .i_in(axis_i),
    .q_in(axis_q),
    .in_valid(axis_buf_valid & core_enable & core_rst_n),
    .in_ready(dpd_ready),
    .i_out(dpd_i),
    .q_out(dpd_q),
    .out_valid(dpd_valid),
    .out_ready(dsm_input_ready & core_enable & core_rst_n),
    .effective_mode_out(dpd_effective_mode),
    .busy(dpd_busy),
    .sample_count(dpd_sample_count),
    .saturation_count(dpd_saturation_count)
  );

  dpd_observer #(
    .W(W),
    .GAIN_W(16),
    .GAIN_FRAC(14),
    .DELAY_AW(5)
  ) u_dpd_observer (
    .clk(aclk),
    .rst_n(core_rst_n),
    .enable(obs_enable_reg),
    .start(obs_start_pulse),
    .clear(obs_clear_pulse),
    .delay_samples(obs_delay_reg),
    .gain_re(obs_gain_re_reg),
    .gain_im(obs_gain_im_reg),
    .temperature_q8_8(condition_temperature_reg),
    .window_samples(obs_window_reg),
    .ref_i(axis_i),
    .ref_q(axis_q),
    .ref_valid(axis_buf_valid & dpd_ready & core_enable & core_rst_n),
    .obs_i(s_axis_obs_tdata[W-1:0]),
    .obs_q(s_axis_obs_tdata[(2*W)-1:W]),
    .obs_last(s_axis_obs_tlast),
    .obs_invalid(|s_axis_obs_tuser),
    .obs_valid(s_axis_obs_tvalid),
    .obs_ready(s_axis_obs_tready),
    .active(obs_active),
    .done(obs_done),
    .last_seen(obs_last_seen),
    .paired_count(obs_paired_count),
    .dropped_count(obs_dropped_count),
    .error_acc(obs_error_acc),
    .latched_temperature_q8_8(obs_latched_temperature),
    .ref_mag_acc(obs_ref_mag_acc),
    .obs_mag_acc(obs_mag_acc),
    .obs_peak(obs_peak),
    .clip_count(obs_clip_count),
    .saturation_count(obs_saturation_count),
    .slew_acc(obs_slew_acc),
    .spec_bin0(obs_spec_bin0),
    .spec_bin1(obs_spec_bin1),
    .spec_bin2(obs_spec_bin2),
    .spec_adj(obs_spec_adj),
    .overflow_flags(obs_overflow_flags)
  );

  dpd_seed_predictor u_dpd_seed_predictor (
    .condition_valid(condition_valid_reg),
    .condition_version(condition_version_reg),
    .qam_order(condition_qam_reg),
    .bandwidth_khz(condition_bw_khz_reg),
    .backoff_ppm(condition_backoff_ppm_reg),
    .power_q8_8(condition_power_reg),
    .temperature_q8_8(condition_temperature_reg),
    .monitor_state(condition_monitor_reg),
    .seed_package(seed_package),
    .condition_known(condition_known),
    .fallback_required(seed_fallback_required),
    .local_search_required(seed_local_search_required)
  );

  dsm_ip_top #(
    .W(W),
    .DSM_OUT_W(DSM_OUT_W),
    .RF_W(RF_W),
    .PHASE_W(PHASE_W),
    .LUT_AW(LUT_AW),
    .TW_W(TW_W),
    .ALGORITHM(ALGORITHM),
    .DUC_MODE(DUC_MODE),
    .INTERP_MODE(INTERP_MODE),
    .INTERP_IMPL(INTERP_IMPL),
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .BB_SAMPLE_RATE_HZ(BB_SAMPLE_RATE_HZ),
    .SIGNAL_BW_HZ(SIGNAL_BW_HZ)
  ) u_dsm_ip_top (
    .clk(aclk),
    .rst_n(core_rst_n),
    .in_valid(frontend_fire),
    .cfg_phase_inc(phase_inc_reg),
    .i_in(dsm_i_cfg),
    .q_in(dsm_q_cfg),
    .in_ready(dsm_input_ready),
    .dsm_valid(dsm_valid),
    .i_bit(i_bit),
    .q_bit(q_bit),
    .i_yout(i_yout),
    .q_yout(q_yout),
    .rf_valid(rf_valid),
    .rf_bit(rf_bit),
    .rf_signed(rf_signed),
    .phase_acc_dbg(phase_acc_dbg)
  );

endmodule

`default_nettype wire
