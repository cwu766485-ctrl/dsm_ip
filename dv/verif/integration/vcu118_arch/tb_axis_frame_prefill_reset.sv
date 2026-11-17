`timescale 1ns/1ps
module tb_axis_frame_prefill_reset;
  logic clk=0,rst_n=0,in_valid=0,in_start=0,in_last=0,out_ready=1;
  logic signed [31:0] in_i=0,in_q=0;logic signed [15:0] in_gain=16384;
  wire in_ready,out_valid,out_start,out_last,protocol_fault,frame_occupied;
  wire signed [31:0] out_i,out_q;wire signed [15:0] out_gain;
  int received=0;
  always #4 clk=~clk;
  thermo5_axis_frame_prefill #(.W(16),.LANES(2),.MAX_BEATS(4)) dut(.*);
  always @(posedge clk) if(rst_n && out_valid && out_ready) begin
    if(out_i!==32'(received+101) || out_q!==-32'(received+101) || out_start!==(received==0) || out_last!==(received==3))
      $fatal(1,"old or reordered data after reset at %0d",received);
    received=received+1;
  end
  task automatic send(input int n,input bit first,input bit last);
    @(negedge clk);in_valid=1;in_start=first;in_last=last;in_i=n;in_q=-n;
    do @(posedge clk);while(!in_ready);
  endtask
  initial begin
    repeat(3)@(negedge clk);rst_n=1;
    send(1,1,0);send(2,0,0);
    @(negedge clk);in_valid=0;rst_n=0;
    repeat(3)@(negedge clk);rst_n=1;
    send(101,1,0);send(102,0,0);send(103,0,0);send(104,0,1);
    @(negedge clk);in_valid=0;in_start=0;in_last=0;
    wait(received==4);repeat(2)@(negedge clk);
    if(frame_occupied || protocol_fault)$fatal(1,"reset frame did not drain cleanly");
    send(1,1,0);send(2,0,0);send(3,0,0);send(4,0,0);
    @(negedge clk);in_valid=0;
    if(!protocol_fault || in_ready)$fatal(1,"oversized frame did not fault and stop input");
    $display("AXIS_FRAME_PREFILL_RESET_OVERFLOW_PASS reset_discards_partial=1 oversized_frame_fault=1");$finish;
  end
  initial begin #100000;$fatal(1,"timeout");end
endmodule
