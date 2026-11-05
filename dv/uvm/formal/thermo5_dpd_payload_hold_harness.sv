`timescale 1ns/1ps
`default_nettype none

// Full-product-shape hold proof for the Thermo5 16-lane one-tap DPD.
// Coefficients, active tap count, metadata, and sample payload are unconstrained
// inputs. Only the parameterized maximum tap count is fixed to the product SKU.
module thermo5_dpd_payload_hold_harness (
  input logic clk,
  input logic rst_n,
  input logic in_valid,
  input logic out_ready,
  input logic [2:0] active_taps,
  input logic signed [15:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im,
  input logic [1:0] in_meta,
  input logic signed [255:0] in_i_vec,
  input logic signed [255:0] in_q_vec
);
  logic in_ready, out_valid;
  logic [1:0] out_meta;
  logic signed [255:0] out_i_vec, out_q_vec;

  dpd_vector16_memory_poly #(
    .W(16), .LANES(16), .COEFF_W(16), .COEFF_FRAC(14), .MAX_TAPS(1)
  ) dut (
    .clk(clk), .rst_n(rst_n), .active_taps(active_taps),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .in_valid(in_valid), .in_ready(in_ready),
    .in_meta(in_meta), .in_i_vec(in_i_vec), .in_q_vec(in_q_vec),
    .out_valid(out_valid), .out_ready(out_ready), .out_meta(out_meta),
    .out_i_vec(out_i_vec), .out_q_vec(out_q_vec)
  );

  default clocking cb @(posedge clk); endclocking

  // The 512-bit payload assertion is split into 16 lane properties to avoid
  // one oversized proof cone. Lane-valid lockstep plus these 16 payload
  // properties and the metadata property are equivalent to whole-word hold.
  a_meta_hold:
    assert property (disable iff (!rst_n)
      out_valid && !out_ready |=> out_valid && $stable(out_meta));

  for (genvar lane = 0; lane < 16; lane++) begin : g_lane_hold
    a_lane_valid_lockstep:
      assert property (disable iff (!rst_n)
        dut.lane_out_valid[lane] == out_valid);
    a_lane_payload_hold:
      assert property (disable iff (!rst_n)
        out_valid && !out_ready |=> dut.lane_out_valid[lane] &&
        $stable({out_i_vec[lane*16 +: 16], out_q_vec[lane*16 +: 16]}));
  end

  c_input_accept: cover property (disable iff (!rst_n) in_valid && in_ready);
  c_output_stall: cover property (disable iff (!rst_n) out_valid && !out_ready);
  c_stall_release: cover property (disable iff (!rst_n)
    out_valid && !out_ready ##1 out_valid && out_ready);
endmodule

`default_nettype wire
