`timescale 1ns/1ps

module dsm_axis_protocol_sva #(
  parameter int DATA_W = 32,
  parameter int USER_W = 1
) (
  input logic aclk,
  input logic aresetn,
  input logic [DATA_W-1:0] tx_tdata,
  input logic [USER_W-1:0] tx_tuser,
  input logic tx_tvalid,
  input logic tx_tready,
  input logic tx_tlast
);
  default clocking cb @(posedge aclk); endclocking
  property p_axis_stable_under_stall;
    disable iff (!aresetn)
    tx_tvalid && !tx_tready |=> tx_tvalid && $stable({tx_tdata, tx_tuser, tx_tlast});
  endproperty
  a_axis_stable_under_stall: assert property (p_axis_stable_under_stall);
endmodule

module dsm_axi_lite_protocol_sva #(
  parameter int ADDR_W = 9,
  parameter int DATA_W = 32
) (
  input logic aclk,
  input logic aresetn,
  input logic [ADDR_W-1:0] awaddr,
  input logic awvalid,
  input logic awready,
  input logic [DATA_W-1:0] wdata,
  input logic [(DATA_W/8)-1:0] wstrb,
  input logic wvalid,
  input logic wready,
  input logic [1:0] bresp,
  input logic bvalid,
  input logic bready,
  input logic [ADDR_W-1:0] araddr,
  input logic arvalid,
  input logic arready,
  input logic [DATA_W-1:0] rdata,
  input logic [1:0] rresp,
  input logic rvalid,
  input logic rready
);
  default clocking cb @(posedge aclk); endclocking
  a_aw_stable: assert property (
    disable iff (!aresetn) awvalid && !awready |=> awvalid && $stable(awaddr));
  a_w_stable: assert property (
    disable iff (!aresetn) wvalid && !wready |=> wvalid && $stable({wdata, wstrb}));
  a_b_stable: assert property (
    disable iff (!aresetn) bvalid && !bready |=> bvalid && $stable(bresp));
  a_ar_stable: assert property (
    disable iff (!aresetn) arvalid && !arready |=> arvalid && $stable(araddr));
  a_r_stable: assert property (
    disable iff (!aresetn) rvalid && !rready |=> rvalid && $stable({rdata, rresp}));
endmodule

module dsm_rf_protocol_sva (
  input logic aclk,
  input logic aresetn,
  input logic rf_valid,
  input logic rf_bit,
  input logic signed [15:0] rf_signed
);
  default clocking cb @(posedge aclk); endclocking
  property p_rf_encoding;
    disable iff (!aresetn)
    rf_valid |-> (rf_signed == (rf_bit ? 16'sh7fff : -16'sh7fff));
  endproperty
  a_rf_encoding: assert property (p_rf_encoding);
endmodule
