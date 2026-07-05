`timescale 1ns/1ps
`default_nettype none

module p0_ooc_lp1 #(
  parameter int W = 16,
  parameter int ACC_W = 32
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] i_data,
  input  wire logic signed [W-1:0] q_data,
  output      logic rf_valid,
  output      logic rf_bit
);
  logic i_bit, q_bit;
  logic signed [ACC_W-1:0] vi, vq;
  dsm_core #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b0)) u_i (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_data), .y_bit(i_bit), .y_signed(), .v_state(vi));
  dsm_core #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b0)) u_q (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_data), .y_bit(q_bit), .y_signed(), .v_state(vq));
  duc_fs4_merge #(.W_OUT(W)) u_duc (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_bit(i_bit), .q_bit(q_bit),
    .rf_valid(rf_valid), .rf_bit(rf_bit), .rf_signed(), .phase());
endmodule

module p0_ooc_lp2 #(
  parameter int W = 16,
  parameter int ACC_W = 20
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] i_data,
  input  wire logic signed [W-1:0] q_data,
  output      logic rf_valid,
  output      logic rf_bit
);
  logic i_bit, q_bit;
  logic signed [ACC_W-1:0] vi1, vi2, vq1, vq2;
  dsm_core_dsm2 #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b1)) u_i (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_data), .y_bit(i_bit), .y_signed(), .v1_state(vi1), .v2_state(vi2));
  dsm_core_dsm2 #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b1)) u_q (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_data), .y_bit(q_bit), .y_signed(), .v1_state(vq1), .v2_state(vq2));
  duc_fs4_merge #(.W_OUT(W)) u_duc (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_bit(i_bit), .q_bit(q_bit),
    .rf_valid(rf_valid), .rf_bit(rf_bit), .rf_signed(), .phase());
endmodule

module p0_ooc_ef1 #(
  parameter int W = 16,
  parameter int ACC_W = 28
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] i_data,
  input  wire logic signed [W-1:0] q_data,
  output      logic rf_valid,
  output      logic rf_bit
);
  logic i_bit, q_bit;
  logic signed [ACC_W-1:0] vi, vq;
  dsm_core_ef1 #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b1)) u_i (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_data), .y_bit(i_bit), .y_signed(), .v_state(vi));
  dsm_core_ef1 #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b1)) u_q (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_data), .y_bit(q_bit), .y_signed(), .v_state(vq));
  duc_fs4_merge #(.W_OUT(W)) u_duc (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_bit(i_bit), .q_bit(q_bit),
    .rf_valid(rf_valid), .rf_bit(rf_bit), .rf_signed(), .phase());
endmodule

module p0_ooc_ef2 #(
  parameter int W = 16,
  parameter int ACC_W = 28
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] i_data,
  input  wire logic signed [W-1:0] q_data,
  output      logic rf_valid,
  output      logic rf_bit
);
  logic i_bit, q_bit;
  logic signed [ACC_W-1:0] vi, vq;
  dsm_core_ef2 #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b1)) u_i (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_data), .y_bit(i_bit), .y_signed(), .v_state(vi));
  dsm_core_ef2 #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b1)) u_q (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_data), .y_bit(q_bit), .y_signed(), .v_state(vq));
  duc_fs4_merge #(.W_OUT(W)) u_duc (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_bit(i_bit), .q_bit(q_bit),
    .rf_valid(rf_valid), .rf_bit(rf_bit), .rf_signed(), .phase());
endmodule

module p0_ooc_mash11 #(
  parameter int W = 16,
  parameter int ACC_W = 18
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] i_data,
  input  wire logic signed [W-1:0] q_data,
  output      logic rf_valid,
  output      logic signed [W-1:0] rf_signed
);
  logic i_bit, q_bit, i1_bit, q1_bit, i2_bit, q2_bit;
  logic signed [2:0] yi, yq;
  logic signed [ACC_W-1:0] vi1, vi2, vq1, vq2;
  dsm_core_mash11 #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b1)) u_i (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_data),
    .y_bit(i_bit), .y1_bit(i1_bit), .y2_bit(i2_bit), .y_mash_signed(yi), .v1_state(vi1), .v2_state(vi2));
  dsm_core_mash11 #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b1)) u_q (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_data),
    .y_bit(q_bit), .y1_bit(q1_bit), .y2_bit(q2_bit), .y_mash_signed(yq), .v1_state(vq1), .v2_state(vq2));
  duc_fs4_merge_signed #(.W_IN(3), .W_OUT(W)) u_duc (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_data(yi), .q_data(yq),
    .rf_valid(rf_valid), .rf_signed(rf_signed), .phase());
endmodule

module p0_ooc_mash111 #(
  parameter int W = 16,
  parameter int ACC_W = 18
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] i_data,
  input  wire logic signed [W-1:0] q_data,
  output      logic rf_valid,
  output      logic signed [W-1:0] rf_signed
);
  logic i_bit, q_bit, i1_bit, q1_bit, i2_bit, q2_bit, i3_bit, q3_bit;
  logic signed [3:0] yi, yq;
  logic signed [ACC_W-1:0] vi1, vi2, vi3, vq1, vq2, vq3;
  dsm_core_mash111 #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b1)) u_i (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_data),
    .y_bit(i_bit), .y1_bit(i1_bit), .y2_bit(i2_bit), .y3_bit(i3_bit),
    .y_mash_signed(yi), .v1_state(vi1), .v2_state(vi2), .v3_state(vi3));
  dsm_core_mash111 #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b1)) u_q (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_data),
    .y_bit(q_bit), .y1_bit(q1_bit), .y2_bit(q2_bit), .y3_bit(q3_bit),
    .y_mash_signed(yq), .v1_state(vq1), .v2_state(vq2), .v3_state(vq3));
  duc_fs4_merge_signed #(.W_IN(4), .W_OUT(W)) u_duc (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_data(yi), .q_data(yq),
    .rf_valid(rf_valid), .rf_signed(rf_signed), .phase());
endmodule

module p0_ooc_mash22 #(
  parameter int W = 16,
  parameter int ACC_W = 18
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] i_data,
  input  wire logic signed [W-1:0] q_data,
  output      logic rf_valid,
  output      logic signed [W-1:0] rf_signed
);
  logic i_bit, q_bit, i1_bit, q1_bit, i2_bit, q2_bit;
  logic signed [3:0] yi, yq;
  logic signed [ACC_W-1:0] vi1, vi2, vq1, vq2;
  dsm_core_mash22 #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b1)) u_i (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_data),
    .y_bit(i_bit), .y1_bit(i1_bit), .y2_bit(i2_bit), .y_mash_signed(yi), .v1_state(vi1), .v2_state(vi2));
  dsm_core_mash22 #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b1)) u_q (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_data),
    .y_bit(q_bit), .y1_bit(q1_bit), .y2_bit(q2_bit), .y_mash_signed(yq), .v1_state(vq1), .v2_state(vq2));
  duc_fs4_merge_signed #(.W_IN(4), .W_OUT(W)) u_duc (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_data(yi), .q_data(yq),
    .rf_valid(rf_valid), .rf_signed(rf_signed), .phase());
endmodule

module p0_ooc_mb_lp1 #(
  parameter int W = 16,
  parameter int ACC_W = 16,
  parameter int OUT_W = 8,
  parameter int Q_BITS = 4
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] i_data,
  input  wire logic signed [W-1:0] q_data,
  output      logic rf_valid,
  output      logic signed [W-1:0] rf_signed
);
  logic i_bit, q_bit;
  logic signed [OUT_W-1:0] yi, yq;
  dsm_core_multibit_lp1 #(.W_IN(W), .ACC_W(ACC_W), .OUT_W(OUT_W), .Q_BITS(Q_BITS)) u_i (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_data), .y_bit(i_bit), .y_code(yi), .v1_state(), .v2_state());
  dsm_core_multibit_lp1 #(.W_IN(W), .ACC_W(ACC_W), .OUT_W(OUT_W), .Q_BITS(Q_BITS)) u_q (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_data), .y_bit(q_bit), .y_code(yq), .v1_state(), .v2_state());
  duc_fs4_merge_signed #(.W_IN(OUT_W), .W_OUT(W)) u_duc (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_data(yi), .q_data(yq),
    .rf_valid(rf_valid), .rf_signed(rf_signed), .phase());
endmodule

module p0_ooc_mb_lp2 #(
  parameter int W = 16,
  parameter int ACC_W = 16,
  parameter int OUT_W = 8,
  parameter int Q_BITS = 4
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] i_data,
  input  wire logic signed [W-1:0] q_data,
  output      logic rf_valid,
  output      logic signed [W-1:0] rf_signed
);
  logic i_bit, q_bit;
  logic signed [OUT_W-1:0] yi, yq;
  dsm_core_multibit_lp2 #(.W_IN(W), .ACC_W(ACC_W), .OUT_W(OUT_W), .Q_BITS(Q_BITS)) u_i (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_data), .y_bit(i_bit), .y_code(yi), .v1_state(), .v2_state());
  dsm_core_multibit_lp2 #(.W_IN(W), .ACC_W(ACC_W), .OUT_W(OUT_W), .Q_BITS(Q_BITS)) u_q (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_data), .y_bit(q_bit), .y_code(yq), .v1_state(), .v2_state());
  duc_fs4_merge_signed #(.W_IN(OUT_W), .W_OUT(W)) u_duc (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_data(yi), .q_data(yq),
    .rf_valid(rf_valid), .rf_signed(rf_signed), .phase());
endmodule

module p0_ooc_mb_ef1 #(
  parameter int W = 16,
  parameter int ACC_W = 16,
  parameter int OUT_W = 8,
  parameter int Q_BITS = 4
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] i_data,
  input  wire logic signed [W-1:0] q_data,
  output      logic rf_valid,
  output      logic signed [W-1:0] rf_signed
);
  logic i_bit, q_bit;
  logic signed [OUT_W-1:0] yi, yq;
  dsm_core_multibit_ef1 #(.W_IN(W), .ACC_W(ACC_W), .OUT_W(OUT_W), .Q_BITS(Q_BITS)) u_i (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_data), .y_bit(i_bit), .y_code(yi), .v1_state(), .v2_state());
  dsm_core_multibit_ef1 #(.W_IN(W), .ACC_W(ACC_W), .OUT_W(OUT_W), .Q_BITS(Q_BITS)) u_q (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_data), .y_bit(q_bit), .y_code(yq), .v1_state(), .v2_state());
  duc_fs4_merge_signed #(.W_IN(OUT_W), .W_OUT(W)) u_duc (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_data(yi), .q_data(yq),
    .rf_valid(rf_valid), .rf_signed(rf_signed), .phase());
endmodule

module p0_ooc_mb_ef2 #(
  parameter int W = 16,
  parameter int ACC_W = 16,
  parameter int OUT_W = 8,
  parameter int Q_BITS = 4
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] i_data,
  input  wire logic signed [W-1:0] q_data,
  output      logic rf_valid,
  output      logic signed [W-1:0] rf_signed
);
  logic i_bit, q_bit;
  logic signed [OUT_W-1:0] yi, yq;
  dsm_core_multibit_ef2 #(.W_IN(W), .ACC_W(ACC_W), .OUT_W(OUT_W), .Q_BITS(Q_BITS)) u_i (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_data), .y_bit(i_bit), .y_code(yi), .v1_state(), .v2_state());
  dsm_core_multibit_ef2 #(.W_IN(W), .ACC_W(ACC_W), .OUT_W(OUT_W), .Q_BITS(Q_BITS)) u_q (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_data), .y_bit(q_bit), .y_code(yq), .v1_state(), .v2_state());
  duc_fs4_merge_signed #(.W_IN(OUT_W), .W_OUT(W)) u_duc (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_data(yi), .q_data(yq),
    .rf_valid(rf_valid), .rf_signed(rf_signed), .phase());
endmodule

module p0_ooc_mb_mash11 #(
  parameter int W = 16,
  parameter int ACC_W = 16,
  parameter int OUT_W = 8,
  parameter int Q_BITS = 4
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] i_data,
  input  wire logic signed [W-1:0] q_data,
  output      logic rf_valid,
  output      logic signed [W-1:0] rf_signed
);
  logic i_bit, q_bit;
  logic signed [OUT_W-1:0] yi, yq;
  dsm_core_multibit_mash11 #(.W_IN(W), .ACC_W(ACC_W), .OUT_W(OUT_W), .Q_BITS(Q_BITS)) u_i (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_data), .y_bit(i_bit), .y_code(yi), .v1_state(), .v2_state());
  dsm_core_multibit_mash11 #(.W_IN(W), .ACC_W(ACC_W), .OUT_W(OUT_W), .Q_BITS(Q_BITS)) u_q (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_data), .y_bit(q_bit), .y_code(yq), .v1_state(), .v2_state());
  duc_fs4_merge_signed #(.W_IN(OUT_W), .W_OUT(W)) u_duc (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_data(yi), .q_data(yq),
    .rf_valid(rf_valid), .rf_signed(rf_signed), .phase());
endmodule

module p0_ooc_mb_mash111 #(
  parameter int W = 16,
  parameter int ACC_W = 16,
  parameter int OUT_W = 8,
  parameter int Q_BITS = 4
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] i_data,
  input  wire logic signed [W-1:0] q_data,
  output      logic rf_valid,
  output      logic signed [W-1:0] rf_signed
);
  logic i_bit, q_bit;
  logic signed [OUT_W-1:0] yi, yq;
  dsm_core_multibit_mash111 #(.W_IN(W), .ACC_W(ACC_W), .OUT_W(OUT_W), .Q_BITS(Q_BITS)) u_i (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_data), .y_bit(i_bit), .y_code(yi), .v1_state(), .v2_state());
  dsm_core_multibit_mash111 #(.W_IN(W), .ACC_W(ACC_W), .OUT_W(OUT_W), .Q_BITS(Q_BITS)) u_q (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_data), .y_bit(q_bit), .y_code(yq), .v1_state(), .v2_state());
  duc_fs4_merge_signed #(.W_IN(OUT_W), .W_OUT(W)) u_duc (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_data(yi), .q_data(yq),
    .rf_valid(rf_valid), .rf_signed(rf_signed), .phase());
endmodule

module p0_ooc_mb_mash22 #(
  parameter int W = 16,
  parameter int ACC_W = 16,
  parameter int OUT_W = 8,
  parameter int Q_BITS = 4
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] i_data,
  input  wire logic signed [W-1:0] q_data,
  output      logic rf_valid,
  output      logic signed [W-1:0] rf_signed
);
  logic i_bit, q_bit;
  logic signed [OUT_W-1:0] yi, yq;
  dsm_core_multibit_mash22 #(.W_IN(W), .ACC_W(ACC_W), .OUT_W(OUT_W), .Q_BITS(Q_BITS)) u_i (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_data), .y_bit(i_bit), .y_code(yi), .v1_state(), .v2_state());
  dsm_core_multibit_mash22 #(.W_IN(W), .ACC_W(ACC_W), .OUT_W(OUT_W), .Q_BITS(Q_BITS)) u_q (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_data), .y_bit(q_bit), .y_code(yq), .v1_state(), .v2_state());
  duc_fs4_merge_signed #(.W_IN(OUT_W), .W_OUT(W)) u_duc (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_data(yi), .q_data(yq),
    .rf_valid(rf_valid), .rf_signed(rf_signed), .phase());
endmodule

`default_nettype wire
