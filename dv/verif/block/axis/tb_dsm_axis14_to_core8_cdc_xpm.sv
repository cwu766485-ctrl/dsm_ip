`timescale 1ns/1ps
`default_nettype none

module tb_dsm_axis14_to_core8_cdc_xpm;
  tb_dsm_axis14_to_core8_cdc #(.USE_XPM_FIFO(1'b1)) u_test();
endmodule

`default_nettype wire
