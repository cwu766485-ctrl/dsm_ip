`timescale 1ns/1ps

interface mash11_sku_if(input logic clk);
  logic rst_n = 1'b0;
  logic in_valid = 1'b0;
  logic signed [15:0] sample = '0;
  logic out_valid;
  logic stage1_bit;
  logic stage2_bit;
  logic signed [2:0] combined_level;

  property p_reset_clears_output_valid;
    @(posedge clk) !rst_n |-> !out_valid;
  endproperty
  assert property (p_reset_clears_output_valid)
    else $fatal(1, "MASH output valid remained asserted during reset");

  property p_valid_matches_previous_input;
    @(posedge clk) disable iff (!rst_n) out_valid == $past(in_valid);
  endproperty
  assert property (p_valid_matches_previous_input)
    else $fatal(1, "MASH output valid is not aligned to the prior input sample");

  property p_payload_holds_after_disabled_sample;
    @(posedge clk) disable iff (!rst_n)
      $past(!in_valid) |-> $stable({stage1_bit,stage2_bit,combined_level});
  endproperty
  assert property (p_payload_holds_after_disabled_sample)
    else $fatal(1, "MASH output payload changed without an enabled sample");

  cover property (@(posedge clk) !rst_n ##1 rst_n ##[1:4] in_valid);
  cover property (@(posedge clk) in_valid ##1 !in_valid ##1 in_valid);
endinterface
