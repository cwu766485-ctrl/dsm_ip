//------------------------------------------------------------------------------
// 32-bit / 218.75-MHz raw GT playback integration boundary.
// It represents 7 Gb/s raw output and 7 GS/s one-bit samples before the BPF.
//------------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module gt_tx_raw_playback32 #(
  parameter int MEM_DEPTH = 1024,
  parameter string MEM_INIT_FILE = ""
) (
  input  wire logic        clk,
  input  wire logic        rst_n,
  input  wire logic        start,
  input  wire logic        repeat_enable,
  output wire logic        gt_valid,
  input  wire logic        gt_ready,
  output wire logic [31:0] gt_data,
  output wire logic        active,
  output wire logic        done
);
  wire src_valid;
  wire src_ready;
  wire [31:0] src_data;

  gt_tx_raw_playback #(
    .DATA_W(32), .MEM_DEPTH(MEM_DEPTH), .MEM_INIT_FILE(MEM_INIT_FILE)
  ) u_playback (
    .clk(clk), .rst_n(rst_n), .start(start), .repeat_enable(repeat_enable),
    .src_valid(src_valid), .src_ready(src_ready), .src_data(src_data),
    .active(active), .done(done)
  );

  gt_tx_raw64_boundary #(.DATA_W(32)) u_raw_boundary (
    .clk(clk), .rst_n(rst_n), .in_valid(src_valid), .in_ready(src_ready),
    .in_data(src_data), .gt_valid(gt_valid), .gt_ready(gt_ready),
    .gt_data(gt_data)
  );
endmodule

`default_nettype wire
