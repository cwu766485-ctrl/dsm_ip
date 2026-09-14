// Compact arithmetic variant of the exact two-sample look-ahead temporal64
// candidate. This combines the proven ACC_W=17 bound with the two-sample
// piecewise-affine state transfer. It is an experiment, not the frozen top.

`timescale 1ns/1ps
`default_nettype none

module bp_ef2_polyphase2_lookahead2_acc17 #(
  parameter int W_IN = 16,
  parameter bit SATURATE = 1'b1
) (
  input wire logic clk,
  input wire logic rst_n,
  input wire logic enable,
  input wire logic [64*W_IN-1:0] x_vec,
  output logic [63:0] y_vec,
  output logic signed [64*W_IN-1:0] y_signed_vec,
  output logic out_valid,
  output logic signed [16:0] v_state
);
  localparam int ACC_W = 17;
  localparam int GROUPS = 16;
  localparam int GROUP_W = 2*W_IN;
  localparam logic signed [W_IN-1:0] Y_POS = {1'b0, {(W_IN-1){1'b1}}};

  logic signed [ACC_W-1:0] even_state [0:GROUPS];
  logic signed [ACC_W-1:0] odd_state [0:GROUPS];
  logic signed [GROUP_W-1:0] even_x [0:GROUPS-1];
  logic signed [GROUP_W-1:0] odd_x [0:GROUPS-1];
  logic [1:0] even_y [0:GROUPS-1];
  logic [1:0] odd_y [0:GROUPS-1];
  logic signed [GROUP_W-1:0] even_signed [0:GROUPS-1];
  logic signed [GROUP_W-1:0] odd_signed [0:GROUPS-1];
  logic signed [ACC_W-1:0] even_v [0:GROUPS-1];
  logic signed [ACC_W-1:0] odd_v [0:GROUPS-1];
  logic signed [ACC_W-1:0] even_e [0:GROUPS-1];
  logic signed [ACC_W-1:0] odd_e [0:GROUPS-1];
  logic [63:0] y_vec_c;
  logic signed [64*W_IN-1:0] y_signed_vec_c;
  logic signed [ACC_W-1:0] v_state_c;
  logic signed [ACC_W-1:0] even_context;
  logic signed [ACC_W-1:0] odd_context;
  integer g;
  integer k;

  assign even_state[0] = even_context;
  assign odd_state[0] = odd_context;

  genvar gi;
  generate
    for (gi = 0; gi < GROUPS; gi = gi + 1) begin : gen_lookahead
      assign even_x[gi][0*W_IN +: W_IN] = x_vec[(4*gi+0)*W_IN +: W_IN];
      assign even_x[gi][1*W_IN +: W_IN] = x_vec[(4*gi+2)*W_IN +: W_IN];
      assign odd_x[gi][0*W_IN +: W_IN] = x_vec[(4*gi+1)*W_IN +: W_IN];
      assign odd_x[gi][1*W_IN +: W_IN] = x_vec[(4*gi+3)*W_IN +: W_IN];

      bp_ef2_lookahead2_comb #(
        .W_IN(W_IN), .ACC_W(ACC_W), .SATURATE(SATURATE)
      ) u_even (
        .x_vec(even_x[gi]), .e_in(even_state[gi]),
        .y_vec(even_y[gi]), .y_signed_vec(even_signed[gi]),
        .e_out(even_e[gi]), .v_state(even_v[gi])
      );
      bp_ef2_lookahead2_comb #(
        .W_IN(W_IN), .ACC_W(ACC_W), .SATURATE(SATURATE)
      ) u_odd (
        .x_vec(odd_x[gi]), .e_in(odd_state[gi]),
        .y_vec(odd_y[gi]), .y_signed_vec(odd_signed[gi]),
        .e_out(odd_e[gi]), .v_state(odd_v[gi])
      );
      if (gi < GROUPS-1) begin : gen_next_state
        assign even_state[gi+1] = even_e[gi];
        assign odd_state[gi+1] = odd_e[gi];
      end
    end
    assign even_state[GROUPS] = even_e[GROUPS-1];
    assign odd_state[GROUPS] = odd_e[GROUPS-1];
  endgenerate

  always_comb begin
    y_vec_c = '0;
    y_signed_vec_c = '0;
    for (g = 0; g < GROUPS; g = g + 1) begin
      for (k = 0; k < 2; k = k + 1) begin
        y_vec_c[4*g+2*k] = even_y[g][k];
        y_vec_c[4*g+2*k+1] = odd_y[g][k];
        y_signed_vec_c[(4*g+2*k)*W_IN +: W_IN] =
          even_signed[g][k*W_IN +: W_IN];
        y_signed_vec_c[(4*g+2*k+1)*W_IN +: W_IN] =
          odd_signed[g][k*W_IN +: W_IN];
      end
    end
    v_state_c = odd_v[GROUPS-1];
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      even_context <= '0;
      odd_context <= '0;
      y_vec <= {64{1'b1}};
      y_signed_vec <= {64{Y_POS}};
      v_state <= '0;
      out_valid <= 1'b0;
    end else if (enable) begin
      even_context <= even_state[GROUPS];
      odd_context <= odd_state[GROUPS];
      y_vec <= y_vec_c;
      y_signed_vec <= y_signed_vec_c;
      v_state <= v_state_c;
      out_valid <= 1'b1;
    end else begin
      out_valid <= 1'b0;
    end
  end
endmodule

`default_nettype wire
