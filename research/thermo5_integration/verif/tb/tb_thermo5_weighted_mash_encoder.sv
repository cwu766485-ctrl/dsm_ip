`timescale 1ns/1ps
`default_nettype none
module tb_thermo5_weighted_mash_encoder;
  localparam int L=32;
  logic clk=0, rst_n=0, in_valid=0;
  logic [2*L-1:0] s1='0, s2='0;
  wire in_ready, out_valid;
  wire [2*L-1:0] pa0, pa1;
  localparam int N=256;
  integer n, lane, errors=0, seen=0;
  integer q1i, q1q, q2i, q2q, yi, yq, prev_i=-1, prev_q=-1;
  integer seed=32'h5a17c0de;
  logic [2*L-1:0] expected0[0:N-1], expected1[0:N-1];

  thermo5_weighted_mash_encoder #(.CHANNELS(L)) dut(
    .clk,.rst_n,.in_valid,.in_ready,.in_stage1_data(s1),.in_stage2_data(s2),
    .out_valid,.out_ready(1'b1),.out_pa0_data(pa0),.out_pa1_data(pa1));
  always #5 clk=~clk;

  function automatic integer decode(input logic [2*L-1:0] word,
                                    input integer lane, input integer comp);
    logic b;
    begin
      b=word[2*lane+comp];
      if(comp==0) decode=((lane%2)==0) ? (b?1:-1) : (b?-1:1);
      else decode=((lane%2)==0) ? (b?-1:1) : (b?1:-1);
    end
  endfunction

  function automatic integer bipolar(input logic b);
    bipolar=b?1:-1;
  endfunction

  always @(posedge clk) begin
    if(rst_n && out_valid) begin
      if(pa0 !== expected0[seen] || pa1 !== expected1[seen]) errors=errors+1;
      seen=seen+1;
    end
  end

  initial begin
    repeat(3) @(negedge clk); rst_n=1;
    for(n=0;n<N;n=n+1) begin
      @(negedge clk);
      s1=$random(seed); s2=$random(seed); in_valid=1;
      expected0[n]='0; expected1[n]='0;
      for(lane=0;lane<L;lane=lane+1) begin
        q1i=decode(s1,lane,0); q1q=decode(s1,lane,1);
        q2i=decode(s2,lane,0); q2q=decode(s2,lane,1);
        yi=q1i+q2i-prev_i; yq=q1q+q2q-prev_q;
        if(yi!= -3 && yi!= -1 && yi!=1 && yi!=3) errors=errors+1;
        if(yq!= -3 && yq!= -1 && yq!=1 && yq!=3) errors=errors+1;
        expected0[n][2*lane]=((yi==-1)||(yi==3)) ? 1'b1 : 1'b0;
        expected1[n][2*lane]=((yi==1)||(yi==3)) ? 1'b1 : 1'b0;
        expected0[n][2*lane+1]=((yq==-1)||(yq==3)) ? 1'b1 : 1'b0;
        expected1[n][2*lane+1]=((yq==1)||(yq==3)) ? 1'b1 : 1'b0;
        // Convert bipolar PA decisions to the Fs/4 raw bit polarity.
        if((lane%2)!=0) begin
          expected0[n][2*lane]=~expected0[n][2*lane];
          expected1[n][2*lane]=~expected1[n][2*lane];
        end
        if((lane%2)==0) begin
          expected0[n][2*lane+1]=~expected0[n][2*lane+1];
          expected1[n][2*lane+1]=~expected1[n][2*lane+1];
        end
        prev_i=q2i; prev_q=q2q;
      end
    end
    @(negedge clk); in_valid=0;
    repeat(2) @(negedge clk);
    if(seen!=N || errors!=0) $fatal(1,"encoder errors=%0d vectors=%0d",errors,seen);
    $display("THERMO5_WEIGHTED_MASH_ENCODER_PASS vectors=%0d lanes=%0d",seen,L);
    $finish;
  end
endmodule
`default_nettype wire
