`timescale 1ns/1ps
`default_nettype none

module dpd_observer #(
  parameter integer W = 16,
  parameter integer GAIN_W = 16,
  parameter integer GAIN_FRAC = 14,
  parameter integer DELAY_AW = 5
) (
  input wire clk,
  input wire rst_n,
  input wire enable,
  input wire start,
  input wire clear,
  input wire [DELAY_AW-1:0] delay_samples,
  input wire signed [GAIN_W-1:0] gain_re,
  input wire signed [GAIN_W-1:0] gain_im,
  input wire signed [15:0] temperature_q8_8,
  input wire [31:0] window_samples,
  input wire signed [W-1:0] ref_i,
  input wire signed [W-1:0] ref_q,
  input wire ref_valid,
  input wire signed [W-1:0] obs_i,
  input wire signed [W-1:0] obs_q,
  input wire obs_last,
  input wire obs_invalid,
  input wire obs_valid,
  output wire obs_ready,
  output reg active,
  output reg done,
  output reg last_seen,
  output reg [31:0] paired_count,
  output reg [31:0] dropped_count,
  output reg [63:0] error_acc,
  output reg signed [15:0] latched_temperature_q8_8,
  output reg [31:0] ref_mag_acc,
  output reg [31:0] obs_mag_acc,
  output reg [31:0] obs_peak,
  output reg [15:0] clip_count,
  output reg [15:0] saturation_count,
  output reg [31:0] slew_acc,
  output wire [31:0] spec_bin0,
  output wire [31:0] spec_bin1,
  output wire [31:0] spec_bin2,
  output wire [31:0] spec_adj
);

  localparam integer DEPTH = (1 << DELAY_AW);
  localparam integer MIX_W = W + GAIN_W + 2;
  localparam signed [MIX_W-1:0] SAMPLE_MAX = (1 <<< (W-1)) - 1;
  localparam signed [MIX_W-1:0] SAMPLE_MIN = -(1 <<< (W-1));
  localparam [W-1:0] CLIP_LEVEL = 16'd31130;
  reg signed [W-1:0] ref_i_mem [0:DEPTH-1];
  reg signed [W-1:0] ref_q_mem [0:DEPTH-1];
  reg [DELAY_AW-1:0] ref_wr_ptr;
  reg [31:0] ref_count;

  wire obs_fire = obs_valid & obs_ready;
  wire use_current_ref = (delay_samples == 0) && ref_valid;
  wire [DELAY_AW-1:0] ref_rd_ptr = ref_wr_ptr - delay_samples;
  wire ref_available = use_current_ref ||
                       ((delay_samples != 0) && (ref_count >= delay_samples));
  wire signed [W-1:0] delayed_i = use_current_ref ? ref_i : ref_i_mem[ref_rd_ptr];
  wire signed [W-1:0] delayed_q = use_current_ref ? ref_q : ref_q_mem[ref_rd_ptr];
  wire signed [MIX_W-1:0] aligned_i_wide =
      ((obs_i * gain_re) - (obs_q * gain_im)) >>> GAIN_FRAC;
  wire signed [MIX_W-1:0] aligned_q_wide =
      ((obs_i * gain_im) + (obs_q * gain_re)) >>> GAIN_FRAC;
  wire signed [MIX_W:0] err_i = aligned_i_wide - delayed_i;
  wire signed [MIX_W:0] err_q = aligned_q_wide - delayed_q;
  wire [MIX_W:0] err_i_abs = err_i[MIX_W] ? (~err_i + 1'b1) : err_i;
  wire [MIX_W:0] err_q_abs = err_q[MIX_W] ? (~err_q + 1'b1) : err_q;
  wire [MIX_W+1:0] error_now = {1'b0, err_i_abs} + {1'b0, err_q_abs};
  wire aligned_i_saturated = (aligned_i_wide > SAMPLE_MAX) ||
                             (aligned_i_wide < SAMPLE_MIN);
  wire aligned_q_saturated = (aligned_q_wide > SAMPLE_MAX) ||
                             (aligned_q_wide < SAMPLE_MIN);
  wire signed [W-1:0] aligned_i = aligned_i_wide > SAMPLE_MAX ?
      {1'b0, {(W-1){1'b1}}} : aligned_i_wide < SAMPLE_MIN ?
      {1'b1, {(W-1){1'b0}}} : aligned_i_wide[W-1:0];
  wire signed [W-1:0] aligned_q = aligned_q_wide > SAMPLE_MAX ?
      {1'b0, {(W-1){1'b1}}} : aligned_q_wide < SAMPLE_MIN ?
      {1'b1, {(W-1){1'b0}}} : aligned_q_wide[W-1:0];
  wire [W-1:0] ref_i_abs = abs_sample(delayed_i);
  wire [W-1:0] ref_q_abs = abs_sample(delayed_q);
  wire [W-1:0] obs_i_abs = abs_sample(aligned_i);
  wire [W-1:0] obs_q_abs = abs_sample(aligned_q);
  wire [W:0] ref_mag_now = {1'b0, ref_i_abs} + {1'b0, ref_q_abs};
  wire [W:0] obs_mag_now = {1'b0, obs_i_abs} + {1'b0, obs_q_abs};
  wire [W:0] obs_mag_sat = obs_mag_now[W] ? {1'b0, {W{1'b1}}} : obs_mag_now;
  wire obs_clip_now = (obs_i_abs >= CLIP_LEVEL) || (obs_q_abs >= CLIP_LEVEL);

  reg signed [W-1:0] obs_i_prev;
  reg signed [W-1:0] obs_q_prev;
  reg obs_prev_valid;
  reg [1:0] spec_phase;
  reg signed [31:0] spec_bin0_i_acc;
  reg signed [31:0] spec_bin0_q_acc;
  reg signed [31:0] spec_bin1_i_acc;
  reg signed [31:0] spec_bin1_q_acc;
  reg signed [31:0] spec_bin2_i_acc;
  reg signed [31:0] spec_bin2_q_acc;
  wire signed [W:0] slew_i_delta = {aligned_i[W-1], aligned_i} -
                                   {obs_i_prev[W-1], obs_i_prev};
  wire signed [W:0] slew_q_delta = {aligned_q[W-1], aligned_q} -
                                   {obs_q_prev[W-1], obs_q_prev};
  wire [W:0] slew_i_abs = abs_delta(slew_i_delta);
  wire [W:0] slew_q_abs = abs_delta(slew_q_delta);
  wire [W+1:0] slew_now = {1'b0, slew_i_abs} + {1'b0, slew_q_abs};
  wire signed [31:0] aligned_i_ext = {{(32-W){aligned_i[W-1]}}, aligned_i};
  wire signed [31:0] aligned_q_ext = {{(32-W){aligned_q[W-1]}}, aligned_q};
  wire [31:0] spec_bin0_i_mag = abs_s32(spec_bin0_i_acc);
  wire [31:0] spec_bin0_q_mag = abs_s32(spec_bin0_q_acc);
  wire [31:0] spec_bin1_i_mag = abs_s32(spec_bin1_i_acc);
  wire [31:0] spec_bin1_q_mag = abs_s32(spec_bin1_q_acc);
  wire [31:0] spec_bin2_i_mag = abs_s32(spec_bin2_i_acc);
  wire [31:0] spec_bin2_q_mag = abs_s32(spec_bin2_q_acc);
  wire [32:0] spec_bin0_sum = {1'b0, spec_bin0_i_mag} + {1'b0, spec_bin0_q_mag};
  wire [32:0] spec_bin1_sum = {1'b0, spec_bin1_i_mag} + {1'b0, spec_bin1_q_mag};
  wire [32:0] spec_bin2_sum = {1'b0, spec_bin2_i_mag} + {1'b0, spec_bin2_q_mag};
  wire [32:0] spec_adj_sum = {1'b0, spec_bin0} + {1'b0, spec_bin2};

  assign spec_bin0 = spec_bin0_sum[32] ? 32'hffff_ffff : spec_bin0_sum[31:0];
  assign spec_bin1 = spec_bin1_sum[32] ? 32'hffff_ffff : spec_bin1_sum[31:0];
  assign spec_bin2 = spec_bin2_sum[32] ? 32'hffff_ffff : spec_bin2_sum[31:0];
  assign spec_adj = spec_adj_sum[32] ? 32'hffff_ffff : spec_adj_sum[31:0];

  assign obs_ready = enable & active;

  function [W-1:0] abs_sample;
    input signed [W-1:0] value;
    begin
      if (value == {1'b1, {(W-1){1'b0}}})
        abs_sample = {1'b0, {(W-1){1'b1}}};
      else if (value[W-1])
        abs_sample = (~value) + {{(W-1){1'b0}}, 1'b1};
      else
        abs_sample = value;
    end
  endfunction

  function [W:0] abs_delta;
    input signed [W:0] value;
    begin
      abs_delta = value[W] ? (~value) + {{W{1'b0}}, 1'b1} : value;
    end
  endfunction

  function [31:0] abs_s32;
    input signed [31:0] value;
    begin
      if (value == 32'sh8000_0000)
        abs_s32 = 32'h7fff_ffff;
      else if (value[31])
        abs_s32 = (~value) + 32'd1;
      else
        abs_s32 = value;
    end
  endfunction

  integer idx;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ref_wr_ptr <= {DELAY_AW{1'b0}};
      ref_count <= 32'd0;
      active <= 1'b0;
      done <= 1'b0;
      last_seen <= 1'b0;
      paired_count <= 32'd0;
      dropped_count <= 32'd0;
      error_acc <= 64'd0;
      latched_temperature_q8_8 <= 16'sd0;
      ref_mag_acc <= 32'd0;
      obs_mag_acc <= 32'd0;
      obs_peak <= 32'd0;
      clip_count <= 16'd0;
      saturation_count <= 16'd0;
      slew_acc <= 32'd0;
      obs_i_prev <= {W{1'b0}};
      obs_q_prev <= {W{1'b0}};
      obs_prev_valid <= 1'b0;
      spec_phase <= 2'd0;
      spec_bin0_i_acc <= 32'sd0;
      spec_bin0_q_acc <= 32'sd0;
      spec_bin1_i_acc <= 32'sd0;
      spec_bin1_q_acc <= 32'sd0;
      spec_bin2_i_acc <= 32'sd0;
      spec_bin2_q_acc <= 32'sd0;
      for (idx = 0; idx < DEPTH; idx = idx + 1) begin
        ref_i_mem[idx] <= {W{1'b0}};
        ref_q_mem[idx] <= {W{1'b0}};
      end
    end else begin
      if (ref_valid) begin
        ref_i_mem[ref_wr_ptr] <= ref_i;
        ref_q_mem[ref_wr_ptr] <= ref_q;
        ref_wr_ptr <= ref_wr_ptr + 1'b1;
        if (ref_count != 32'hffff_ffff) ref_count <= ref_count + 32'd1;
      end
      if (clear || start) begin
        paired_count <= 32'd0;
        dropped_count <= 32'd0;
        error_acc <= 64'd0;
        if (start) latched_temperature_q8_8 <= temperature_q8_8;
        ref_mag_acc <= 32'd0;
        obs_mag_acc <= 32'd0;
        obs_peak <= 32'd0;
        clip_count <= 16'd0;
        saturation_count <= 16'd0;
        slew_acc <= 32'd0;
        obs_i_prev <= {W{1'b0}};
        obs_q_prev <= {W{1'b0}};
        obs_prev_valid <= 1'b0;
        spec_phase <= 2'd0;
        spec_bin0_i_acc <= 32'sd0;
        spec_bin0_q_acc <= 32'sd0;
        spec_bin1_i_acc <= 32'sd0;
        spec_bin1_q_acc <= 32'sd0;
        spec_bin2_i_acc <= 32'sd0;
        spec_bin2_q_acc <= 32'sd0;
        done <= 1'b0;
        last_seen <= 1'b0;
        active <= start & enable;
      end else begin
        if (!enable) active <= 1'b0;
        if (obs_fire) begin
          if (obs_last) last_seen <= 1'b1;
          if (obs_invalid || !ref_available) begin
            dropped_count <= dropped_count + 32'd1;
          end else begin
            paired_count <= paired_count + 32'd1;
            error_acc <= error_acc + error_now;
            ref_mag_acc <= ref_mag_acc + ref_mag_now;
            obs_mag_acc <= obs_mag_acc + obs_mag_now;
            if (obs_mag_sat > obs_peak) obs_peak <= obs_mag_sat;
            if (obs_clip_now) clip_count <= clip_count + 16'd1;
            if (aligned_i_saturated || aligned_q_saturated)
              saturation_count <= saturation_count + 16'd1;
            if (obs_prev_valid) slew_acc <= slew_acc + slew_now;
            obs_i_prev <= aligned_i;
            obs_q_prev <= aligned_q;
            obs_prev_valid <= 1'b1;
            spec_bin0_i_acc <= spec_bin0_i_acc + aligned_i_ext;
            spec_bin0_q_acc <= spec_bin0_q_acc + aligned_q_ext;
            if (spec_phase[0]) begin
              spec_bin2_i_acc <= spec_bin2_i_acc - aligned_i_ext;
              spec_bin2_q_acc <= spec_bin2_q_acc - aligned_q_ext;
            end else begin
              spec_bin2_i_acc <= spec_bin2_i_acc + aligned_i_ext;
              spec_bin2_q_acc <= spec_bin2_q_acc + aligned_q_ext;
            end
            case (spec_phase)
              2'd0: begin
                spec_bin1_i_acc <= spec_bin1_i_acc + aligned_i_ext;
                spec_bin1_q_acc <= spec_bin1_q_acc + aligned_q_ext;
              end
              2'd1: begin
                spec_bin1_i_acc <= spec_bin1_i_acc + aligned_q_ext;
                spec_bin1_q_acc <= spec_bin1_q_acc - aligned_i_ext;
              end
              2'd2: begin
                spec_bin1_i_acc <= spec_bin1_i_acc - aligned_i_ext;
                spec_bin1_q_acc <= spec_bin1_q_acc - aligned_q_ext;
              end
              default: begin
                spec_bin1_i_acc <= spec_bin1_i_acc - aligned_q_ext;
                spec_bin1_q_acc <= spec_bin1_q_acc + aligned_i_ext;
              end
            endcase
            spec_phase <= spec_phase + 2'd1;
            if ((window_samples != 0) &&
                ((paired_count + 32'd1) >= window_samples)) begin
              active <= 1'b0;
              done <= 1'b1;
            end
          end
        end
      end
    end
  end

endmodule

`default_nettype wire
