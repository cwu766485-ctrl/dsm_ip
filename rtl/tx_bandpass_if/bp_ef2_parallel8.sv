//------------------------------------------------------------------------------
// Eight-sample time-unrolled, one-bit BP EFDSM2.
//
// Each accepted vector contains eight consecutive real IF samples. The
// samples are evaluated in temporal order inside one clock period; therefore
// the state entering sample k+1 is the state produced by sample k. The eight
// output bits are a parallel representation of the same scalar bitstream, not
// eight independent DSM loops.
//
// This is an architecture prototype for bit-true and PPA experiments. It is
// intentionally fixed to the Fs/4 BP coefficients B1=0 and B2=-1.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module bp_ef2_parallel8 #(
  parameter int W_IN = 16,
  parameter int ACC_W = 28,
  parameter bit SATURATE = 1'b1
) (
  input  wire logic                         clk,
  input  wire logic                         rst_n,
  input  wire logic                         enable,
  input  wire logic [8*W_IN-1:0]            x_vec,
  output logic [7:0]                        y_vec,
  output logic signed [8*W_IN-1:0]          y_signed_vec,
  output logic                              out_valid,
  output logic signed [ACC_W-1:0]           v_state
);

  localparam int SUM_W = ACC_W + 2;
  localparam logic signed [W_IN-1:0] Y_POS = {1'b0, {(W_IN-1){1'b1}}};
  localparam logic signed [W_IN-1:0] Y_NEG = -Y_POS;
  localparam logic signed [ACC_W-1:0] V_MAX = {1'b0, {(ACC_W-1){1'b1}}};
  localparam logic signed [ACC_W-1:0] V_MIN = {1'b1, {(ACC_W-1){1'b0}}};

  logic signed [ACC_W-1:0] e1_state;
  logic signed [ACC_W-1:0] e2_state;
  logic signed [ACC_W-1:0] e1_work [0:7];
  logic signed [ACC_W-1:0] e2_work [0:7];
  logic signed [ACC_W-1:0] y_work [0:7];
  logic signed [ACC_W-1:0] e_work [0:7];
  logic signed [SUM_W-1:0] y_sum;
  logic signed [ACC_W-1:0] x_ext;
  logic signed [ACC_W-1:0] q_ext;
  logic [7:0] y_vec_c;
  logic signed [8*W_IN-1:0] y_signed_vec_c;
  logic signed [ACC_W-1:0] v_state_c;

  function automatic logic signed [ACC_W-1:0] sat_acc(
    input logic signed [SUM_W-1:0] value
  );
    begin
      if (!SATURATE) begin
        sat_acc = value[ACC_W-1:0];
      end else if (value > $signed({{(SUM_W-ACC_W){V_MAX[ACC_W-1]}}, V_MAX})) begin
        sat_acc = V_MAX;
      end else if (value < $signed({{(SUM_W-ACC_W){V_MIN[ACC_W-1]}}, V_MIN})) begin
        sat_acc = V_MIN;
      end else begin
        sat_acc = value[ACC_W-1:0];
      end
    end
  endfunction

  integer k;
  always_comb begin
    y_vec_c = '0;
    y_signed_vec_c = '0;
    // Work arrays model the scalar EFDSM2 recurrence in temporal order.
    e1_work[0] = e1_state;
    e2_work[0] = e2_state;
    for (k = 0; k < 8; k = k + 1) begin
      x_ext = {{(ACC_W-W_IN){x_vec[k*W_IN+W_IN-1]}}, x_vec[k*W_IN +: W_IN]};
      y_sum = $signed({{(SUM_W-ACC_W){x_ext[ACC_W-1]}}, x_ext}) -
              $signed({{(SUM_W-ACC_W){e2_work[k][ACC_W-1]}}, e2_work[k]});
      y_work[k] = sat_acc(y_sum);
      y_vec_c[k] = (y_work[k] >= 0);
      y_signed_vec_c[k*W_IN +: W_IN] = y_vec_c[k] ? Y_POS : Y_NEG;
      q_ext = {{(ACC_W-W_IN){y_signed_vec_c[k*W_IN+W_IN-1]}},
               y_signed_vec_c[k*W_IN +: W_IN]};
      e_work[k] = y_work[k] - q_ext;
      if (k < 7) begin
        e1_work[k+1] = e_work[k];
        e2_work[k+1] = e1_work[k];
      end
    end
    v_state_c = y_work[7];
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      e1_state <= '0;
      e2_state <= '0;
      y_vec <= 8'hff;
      y_signed_vec <= {8{Y_POS}};
      v_state <= '0;
      out_valid <= 1'b0;
    end else if (enable) begin
      y_vec <= y_vec_c;
      y_signed_vec <= y_signed_vec_c;
      v_state <= v_state_c;
      e1_state <= e_work[7];
      e2_state <= e1_work[7];
      out_valid <= 1'b1;
    end else begin
      out_valid <= 1'b0;
    end
  end

endmodule

`default_nettype wire
