`timescale 1ns/1ps
`default_nettype none

module dsm_interp_fir_fixed #(
  parameter int W_IN = 16,
  parameter int W_OUT = 16,
  parameter int COEFF_W = 18,
  parameter int COEFF_FRAC = 16,
  parameter int ACC_W = 48,
  parameter int NTAPS = 29,
  parameter int INTERP = 8,
  parameter int COEFF_SET = 2
) (
  input  wire                         clk,
  input  wire                         rst_n,
  input  wire                         enable,
  input  wire signed [W_IN-1:0]       in_data,
  input  wire                         in_valid,
  output wire                         in_ready,
  output logic signed [W_OUT-1:0]     out_data,
  output logic                        out_valid,
  input  wire                         out_ready
);

  localparam int PHASE_BITS = (INTERP <= 1) ? 1 : $clog2(INTERP);
  logic [PHASE_BITS-1:0] phase;
  logic signed [W_IN-1:0] shift_reg [0:NTAPS-2];
  localparam int PAIRS = NTAPS / 2;
  localparam int G1 = (PAIRS + 3) / 4;
  localparam int G2 = (G1 + 3) / 4;

  logic signed [ACC_W-1:0] prod_s1 [0:PAIRS-1];
  logic signed [ACC_W-1:0] center_s1;
  logic signed [ACC_W-1:0] sum_s2 [0:G1-1];
  logic signed [ACC_W-1:0] center_s2;
  logic signed [ACC_W-1:0] sum_s3 [0:G2-1];
  logic signed [ACC_W-1:0] center_s3;
  logic valid_s1;
  logic valid_s2;
  logic valid_s3;

  function automatic signed [COEFF_W-1:0] coeff_cic(input int idx);
    begin
      case (idx)
        0:  coeff_cic = 18'sd128;
        1:  coeff_cic = 18'sd512;
        2:  coeff_cic = 18'sd1280;
        3:  coeff_cic = 18'sd2560;
        4:  coeff_cic = 18'sd4480;
        5:  coeff_cic = 18'sd7168;
        6:  coeff_cic = 18'sd10752;
        7:  coeff_cic = 18'sd15360;
        8:  coeff_cic = 18'sd20608;
        9:  coeff_cic = 18'sd26112;
        10: coeff_cic = 18'sd31488;
        11: coeff_cic = 18'sd36352;
        12: coeff_cic = 18'sd40320;
        13: coeff_cic = 18'sd43008;
        14: coeff_cic = 18'sd44032;
        15: coeff_cic = 18'sd43008;
        16: coeff_cic = 18'sd40320;
        17: coeff_cic = 18'sd36352;
        18: coeff_cic = 18'sd31488;
        19: coeff_cic = 18'sd26112;
        20: coeff_cic = 18'sd20608;
        21: coeff_cic = 18'sd15360;
        22: coeff_cic = 18'sd10752;
        23: coeff_cic = 18'sd7168;
        24: coeff_cic = 18'sd4480;
        25: coeff_cic = 18'sd2560;
        26: coeff_cic = 18'sd1280;
        27: coeff_cic = 18'sd512;
        28: coeff_cic = 18'sd128;
        default: coeff_cic = '0;
      endcase
    end
  endfunction

  function automatic signed [COEFF_W-1:0] coeff_comp(input int idx);
    begin
      case (idx)
        0:  coeff_comp = 18'sd182;
        1:  coeff_comp = 18'sd167;
        2:  coeff_comp = 18'sd157;
        3:  coeff_comp = 18'sd148;
        4:  coeff_comp = 18'sd132;
        5:  coeff_comp = 18'sd101;
        6:  coeff_comp = 18'sd46;
        7:  coeff_comp = -18'sd36;
        8:  coeff_comp = -18'sd152;
        9:  coeff_comp = -18'sd298;
        10: coeff_comp = -18'sd473;
        11: coeff_comp = -18'sd665;
        12: coeff_comp = -18'sd861;
        13: coeff_comp = -18'sd1041;
        14: coeff_comp = -18'sd1185;
        15: coeff_comp = -18'sd1268;
        16: coeff_comp = -18'sd1270;
        17: coeff_comp = -18'sd1167;
        18: coeff_comp = -18'sd946;
        19: coeff_comp = -18'sd596;
        20: coeff_comp = -18'sd117;
        21: coeff_comp = 18'sd485;
        22: coeff_comp = 18'sd1193;
        23: coeff_comp = 18'sd1982;
        24: coeff_comp = 18'sd2818;
        25: coeff_comp = 18'sd3664;
        26: coeff_comp = 18'sd4475;
        27: coeff_comp = 18'sd5212;
        28: coeff_comp = 18'sd5832;
        29: coeff_comp = 18'sd6303;
        30: coeff_comp = 18'sd6596;
        31: coeff_comp = 18'sd6696;
        32: coeff_comp = 18'sd6596;
        33: coeff_comp = 18'sd6303;
        34: coeff_comp = 18'sd5832;
        35: coeff_comp = 18'sd5212;
        36: coeff_comp = 18'sd4475;
        37: coeff_comp = 18'sd3664;
        38: coeff_comp = 18'sd2818;
        39: coeff_comp = 18'sd1982;
        40: coeff_comp = 18'sd1193;
        41: coeff_comp = 18'sd485;
        42: coeff_comp = -18'sd117;
        43: coeff_comp = -18'sd596;
        44: coeff_comp = -18'sd946;
        45: coeff_comp = -18'sd1167;
        46: coeff_comp = -18'sd1270;
        47: coeff_comp = -18'sd1268;
        48: coeff_comp = -18'sd1185;
        49: coeff_comp = -18'sd1041;
        50: coeff_comp = -18'sd861;
        51: coeff_comp = -18'sd665;
        52: coeff_comp = -18'sd473;
        53: coeff_comp = -18'sd298;
        54: coeff_comp = -18'sd152;
        55: coeff_comp = -18'sd36;
        56: coeff_comp = 18'sd46;
        57: coeff_comp = 18'sd101;
        58: coeff_comp = 18'sd132;
        59: coeff_comp = 18'sd148;
        60: coeff_comp = 18'sd157;
        61: coeff_comp = 18'sd167;
        62: coeff_comp = 18'sd182;
        default: coeff_comp = '0;
      endcase
    end
  endfunction

  function automatic signed [COEFF_W-1:0] coeff(input int idx);
    begin
      if (COEFF_SET == 2) begin
        coeff = coeff_cic(idx);
      end else begin
        coeff = coeff_comp(idx);
      end
    end
  endfunction

  function automatic signed [W_OUT-1:0] sat_out(input signed [ACC_W-1:0] x);
    logic signed [ACC_W-1:0] maxv;
    logic signed [ACC_W-1:0] minv;
    begin
      maxv = (signed'(1) <<< (W_OUT - 1)) - 1;
      minv = -(signed'(1) <<< (W_OUT - 1));
      if (x > maxv) begin
        sat_out = signed'(maxv[W_OUT-1:0]);
      end else if (x < minv) begin
        sat_out = signed'(minv[W_OUT-1:0]);
      end else begin
        sat_out = signed'(x[W_OUT-1:0]);
      end
    end
  endfunction

  function automatic signed [ACC_W-1:0] round_shift(input signed [ACC_W-1:0] x);
    logic signed [ACC_W-1:0] bias;
    begin
      bias = signed'(1) <<< (COEFF_FRAC - 1);
      if (x >= 0) begin
        round_shift = (x + bias) >>> COEFF_FRAC;
      end else begin
        round_shift = -(((-x) + bias) >>> COEFF_FRAC);
      end
    end
  endfunction

  wire pipe_ready = (!out_valid) || out_ready;
  wire phase_zero = (phase == '0);
  wire do_step = pipe_ready && enable && (phase_zero ? in_valid : 1'b1);
  wire signed [W_IN-1:0] step_sample = phase_zero ? in_data : '0;

  assign in_ready = pipe_ready && enable && phase_zero;

  always_ff @(posedge clk) begin : p_fir
    logic signed [ACC_W-1:0] total;
    logic signed [ACC_W-1:0] rounded;
    logic signed [W_IN-1:0] tap_a;
    logic signed [W_IN-1:0] tap_b;
    logic signed [W_IN:0] tap_sum;
    logic signed [ACC_W-1:0] sum2_next [0:G1-1];
    logic signed [ACC_W-1:0] sum3_next [0:G2-1];
    if (!rst_n) begin
      phase <= '0;
      out_data <= '0;
      out_valid <= 1'b0;
      valid_s1 <= 1'b0;
      valid_s2 <= 1'b0;
      valid_s3 <= 1'b0;
      center_s1 <= '0;
      center_s2 <= '0;
      center_s3 <= '0;
      for (int i = 0; i < PAIRS; i = i + 1) begin
        prod_s1[i] <= '0;
      end
      for (int i = 0; i < G1; i = i + 1) begin
        sum_s2[i] <= '0;
      end
      for (int i = 0; i < G2; i = i + 1) begin
        sum_s3[i] <= '0;
      end
      for (int i = 0; i < NTAPS-1; i = i + 1) begin
        shift_reg[i] <= '0;
      end
    end else if (!enable) begin
      phase <= '0;
      out_valid <= 1'b0;
      valid_s1 <= 1'b0;
      valid_s2 <= 1'b0;
      valid_s3 <= 1'b0;
    end else if (pipe_ready) begin
      valid_s1 <= do_step;
      valid_s2 <= valid_s1;
      valid_s3 <= valid_s2;
      out_valid <= valid_s3;

      for (int g = 0; g < G1; g = g + 1) begin
        sum2_next[g] = '0;
        for (int j = 0; j < 4; j = j + 1) begin
          if ((g * 4 + j) < PAIRS) begin
            sum2_next[g] = sum2_next[g] + prod_s1[g * 4 + j];
          end
        end
        sum_s2[g] <= sum2_next[g];
      end
      center_s2 <= center_s1;

      for (int g = 0; g < G2; g = g + 1) begin
        sum3_next[g] = '0;
        for (int j = 0; j < 4; j = j + 1) begin
          if ((g * 4 + j) < G1) begin
            sum3_next[g] = sum3_next[g] + sum_s2[g * 4 + j];
          end
        end
        sum_s3[g] <= sum3_next[g];
      end
      center_s3 <= center_s2;

      total = center_s3;
      for (int g = 0; g < G2; g = g + 1) begin
        total = total + sum_s3[g];
      end
      rounded = round_shift(total);
      out_data <= sat_out(rounded);

      if (do_step) begin
        for (int i = 0; i < PAIRS; i = i + 1) begin
          if (coeff(i) != '0) begin
            tap_a = (i == 0) ? step_sample : shift_reg[i-1];
            tap_b = shift_reg[NTAPS-2-i];
            tap_sum = signed'(tap_a) + signed'(tap_b);
            prod_s1[i] <= signed'(tap_sum) * signed'(coeff(i));
          end else begin
            prod_s1[i] <= '0;
          end
        end
        center_s1 <= signed'(shift_reg[(NTAPS/2)-1]) * signed'(coeff(NTAPS/2));

        for (int i = NTAPS-2; i > 0; i = i - 1) begin
          shift_reg[i] <= shift_reg[i-1];
        end
        shift_reg[0] <= step_sample;

        if (phase == PHASE_BITS'(INTERP - 1)) begin
          phase <= '0;
        end else begin
          phase <= phase + 1'b1;
        end
      end else begin
        for (int i = 0; i < PAIRS; i = i + 1) begin
          prod_s1[i] <= '0;
        end
        center_s1 <= '0;
      end
    end
  end
endmodule

`default_nettype wire
