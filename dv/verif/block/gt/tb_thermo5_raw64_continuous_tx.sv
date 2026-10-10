`timescale 1ns/1ps
`default_nettype none

module tb_thermo5_raw64_continuous_tx;
  logic clk = 1'b0;
  always #5 clk = ~clk;
  logic rst_n = 1'b0, link_ready = 1'b0, run_request = 1'b0;
  logic [3:0] pa_valid = '0;
  logic [63:0] pa_data [0:3];
  wire logic [3:0] pa_ready;
  wire logic [255:0] gt_txdata;
  wire logic pa_enable, stream_fault;
  localparam logic [255:0] IDLE = {4{64'hAAAA_AAAA_AAAA_AAAA}};

  thermo5_raw64_continuous_tx dut (.*);

  task automatic tick;
    @(posedge clk); #1;
  endtask
  task automatic check(input logic [255:0] exp_data,
                       input logic exp_enable, input logic exp_fault);
    if (gt_txdata !== exp_data || pa_enable !== exp_enable ||
        stream_fault !== exp_fault || pa_ready !== 4'hf)
      $fatal(1, "raw64 boundary mismatch data=%h enable=%b fault=%b ready=%h",
             gt_txdata, pa_enable, stream_fault, pa_ready);
  endtask

  initial begin
    pa_data[0] = 64'h0123_4567_89AB_CDEF;
    pa_data[1] = 64'h1023_4567_89AB_CDEF;
    pa_data[2] = 64'h2023_4567_89AB_CDEF;
    pa_data[3] = 64'h3023_4567_89AB_CDEF;
    tick(); check(IDLE, 1'b0, 1'b0);
    @(negedge clk); rst_n = 1'b1; link_ready = 1'b1; run_request = 1'b1;
    tick(); check(IDLE, 1'b0, 1'b0); // prefill is not a fault
    @(negedge clk); pa_valid = 4'hf;
    tick(); check({pa_data[3], pa_data[2], pa_data[1], pa_data[0]}, 1'b1, 1'b0);
    @(negedge clk); pa_valid = '0;
    tick(); check(IDLE, 1'b0, 1'b1); // missing word after streaming starts
    @(negedge clk); pa_valid = 4'hf;
    tick(); check(IDLE, 1'b0, 1'b1); // sticky until common reset
    @(negedge clk); rst_n = 1'b0;
    tick(); check(IDLE, 1'b0, 1'b0);
    @(negedge clk); rst_n = 1'b1; pa_valid = 4'b0111;
    tick(); check(IDLE, 1'b0, 1'b1); // plane disagreement
    @(negedge clk); rst_n = 1'b0; pa_valid = '0;
    tick(); check(IDLE, 1'b0, 1'b0);
    @(negedge clk); rst_n = 1'b1; pa_valid = 4'hf; run_request = 1'b0;
    tick(); check(IDLE, 1'b0, 1'b1); // no silent payload loss when stopped
    @(negedge clk); rst_n = 1'b0; pa_valid = '0;
    tick(); check(IDLE, 1'b0, 1'b0);
    @(negedge clk); rst_n = 1'b1; run_request = 1'b1; pa_valid = 4'hf;
    tick(); check({pa_data[3], pa_data[2], pa_data[1], pa_data[0]}, 1'b1, 1'b0);
    @(negedge clk); pa_valid = '0; run_request = 1'b0;
    tick(); check(IDLE, 1'b0, 1'b1); // cannot stop mid-superframe
    @(negedge clk); rst_n = 1'b0;
    tick(); check(IDLE, 1'b0, 1'b0);
    @(negedge clk); rst_n = 1'b1; run_request = 1'b1; link_ready = 1'b1;
    pa_valid = 4'hf;
    tick(); check({pa_data[3], pa_data[2], pa_data[1], pa_data[0]}, 1'b1, 1'b0);
    @(negedge clk); link_ready = 1'b0; pa_valid = '0;
    tick(); check(IDLE, 1'b0, 1'b1); // GT health loss interrupts a frame
    @(negedge clk); rst_n = 1'b0;
    tick(); check(IDLE, 1'b0, 1'b0);
    @(negedge clk); rst_n = 1'b1; run_request = 1'b1; link_ready = 1'b1;
    for (int n = 0; n < 56; n++) begin
      @(negedge clk); pa_valid = 4'hf;
      tick(); check({pa_data[3], pa_data[2], pa_data[1], pa_data[0]}, 1'b1, 1'b0);
    end
    @(negedge clk); pa_valid = '0;
    tick(); check(IDLE, 1'b0, 1'b0); // complete frame may end cleanly
    @(negedge clk); run_request = 1'b0;
    tick(); check(IDLE, 1'b0, 1'b0);
    $display("THERMO5_RAW64_CONTINUOUS_TX_PASS");
    $finish;
  end
endmodule

`default_nettype wire
