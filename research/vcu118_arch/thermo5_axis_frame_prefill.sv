`timescale 1ns/1ps
`default_nettype none
// Research candidate: one complete bounded AXIS frame is collected before
// replay into the existing AXIS CDC. This has no indefinite-throughput claim.
module thermo5_axis_frame_prefill #(
  parameter int W=16, LANES=14, MAX_BEATS=3008,
  localparam int CW=$clog2(MAX_BEATS+1)
)(
  input wire logic clk,rst_n,
  input wire logic in_valid,output wire logic in_ready,
  input wire logic signed [LANES*W-1:0] in_i,in_q,
  input wire logic in_start,in_last,input wire logic signed [15:0] in_gain,
  output wire logic out_valid,input wire logic out_ready,
  output wire logic signed [LANES*W-1:0] out_i,out_q,
  output wire logic out_start,out_last,output wire logic signed [15:0] out_gain,
  output logic protocol_fault,output wire logic frame_occupied
);
  logic signed [LANES*W-1:0] mem_i[0:MAX_BEATS-1],mem_q[0:MAX_BEATS-1];
  logic [15:0] gain_mem[0:MAX_BEATS-1];
  logic start_mem[0:MAX_BEATS-1],last_mem[0:MAX_BEATS-1];
  logic [CW-1:0] count,read_index,frame_words;
  logic playing;
  assign frame_occupied=(count!=0)||playing;
  assign in_ready=rst_n && !playing && !protocol_fault && count<MAX_BEATS;
  assign out_valid=rst_n && playing && !protocol_fault;
  assign out_i=mem_i[read_index];assign out_q=mem_q[read_index];
  assign out_start=start_mem[read_index];assign out_last=last_mem[read_index];assign out_gain=gain_mem[read_index];
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin count<=0;read_index<=0;frame_words<=0;playing<=0;protocol_fault<=0;end
    else begin
      if(in_valid && in_ready) begin
        if(in_start!=(count==0) || (count==CW'(MAX_BEATS-1) && !in_last)) protocol_fault<=1;
        else begin
          mem_i[count]<=in_i;mem_q[count]<=in_q;gain_mem[count]<=in_gain;
          start_mem[count]<=in_start;last_mem[count]<=in_last;
          count<=count+1'b1;
          if(in_last)begin frame_words<=count+1'b1;playing<=1;read_index<=0;end
        end
      end
      if(out_valid && out_ready) begin
        if(read_index==frame_words-1)begin playing<=0;count<=0;read_index<=0;frame_words<=0;end
        else read_index<=read_index+1'b1;
      end
    end
  end
  initial if(MAX_BEATS<1) $error("MAX_BEATS must be positive");
endmodule
`default_nettype wire
