`timescale 1ns/1ps
`default_nettype none

module dpd_frontend #(
  parameter integer W = 16,
  parameter integer COEFF_W = 16,
  parameter integer COEFF_FRAC = 14,
  parameter integer LUT_AW = 4,
  // The shipped configuration is 4 taps / 5th order.  Larger tap counts
  // use the same pipelined memory-polynomial datapath at synthesis time.
  parameter integer MP_MAX_TAPS = 4,
  parameter integer MP_POLY_ORDER = 5,
  parameter integer COEFF_SAFE_ABS = 24576,
  parameter integer ENABLE_DPD_POLY = 1,
  parameter integer ENABLE_DPD_LUT = 1,
  parameter integer ENABLE_DPD_MEMORY = 1
) (
  input wire clk,
  input wire rst_n,
  input wire [1:0] mode,

  input wire signed [COEFF_W-1:0] c1_re,
  input wire signed [COEFF_W-1:0] c1_im,
  input wire signed [COEFF_W-1:0] c3_re,
  input wire signed [COEFF_W-1:0] c3_im,
  input wire signed [COEFF_W-1:0] c5_re,
  input wire signed [COEFF_W-1:0] c5_im,
  input wire signed [COEFF_W-1:0] c7_re,
  input wire signed [COEFF_W-1:0] c7_im,

  input wire [2:0] mp_active_taps,
  input wire mp_coeff_we,
  input wire mp_commit,
  input wire [2:0] mp_coeff_tap,
  input wire [1:0] mp_coeff_order,
  input wire signed [COEFF_W-1:0] mp_coeff_re,
  input wire signed [COEFF_W-1:0] mp_coeff_im,
  output wire signed [COEFF_W-1:0] mp_coeff_rdata_re,
  output wire signed [COEFF_W-1:0] mp_coeff_rdata_im,
  output reg mp_active_bank,

  input wire lut_we,
  input wire lut_commit,
  input wire [LUT_AW-1:0] lut_waddr,
  input wire signed [COEFF_W-1:0] lut_wgain_re,
  input wire signed [COEFF_W-1:0] lut_wgain_im,
  input wire [LUT_AW-1:0] lut_raddr,
  output wire signed [COEFF_W-1:0] lut_rgain_re,
  output wire signed [COEFF_W-1:0] lut_rgain_im,
  output wire lut_active_bank,

  input wire safety_enable,
  input wire safety_clear,
  output reg safety_fault,
  output reg mp_commit_rejected,
  output reg lut_commit_rejected,

  input wire signed [W-1:0] i_in,
  input wire signed [W-1:0] q_in,
  input wire in_valid,
  output wire in_ready,

  output wire signed [W-1:0] i_out,
  output wire signed [W-1:0] q_out,
  output wire out_valid,
  input wire out_ready,

  // Exposes the actual selected path after compile-time feature pruning and
  // safety fallback.  `busy` stays high until every accepted sample has
  // left the aligned ten-stage frontend pipeline.
  output wire [1:0] effective_mode_out,
  output wire busy,

  output reg [31:0] sample_count,
  output reg [31:0] saturation_count
);

  localparam [1:0] DPD_MODE_BYPASS = 2'd0;
  localparam [1:0] DPD_MODE_POLY   = 2'd1;
  localparam [1:0] DPD_MODE_LUT    = 2'd2;
  localparam [1:0] DPD_MODE_MEMORY = 2'd3;
  // Keep bypass, LUT, and polynomial paths aligned with the ten-stage
  // memory-polynomial pipeline.
  localparam integer PIPE_STAGES = 10;
  localparam integer LAST_PIPE_STAGE = PIPE_STAGES - 1;
  localparam integer MAX_MP_TAPS = MP_MAX_TAPS;
  localparam [2:0] MAX_MP_TAPS_U = MAX_MP_TAPS;

  wire signed [W-1:0] poly_i;
  wire signed [W-1:0] poly_q;
  wire poly_valid;
  wire poly_ready_unused;
  wire [31:0] poly_sample_count;
  wire [31:0] poly_saturation_count;
  wire signed [W-1:0] mp_i;
  wire signed [W-1:0] mp_q;
  wire mp_valid;
  wire mp_ready_unused;
  wire [31:0] mp_sample_count;
  wire [31:0] mp_saturation_count;

  reg signed [COEFF_W-1:0] mp_coeff_re_mem0 [0:MAX_MP_TAPS-1][0:2];
  reg signed [COEFF_W-1:0] mp_coeff_im_mem0 [0:MAX_MP_TAPS-1][0:2];
  reg signed [COEFF_W-1:0] mp_coeff_re_mem1 [0:MAX_MP_TAPS-1][0:2];
  reg signed [COEFF_W-1:0] mp_coeff_im_mem1 [0:MAX_MP_TAPS-1][0:2];
  wire signed [(MAX_MP_TAPS*COEFF_W)-1:0] mp_c1_re_flat;
  wire signed [(MAX_MP_TAPS*COEFF_W)-1:0] mp_c1_im_flat;
  wire signed [(MAX_MP_TAPS*COEFF_W)-1:0] mp_c3_re_flat;
  wire signed [(MAX_MP_TAPS*COEFF_W)-1:0] mp_c3_im_flat;
  wire signed [(MAX_MP_TAPS*COEFF_W)-1:0] mp_c5_re_flat;
  wire signed [(MAX_MP_TAPS*COEFF_W)-1:0] mp_c5_im_flat;

  wire signed [W-1:0] lut_i_now;
  wire signed [W-1:0] lut_q_now;
  wire lut_sat_now;

  reg [PIPE_STAGES-1:0] valid_pipe;
  reg [1:0] mode_pipe [0:PIPE_STAGES-1];
  reg signed [W-1:0] bypass_i_pipe [0:PIPE_STAGES-1];
  reg signed [W-1:0] bypass_q_pipe [0:PIPE_STAGES-1];
  reg signed [W-1:0] lut_i_pipe [0:PIPE_STAGES-1];
  reg signed [W-1:0] lut_q_pipe [0:PIPE_STAGES-1];
  reg [PIPE_STAGES-1:0] lut_sat_pipe;
  reg [31:0] poly_saturation_count_d;
  reg [31:0] mp_saturation_count_d;
  reg signed [W-1:0] poly_i_align;
  reg signed [W-1:0] poly_q_align;
  reg mp_shadow_invalid;
  reg lut_shadow_invalid;

  // A single clock-enable advances every aligned path together.  This keeps
  // the bypass, LUT, polynomial, and memory-polynomial results coherent when
  // the downstream AXI-Stream sink applies backpressure.
  wire pipe_ce = out_ready | !valid_pipe[LAST_PIPE_STAGE];
  wire pipe_out_valid = valid_pipe[LAST_PIPE_STAGE];
  wire output_fire = out_valid & out_ready;
  wire poly_sat_event = (poly_saturation_count != poly_saturation_count_d);
  wire mp_sat_event = (mp_saturation_count != mp_saturation_count_d);
  wire lut_write_unsafe = (lut_wgain_re > COEFF_SAFE_ABS) ||
                          (lut_wgain_re < -COEFF_SAFE_ABS) ||
                          (lut_wgain_im > COEFF_SAFE_ABS) ||
                          (lut_wgain_im < -COEFF_SAFE_ABS);
  wire mp_write_unsafe = (mp_coeff_re > COEFF_SAFE_ABS) ||
                         (mp_coeff_re < -COEFF_SAFE_ABS) ||
                         (mp_coeff_im > COEFF_SAFE_ABS) ||
                         (mp_coeff_im < -COEFF_SAFE_ABS);
  wire lut_we_safe = lut_we && (!safety_enable || !lut_write_unsafe);
  wire [1:0] requested_mode = (safety_enable && safety_fault) ?
                              DPD_MODE_BYPASS : mode;
  wire mode_supported =
      ((requested_mode == DPD_MODE_BYPASS) ||
       ((requested_mode == DPD_MODE_POLY) && ENABLE_DPD_POLY) ||
       ((requested_mode == DPD_MODE_LUT) && ENABLE_DPD_LUT) ||
       ((requested_mode == DPD_MODE_MEMORY) && ENABLE_DPD_MEMORY));
  wire [1:0] effective_mode = mode_supported ? requested_mode : DPD_MODE_BYPASS;

  assign in_ready = pipe_ce;
  assign out_valid = pipe_out_valid;
  assign effective_mode_out = effective_mode;
  assign busy = |valid_pipe;
  assign i_out =
      (mode_pipe[LAST_PIPE_STAGE] == DPD_MODE_POLY) ? poly_i_align :
      (mode_pipe[LAST_PIPE_STAGE] == DPD_MODE_LUT)  ? lut_i_pipe[LAST_PIPE_STAGE] :
      (mode_pipe[LAST_PIPE_STAGE] == DPD_MODE_MEMORY) ? mp_i :
                                                       bypass_i_pipe[LAST_PIPE_STAGE];
  assign q_out =
      (mode_pipe[LAST_PIPE_STAGE] == DPD_MODE_POLY) ? poly_q_align :
      (mode_pipe[LAST_PIPE_STAGE] == DPD_MODE_LUT)  ? lut_q_pipe[LAST_PIPE_STAGE] :
      (mode_pipe[LAST_PIPE_STAGE] == DPD_MODE_MEMORY) ? mp_q :
                                                       bypass_q_pipe[LAST_PIPE_STAGE];

  assign mp_coeff_rdata_re = (ENABLE_DPD_MEMORY && (mp_coeff_order < 3)) ?
      (mp_active_bank ? mp_coeff_re_mem0[mp_coeff_tap][mp_coeff_order] :
                        mp_coeff_re_mem1[mp_coeff_tap][mp_coeff_order]) :
      {COEFF_W{1'b0}};
  assign mp_coeff_rdata_im = (ENABLE_DPD_MEMORY && (mp_coeff_order < 3)) ?
      (mp_active_bank ? mp_coeff_im_mem0[mp_coeff_tap][mp_coeff_order] :
                        mp_coeff_im_mem1[mp_coeff_tap][mp_coeff_order]) :
      {COEFF_W{1'b0}};

  genvar mp_tap;
  generate
    if (ENABLE_DPD_MEMORY) begin : g_memory_enabled
      for (mp_tap = 0; mp_tap < MAX_MP_TAPS; mp_tap = mp_tap + 1) begin : g_mp_flatten
      assign mp_c1_re_flat[(mp_tap*COEFF_W) +: COEFF_W] = mp_active_bank ?
          mp_coeff_re_mem1[mp_tap][0] : mp_coeff_re_mem0[mp_tap][0];
      assign mp_c1_im_flat[(mp_tap*COEFF_W) +: COEFF_W] = mp_active_bank ?
          mp_coeff_im_mem1[mp_tap][0] : mp_coeff_im_mem0[mp_tap][0];
      assign mp_c3_re_flat[(mp_tap*COEFF_W) +: COEFF_W] = mp_active_bank ?
          mp_coeff_re_mem1[mp_tap][1] : mp_coeff_re_mem0[mp_tap][1];
      assign mp_c3_im_flat[(mp_tap*COEFF_W) +: COEFF_W] = mp_active_bank ?
          mp_coeff_im_mem1[mp_tap][1] : mp_coeff_im_mem0[mp_tap][1];
      assign mp_c5_re_flat[(mp_tap*COEFF_W) +: COEFF_W] = mp_active_bank ?
          ((MP_POLY_ORDER >= 5) ? mp_coeff_re_mem1[mp_tap][2] : {COEFF_W{1'b0}}) :
          ((MP_POLY_ORDER >= 5) ? mp_coeff_re_mem0[mp_tap][2] : {COEFF_W{1'b0}});
      assign mp_c5_im_flat[(mp_tap*COEFF_W) +: COEFF_W] = mp_active_bank ?
          ((MP_POLY_ORDER >= 5) ? mp_coeff_im_mem1[mp_tap][2] : {COEFF_W{1'b0}}) :
          ((MP_POLY_ORDER >= 5) ? mp_coeff_im_mem0[mp_tap][2] : {COEFF_W{1'b0}});
      end
    end else begin : g_memory_disabled
      assign mp_c1_re_flat = {(MAX_MP_TAPS*COEFF_W){1'b0}};
      assign mp_c1_im_flat = {(MAX_MP_TAPS*COEFF_W){1'b0}};
      assign mp_c3_re_flat = {(MAX_MP_TAPS*COEFF_W){1'b0}};
      assign mp_c3_im_flat = {(MAX_MP_TAPS*COEFF_W){1'b0}};
      assign mp_c5_re_flat = {(MAX_MP_TAPS*COEFF_W){1'b0}};
      assign mp_c5_im_flat = {(MAX_MP_TAPS*COEFF_W){1'b0}};
    end
  endgenerate

  generate
    if (ENABLE_DPD_POLY) begin : g_poly_enabled
  dpd_poly #(
    .W(W),
    .COEFF_W(COEFF_W),
    .COEFF_FRAC(COEFF_FRAC),
    .POLY_ORDER(MP_POLY_ORDER)
  ) u_poly (
    .clk(clk),
    .rst_n(rst_n),
    .enable(1'b1),
    .c1_re(c1_re),
    .c1_im(c1_im),
    .c3_re(c3_re),
    .c3_im(c3_im),
    .c5_re(c5_re),
    .c5_im(c5_im),
    .c7_re(c7_re),
    .c7_im(c7_im),
    .i_in(i_in),
    .q_in(q_in),
    .in_valid(in_valid),
    .in_ready(poly_ready_unused),
    .i_out(poly_i),
    .q_out(poly_q),
    .out_valid(poly_valid),
    .out_ready(pipe_ce),
    .sample_count(poly_sample_count),
    .saturation_count(poly_saturation_count)
  );
    end else begin : g_poly_disabled
      assign poly_i = {W{1'b0}};
      assign poly_q = {W{1'b0}};
      assign poly_valid = 1'b0;
      assign poly_ready_unused = pipe_ce;
      assign poly_sample_count = 32'd0;
      assign poly_saturation_count = 32'd0;
    end
  endgenerate

  generate
    if (ENABLE_DPD_LUT) begin : g_lut_enabled
  dpd_lut #(
    .W(W),
    .COEFF_W(COEFF_W),
    .COEFF_FRAC(COEFF_FRAC),
    .LUT_AW(LUT_AW)
  ) u_lut (
    .clk(clk),
    .rst_n(rst_n),
    .lut_we(lut_we_safe),
    .lut_commit(lut_commit && (!safety_enable || !lut_shadow_invalid)),
    .lut_waddr(lut_waddr),
    .lut_wgain_re(lut_wgain_re),
    .lut_wgain_im(lut_wgain_im),
    .lut_raddr(lut_raddr),
    .lut_rgain_re(lut_rgain_re),
    .lut_rgain_im(lut_rgain_im),
    .active_bank(lut_active_bank),
    .i_in(i_in),
    .q_in(q_in),
    .i_out(lut_i_now),
    .q_out(lut_q_now),
    .sat(lut_sat_now)
  );
    end else begin : g_lut_disabled
      assign lut_i_now = i_in;
      assign lut_q_now = q_in;
      assign lut_sat_now = 1'b0;
      assign lut_rgain_re = {COEFF_W{1'b0}};
      assign lut_rgain_im = {COEFF_W{1'b0}};
      assign lut_active_bank = 1'b0;
    end
  endgenerate

  generate
    if (ENABLE_DPD_MEMORY) begin : g_memory_datapath_enabled
  dpd_memory_poly #(
    .W(W),
    .COEFF_W(COEFF_W),
    .COEFF_FRAC(COEFF_FRAC),
    .MAX_TAPS(MAX_MP_TAPS)
  ) u_memory_poly (
    .clk(clk),
    .rst_n(rst_n),
    .active_taps((mp_active_taps < 3'd1) ? 3'd1 :
                 ((mp_active_taps > MAX_MP_TAPS_U) ? MAX_MP_TAPS_U : mp_active_taps)),
    .c1_re(mp_c1_re_flat),
    .c1_im(mp_c1_im_flat),
    .c3_re(mp_c3_re_flat),
    .c3_im(mp_c3_im_flat),
    .c5_re(mp_c5_re_flat),
    .c5_im(mp_c5_im_flat),
    .i_in(i_in),
    .q_in(q_in),
    .in_valid(in_valid),
    .in_ready(mp_ready_unused),
    .i_out(mp_i),
    .q_out(mp_q),
    .out_valid(mp_valid),
    .out_ready(pipe_ce),
    .sample_count(mp_sample_count),
    .saturation_count(mp_saturation_count)
  );
    end else begin : g_memory_datapath_disabled
      assign mp_i = {W{1'b0}};
      assign mp_q = {W{1'b0}};
      assign mp_valid = 1'b0;
      assign mp_ready_unused = pipe_ce;
      assign mp_sample_count = 32'd0;
      assign mp_saturation_count = 32'd0;
    end
  endgenerate

  integer st;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_pipe <= {PIPE_STAGES{1'b0}};
      lut_sat_pipe <= {PIPE_STAGES{1'b0}};
      sample_count <= 32'd0;
      saturation_count <= 32'd0;
      poly_saturation_count_d <= 32'd0;
      mp_saturation_count_d <= 32'd0;
      poly_i_align <= {W{1'b0}};
      poly_q_align <= {W{1'b0}};
      mp_active_bank <= 1'b0;
      safety_fault <= 1'b0;
      mp_commit_rejected <= 1'b0;
      lut_commit_rejected <= 1'b0;
      mp_shadow_invalid <= 1'b0;
      lut_shadow_invalid <= 1'b0;
      for (st = 0; st < PIPE_STAGES; st = st + 1) begin
        mode_pipe[st] <= DPD_MODE_BYPASS;
        bypass_i_pipe[st] <= {W{1'b0}};
        bypass_q_pipe[st] <= {W{1'b0}};
        lut_i_pipe[st] <= {W{1'b0}};
        lut_q_pipe[st] <= {W{1'b0}};
      end
      for (st = 0; st < MAX_MP_TAPS; st = st + 1) begin
        mp_coeff_re_mem0[st][0] <= (st == 0) ? 16'sd16384 : 16'sd0;
        mp_coeff_im_mem0[st][0] <= 16'sd0;
        mp_coeff_re_mem0[st][1] <= 16'sd0;
        mp_coeff_im_mem0[st][1] <= 16'sd0;
        mp_coeff_re_mem0[st][2] <= 16'sd0;
        mp_coeff_im_mem0[st][2] <= 16'sd0;
        mp_coeff_re_mem1[st][0] <= (st == 0) ? 16'sd16384 : 16'sd0;
        mp_coeff_im_mem1[st][0] <= 16'sd0;
        mp_coeff_re_mem1[st][1] <= 16'sd0;
        mp_coeff_im_mem1[st][1] <= 16'sd0;
        mp_coeff_re_mem1[st][2] <= 16'sd0;
        mp_coeff_im_mem1[st][2] <= 16'sd0;
      end
    end else begin
      if (safety_clear) begin
        safety_fault <= 1'b0;
        // Abandon a rejected inactive-bank update before a complete reload.
        mp_shadow_invalid <= 1'b0;
        lut_shadow_invalid <= 1'b0;
        mp_commit_rejected <= 1'b0;
        lut_commit_rejected <= 1'b0;
      end
      if (ENABLE_DPD_MEMORY && mp_coeff_we && (mp_coeff_tap < MAX_MP_TAPS) &&
          (mp_coeff_order < 3)) begin
        if (safety_enable && mp_write_unsafe) begin
          mp_shadow_invalid <= 1'b1;
        end else begin
          if (mp_active_bank) begin
            mp_coeff_re_mem0[mp_coeff_tap][mp_coeff_order] <= mp_coeff_re;
            mp_coeff_im_mem0[mp_coeff_tap][mp_coeff_order] <= mp_coeff_im;
          end else begin
            mp_coeff_re_mem1[mp_coeff_tap][mp_coeff_order] <= mp_coeff_re;
            mp_coeff_im_mem1[mp_coeff_tap][mp_coeff_order] <= mp_coeff_im;
          end
        end
      end
      if (ENABLE_DPD_MEMORY && mp_commit) begin
        if (safety_enable && mp_shadow_invalid) begin
          mp_commit_rejected <= 1'b1;
        end else begin
          mp_active_bank <= ~mp_active_bank;
          mp_shadow_invalid <= 1'b0;
        end
      end
      if (ENABLE_DPD_LUT && lut_we && safety_enable && lut_write_unsafe) begin
        lut_shadow_invalid <= 1'b1;
      end
      if (ENABLE_DPD_LUT && lut_commit) begin
        if (safety_enable && lut_shadow_invalid) begin
          lut_commit_rejected <= 1'b1;
        end else begin
          lut_shadow_invalid <= 1'b0;
        end
      end
      if (pipe_ce) begin
        valid_pipe <= {valid_pipe[PIPE_STAGES-2:0], in_valid};
        lut_sat_pipe <= {lut_sat_pipe[PIPE_STAGES-2:0], lut_sat_now};
        poly_saturation_count_d <= poly_saturation_count;
        mp_saturation_count_d <= mp_saturation_count;
        if (poly_valid) begin
          poly_i_align <= poly_i;
          poly_q_align <= poly_q;
        end

        mode_pipe[0] <= effective_mode;
        bypass_i_pipe[0] <= i_in;
        bypass_q_pipe[0] <= q_in;
        lut_i_pipe[0] <= lut_i_now;
        lut_q_pipe[0] <= lut_q_now;
        for (st = 1; st < PIPE_STAGES; st = st + 1) begin
          mode_pipe[st] <= mode_pipe[st-1];
          bypass_i_pipe[st] <= bypass_i_pipe[st-1];
          bypass_q_pipe[st] <= bypass_q_pipe[st-1];
          lut_i_pipe[st] <= lut_i_pipe[st-1];
          lut_q_pipe[st] <= lut_q_pipe[st-1];
        end

        if (output_fire) begin
          case (mode_pipe[LAST_PIPE_STAGE])
            DPD_MODE_POLY: begin
              if (poly_sat_event) begin
                saturation_count <= saturation_count + 32'd1;
              end
            end
            DPD_MODE_LUT: begin
              if (lut_sat_pipe[LAST_PIPE_STAGE]) begin
                saturation_count <= saturation_count + 32'd1;
              end
            end
            DPD_MODE_MEMORY: begin
              if (mp_sat_event) begin
                saturation_count <= saturation_count + 32'd1;
              end
            end
            default: begin end
          endcase
        end

        if (safety_enable && output_fire &&
            ((mode_pipe[LAST_PIPE_STAGE] == DPD_MODE_POLY && poly_sat_event) ||
             (mode_pipe[LAST_PIPE_STAGE] == DPD_MODE_LUT && lut_sat_pipe[LAST_PIPE_STAGE]) ||
             (mode_pipe[LAST_PIPE_STAGE] == DPD_MODE_MEMORY && mp_sat_event))) begin
          safety_fault <= 1'b1;
        end

        if (in_valid) begin
          sample_count <= sample_count + 32'd1;
        end
      end
    end
  end

endmodule

`default_nettype wire
