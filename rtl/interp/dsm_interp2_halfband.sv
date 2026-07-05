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

  wire can_step = (!out_valid) || out_ready;
  wire do_step = can_step && enable && (phase_zero ? in_valid : 1'b1);
  wire signed [W_IN-1:0] step_sample = phase_zero ? in_data : '0;

  assign in_ready = can_step && enable && phase_zero;

  always_ff @(posedge clk) begin : p_interp
    logic signed [ACC_W-1:0] acc;
    logic signed [ACC_W-1:0] rounded;
    logic signed [W_IN-1:0] tap_a;
    logic signed [W_IN-1:0] tap_b;
    logic signed [W_IN:0] tap_sum;
    if (!rst_n) begin
      phase_zero <= 1'b1;
      out_data <= '0;
      out_valid <= 1'b0;
      for (int i = 0; i < NTAPS-1; i = i + 1) begin
        shift_reg[i] <= '0;
      end
    end else if (!enable) begin
      phase_zero <= 1'b1;
      out_valid <= 1'b0;
    end else begin
      if (out_valid && out_ready && !do_step) begin
        out_valid <= 1'b0;
      end

      if (do_step) begin
        acc = '0;
        for (int i = 0; i < (NTAPS/2); i = i + 1) begin
          if (coeff(i) != '0) begin
            tap_a = (i == 0) ? step_sample : shift_reg[i-1];
            tap_b = shift_reg[NTAPS-2-i];
            tap_sum = signed'(tap_a) + signed'(tap_b);
            acc = acc + signed'(tap_sum) * signed'(coeff(i));
          end
        end
        acc = acc + signed'(shift_reg[(NTAPS/2)-1]) * signed'(coeff(NTAPS/2));

        rounded = round_shift(acc);
        out_data <= sat_out(rounded);
        out_valid <= 1'b1;

        for (int i = NTAPS-2; i > 0; i = i - 1) begin
          shift_reg[i] <= shift_reg[i-1];
        end
        shift_reg[0] <= step_sample;
        phase_zero <= ~phase_zero;
      end
    end
  end
endmodule

`default_nettype wire
