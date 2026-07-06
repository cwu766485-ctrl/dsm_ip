`timescale 1ns/1ps
`default_nettype none

module dsm_interp2_halfband #(
  parameter int W_IN = 16,
  parameter int W_OUT = 16,
  parameter int COEFF_W = 18,
  parameter int COEFF_FRAC = 16,
  parameter int ACC_W = 48,
  parameter int NTAPS = 47
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

  logic phase_zero;
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

  function automatic signed [COEFF_W-1:0] coeff(input int idx);
    begin
      case (idx)
        0:  coeff = -18'sd145;
        1:  coeff =  18'sd0;
        2:  coeff =  18'sd193;
        3:  coeff =  18'sd0;
        4:  coeff = -18'sd323;
        5:  coeff =  18'sd0;
        6:  coeff =  18'sd555;
        7:  coeff =  18'sd0;
        8:  coeff = -18'sd914;
        9:  coeff =  18'sd0;
        10: coeff =  18'sd1434;
        11: coeff =  18'sd0;
        12: coeff = -18'sd2170;
        13: coeff =  18'sd0;
        14: coeff =  18'sd3221;
        15: coeff =  18'sd0;
        16: coeff = -18'sd4805;
        17: coeff =  18'sd0;
        18: coeff =  18'sd7491;
        19: coeff =  18'sd0;
        20: coeff = -18'sd13392;
        21: coeff =  18'sd0;
        22: coeff =  18'sd41587;
        23: coeff =  18'sd65606;
        24: coeff =  18'sd41587;
        25: coeff =  18'sd0;
        26: coeff = -18'sd13392;
        27: coeff =  18'sd0;
        28: coeff =  18'sd7491;
        29: coeff =  18'sd0;
        30: coeff = -18'sd4805;
        31: coeff =  18'sd0;
        32: coeff =  18'sd3221;
        33: coeff =  18'sd0;
        34: coeff = -18'sd2170;
        35: coeff =  18'sd0;
        36: coeff =  18'sd1434;
        37: coeff =  18'sd0;
        38: coeff = -18'sd914;
        39: coeff =  18'sd0;
        40: coeff =  18'sd555;
        41: coeff =  18'sd0;
        42: coeff = -18'sd323;
        43: coeff =  18'sd0;
        44: coeff =  18'sd193;
        45: coeff =  18'sd0;
        46: coeff = -18'sd145;
        default: coeff = '0;
      endcase
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
  wire do_step = pipe_ready && enable && (phase_zero ? in_valid : 1'b1);
  wire signed [W_IN-1:0] step_sample = phase_zero ? in_data : '0;

  assign in_ready = pipe_ready && enable && phase_zero;

  always_ff @(posedge clk) begin : p_interp
    logic signed [ACC_W-1:0] total;
    logic signed [ACC_W-1:0] rounded;
    logic signed [W_IN-1:0] tap_a;
    logic signed [W_IN-1:0] tap_b;
    logic signed [W_IN:0] tap_sum;
    logic signed [ACC_W-1:0] sum2_next [0:G1-1];
    logic signed [ACC_W-1:0] sum3_next [0:G2-1];
    if (!rst_n) begin
      phase_zero <= 1'b1;
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
      phase_zero <= 1'b1;
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
        phase_zero <= ~phase_zero;
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
