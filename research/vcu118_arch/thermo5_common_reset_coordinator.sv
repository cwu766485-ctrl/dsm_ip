`timescale 1ns/1ps
`default_nettype none
// Research-only parent integration candidate. The single asynchronous input is
// a reset request for the complete transmitter epoch, not a per-domain reset.
// Parent must use these outputs for all three transmitter domains and discard
// in-flight traffic on assertion. Clocking, reset distribution and RDC remain
// subject to system implementation review.
module thermo5_common_reset_coordinator (
  input wire logic common_arst_n,
  input wire logic s_axil_aclk,
  input wire logic s_axis_aclk,
  input wire logic core_clk,
  output wire logic s_axil_aresetn,
  output wire logic s_axis_aresetn,
  output wire logic core_aresetn
);
  dsm_reset_sync axil_reset (.clk(s_axil_aclk),.arst_n(common_arst_n),.srst_n(s_axil_aresetn));
  dsm_reset_sync axis_reset (.clk(s_axis_aclk),.arst_n(common_arst_n),.srst_n(s_axis_aresetn));
  dsm_reset_sync core_reset (.clk(core_clk),.arst_n(common_arst_n),.srst_n(core_aresetn));
endmodule
`default_nettype wire
