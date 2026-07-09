`timescale 1ns/1ps
`default_nettype none

module dpd_frontend #(
  parameter integer W = 16,
  parameter integer COEFF_W = 16,
  parameter integer COEFF_FRAC = 14,
  parameter integer LUT_AW = 4
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

  input wire lut_we,
  input wire lut_commit,
  input wire [LUT_AW-1:0] lut_waddr,
  input wire signed [COEFF_W-1:0] lut_wgain_re,
  input wire signed [COEFF_W-1:0] lut_wgain_im,
  input wire [LUT_AW-1:0] lut_raddr,
  output wire signed [COEFF_W-1:0] lut_rgain_re,
  output wire signed [COEFF_W-1:0] lut_rgain_im,
  output wire lut_active_bank,

  input wire signed [W-1:0] i_in,
  input wire signed [W-1:0] q_in,
  input wire in_valid,
  output wire in_ready,

  output wire signed [W-1:0] i_out,
  output wire signed [W-1:0] q_out,
  output wire out_valid,
  input wire out_ready,

  output reg [31:0] sample_count,
  output reg [31:0] saturation_count
);

  localparam [1:0] DPD_MODE_BYPASS = 2'd0;
  localparam [1:0] DPD_MODE_POLY   = 2'd1;
  localparam [1:0] DPD_MODE_LUT    = 2'd2;
  localparam integer PIPE_STAGES = 9;

  wire signed [W-1:0] poly_i;
  wire signed [W-1:0] poly_q;
  wire poly_valid;
  wire poly_ready_unused;
  wire [31:0] poly_sample_count;
  wire [31:0] poly_saturation_count;

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

  wire pipe_ce = out_ready | !valid_pipe[PIPE_STAGES-1];
  wire pipe_out_valid = valid_pipe[PIPE_STAGES-1];
  wire output_fire = out_valid & out_ready;
  wire poly_sat_event = (poly_saturation_count != poly_saturation_count_d);

  assign in_ready = pipe_ce;
  assign out_valid = pipe_out_valid;
  assign i_out =
      (mode_pipe[PIPE_STAGES-1] == DPD_MODE_POLY) ? poly_i :
      (mode_pipe[PIPE_STAGES-1] == DPD_MODE_LUT)  ? lut_i_pipe[PIPE_STAGES-1] :
                                                    bypass_i_pipe[PIPE_STAGES-1];
  assign q_out =
      (mode_pipe[PIPE_STAGES-1] == DPD_MODE_POLY) ? poly_q :
      (mode_pipe[PIPE_STAGES-1] == DPD_MODE_LUT)  ? lut_q_pipe[PIPE_STAGES-1] :
                                                    bypass_q_pipe[PIPE_STAGES-1];

  dpd_poly #(
    .W(W),
    .COEFF_W(COEFF_W),
    .COEFF_FRAC(COEFF_FRAC)
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

  dpd_lut #(
    .W(W),
    .COEFF_W(COEFF_W),
    .COEFF_FRAC(COEFF_FRAC),
    .LUT_AW(LUT_AW)
  ) u_lut (
    .clk(clk),
    .rst_n(rst_n),
    .lut_we(lut_we),
    .lut_commit(lut_commit),
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

  integer st;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_pipe <= {PIPE_STAGES{1'b0}};
      lut_sat_pipe <= {PIPE_STAGES{1'b0}};
      sample_count <= 32'd0;
      saturation_count <= 32'd0;
      poly_saturation_count_d <= 32'd0;
      for (st = 0; st < PIPE_STAGES; st = st + 1) begin
        mode_pipe[st] <= DPD_MODE_BYPASS;
        bypass_i_pipe[st] <= {W{1'b0}};
        bypass_q_pipe[st] <= {W{1'b0}};
        lut_i_pipe[st] <= {W{1'b0}};
        lut_q_pipe[st] <= {W{1'b0}};
      end
    end else begin
      if (pipe_ce) begin
        valid_pipe <= {valid_pipe[PIPE_STAGES-2:0], in_valid};
        lut_sat_pipe <= {lut_sat_pipe[PIPE_STAGES-2:0], lut_sat_now};
        poly_saturation_count_d <= poly_saturation_count;

        mode_pipe[0] <= mode;
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
          case (mode_pipe[PIPE_STAGES-1])
            DPD_MODE_POLY: begin
              if (poly_sat_event) begin
                saturation_count <= saturation_count + 32'd1;
              end
            end
            DPD_MODE_LUT: begin
              if (lut_sat_pipe[PIPE_STAGES-1]) begin
                saturation_count <= saturation_count + 32'd1;
              end
            end
            default: begin end
          endcase
        end

        if (in_valid) begin
          sample_count <= sample_count + 32'd1;
        end
      end
    end
  end

endmodule

`default_nettype wire
