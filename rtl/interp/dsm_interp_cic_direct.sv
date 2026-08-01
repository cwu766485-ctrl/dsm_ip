`timescale 1ns/1ps
`default_nettype none

// Direct interpolating CIC.  A four-stage, x8 CIC has the same ideal
// impulse response as COEFF_SET=2 in dsm_interp_fir_fixed: ones(8)^4 / 8^3.
// The output is therefore scaled by RATE^(ORDER-1), preserving the x8 DC
// interpolation gain used by the shipped I0 frontend.
module dsm_interp_cic_direct #(
  parameter int W_IN = 16,
  parameter int W_OUT = 16,
  parameter int RATE = 8,
  parameter int ORDER = 4,
  parameter int ACC_W = 48
) (
  input  wire                     clk,
  input  wire                     rst_n,
  input  wire                     enable,
  input  wire signed [W_IN-1:0]   in_data,
  input  wire                     in_valid,
  output wire                     in_ready,
  output logic signed [W_OUT-1:0] out_data,
  output logic                    out_valid,
  input  wire                     out_ready
);

  localparam int PHASE_W = (RATE <= 1) ? 1 : $clog2(RATE);
  localparam int SCALE_SHIFT = $clog2(RATE) * (ORDER - 1);

  logic [PHASE_W-1:0] phase;
  logic signed [ACC_W-1:0] comb_delay [0:ORDER-1];
  logic signed [ACC_W-1:0] integrator [0:ORDER-1];

  function automatic signed [ACC_W-1:0] round_shift(
    input signed [ACC_W-1:0] value
  );
    logic signed [ACC_W-1:0] bias;
    begin
      bias = signed'(1) <<< (SCALE_SHIFT - 1);
      if (value >= 0) begin
        round_shift = (value + bias) >>> SCALE_SHIFT;
      end else begin
        round_shift = -(((-value) + bias) >>> SCALE_SHIFT);
      end
    end
  endfunction

  function automatic signed [W_OUT-1:0] sat_out(
    input signed [ACC_W-1:0] value
  );
    logic signed [ACC_W-1:0] maxv;
    logic signed [ACC_W-1:0] minv;
    begin
      maxv = (signed'(1) <<< (W_OUT - 1)) - 1;
      minv = -(signed'(1) <<< (W_OUT - 1));
      if (value > maxv) begin
        sat_out = signed'(maxv[W_OUT-1:0]);
      end else if (value < minv) begin
        sat_out = signed'(minv[W_OUT-1:0]);
      end else begin
        sat_out = signed'(value[W_OUT-1:0]);
      end
    end
  endfunction

  wire pipe_ready = !out_valid || out_ready;
  wire phase_zero = (phase == '0);
  wire do_step = pipe_ready && enable && (phase_zero ? in_valid : 1'b1);

  assign in_ready = pipe_ready && enable && phase_zero;

  always_ff @(posedge clk) begin : p_cic
    logic signed [ACC_W-1:0] comb_value;
    logic signed [ACC_W-1:0] integ_value;
    logic signed [ACC_W-1:0] scaled_value;
    if (!rst_n) begin
      phase <= '0;
      out_data <= '0;
      out_valid <= 1'b0;
      for (int s = 0; s < ORDER; s = s + 1) begin
        comb_delay[s] <= '0;
        integrator[s] <= '0;
      end
    end else if (!enable) begin
      phase <= '0;
      out_valid <= 1'b0;
      for (int s = 0; s < ORDER; s = s + 1) begin
        comb_delay[s] <= '0;
        integrator[s] <= '0;
      end
    end else if (pipe_ready) begin
      out_valid <= do_step;
      if (do_step) begin
        comb_value = '0;
        if (phase_zero) begin
          comb_value = {{(ACC_W-W_IN){in_data[W_IN-1]}}, in_data};
          for (int s = 0; s < ORDER; s = s + 1) begin
            integ_value = comb_value - comb_delay[s];
            comb_delay[s] <= comb_value;
            comb_value = integ_value;
          end
        end

        integ_value = comb_value;
        for (int s = 0; s < ORDER; s = s + 1) begin
          integ_value = integrator[s] + integ_value;
          integrator[s] <= integ_value;
        end
        scaled_value = round_shift(integ_value);
        out_data <= sat_out(scaled_value);
        phase <= (phase == RATE-1) ? '0 : phase + 1'b1;
      end
    end
  end
endmodule

`default_nettype wire
