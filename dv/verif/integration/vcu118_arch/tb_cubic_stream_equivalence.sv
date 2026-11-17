`timescale 1ns/1ps
module tb_cubic_stream_equivalence;
  localparam int W=16,L=4;
  logic clk=0,rst_n=0,enable=1,in_valid=0,in_frame_start=0,in_frame_end=0,in_tail=0,out_ready=0;
  logic signed [L*W-1:0] in_i_vec=0,in_q_vec=0;
  wire ref_ready,ref_valid,ref_start,ref_end,ref_tail,cand_ready,cand_valid,cand_start,cand_end,cand_tail;
  wire signed [2*L*W-1:0] ref_i,ref_q,cand_i,cand_q;
  int accepted=0,received=0,stalls=0,bubbles=0,resets=0;
  bit previous_accept=1;
  always #2.5 clk=~clk;
  cubic_reference #(.W(W),.LANES(L),.APPEND_TAIL_VECTOR(1)) ref_dut (
    .clk(clk),.rst_n(rst_n),.enable(enable),.in_valid(in_valid),.in_ready(ref_ready),
    .in_frame_start(in_frame_start),.in_frame_end(in_frame_end),.in_tail(in_tail),.in_i_vec(in_i_vec),.in_q_vec(in_q_vec),
    .out_valid(ref_valid),.out_ready(out_ready),.out_frame_start(ref_start),.out_frame_end(ref_end),.out_tail(ref_tail),.out_i_vec(ref_i),.out_q_vec(ref_q));
  cubic_candidate #(.W(W),.LANES(L),.APPEND_TAIL_VECTOR(1)) cand_dut (
    .clk(clk),.rst_n(rst_n),.enable(enable),.in_valid(in_valid),.in_ready(cand_ready),
    .in_frame_start(in_frame_start),.in_frame_end(in_frame_end),.in_tail(in_tail),.in_i_vec(in_i_vec),.in_q_vec(in_q_vec),
    .out_valid(cand_valid),.out_ready(out_ready),.out_frame_start(cand_start),.out_frame_end(cand_end),.out_tail(cand_tail),.out_i_vec(cand_i),.out_q_vec(cand_q));
  initial begin
    repeat(4) @(negedge clk);rst_n=1;
    for(int c=0;c<5000;c++) begin
      @(negedge clk);
      if(c==2500)begin rst_n=0;in_valid=0;previous_accept=1;end
      if(c==2503)begin rst_n=1;accepted=0;previous_accept=1;resets++;end
      out_ready=($urandom_range(0,4)!=0);
      if(rst_n && (!in_valid || previous_accept)) begin
        in_valid=($urandom_range(0,5)!=0);
        if(in_valid)begin
          in_frame_start=(accepted%64==0);in_frame_end=(accepted%64==63);in_tail=0;
          for(int l=0;l<L;l++)begin in_i_vec[l*W+:W]=$urandom;in_q_vec[l*W+:W]=$urandom;end
        end
      end
      @(posedge clk);
      if(rst_n)begin
        if(ref_ready!==cand_ready || ref_valid!==cand_valid ||
           (ref_valid && ({ref_start,ref_end,ref_tail,ref_i,ref_q} !== {cand_start,cand_end,cand_tail,cand_i,cand_q})))
          $fatal(1,"cubic full-stream mismatch cycle=%0d",c);
        previous_accept=in_valid && ref_ready;
        if(previous_accept)accepted++;
        if(ref_valid&&out_ready)received++;
        if(ref_valid&&!out_ready)stalls++;
        if(!in_valid)bubbles++;
      end
    end
    if(received<500 || stalls==0 || bubbles==0 || resets!=1)$fatal(1,"insufficient exercise");
    $display("CUBIC_STREAM_EQ_PASS outputs=%0d stalls=%0d bubbles=%0d resets=%0d",received,stalls,bubbles,resets);$finish;
  end
endmodule
