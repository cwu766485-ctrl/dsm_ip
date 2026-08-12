`timescale 1ns/1ps

interface dsm_axis_if #(parameter int DATA_W = 32, parameter int USER_W = 1)
  (input logic aclk, input logic aresetn);
  logic [DATA_W-1:0] tdata;
  logic tlast;
  logic [USER_W-1:0] tuser;
  logic tvalid;
  logic tready;
endinterface
