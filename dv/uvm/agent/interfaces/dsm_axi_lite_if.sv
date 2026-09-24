`timescale 1ns/1ps

interface dsm_axi_lite_if #(parameter int ADDR_W = 9, parameter int DATA_W = 32)
  (input logic aclk, input logic aresetn);
  logic [ADDR_W-1:0] awaddr;
  logic awvalid;
  logic awready;
  logic [DATA_W-1:0] wdata;
  logic [(DATA_W/8)-1:0] wstrb;
  logic wvalid;
  logic wready;
  logic [1:0] bresp;
  logic bvalid;
  logic bready;
  logic [ADDR_W-1:0] araddr;
  logic arvalid;
  logic arready;
  logic [DATA_W-1:0] rdata;
  logic [1:0] rresp;
  logic rvalid;
  logic rready;
endinterface
