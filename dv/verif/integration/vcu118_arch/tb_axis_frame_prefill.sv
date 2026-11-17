`timescale 1ns/1ps
module tb_axis_frame_prefill;
  logic clk=0,rst_n=0,in_valid=0,in_start=0,in_last=0,out_ready=0;
  logic signed [31:0] in_i=0,in_q=0;logic signed [15:0] in_gain=0;
  wire in_ready,out_valid,out_start,out_last,protocol_fault,frame_occupied;
  wire signed [31:0] out_i,out_q;wire signed [15:0] out_gain;
  int received=0,source_count=0,cycle=0;
  always #4 clk=~clk;
  thermo5_axis_frame_prefill #(.W(16),.LANES(2),.MAX_BEATS(8)) dut(.*);
  always @(posedge clk) if(rst_n) begin
    cycle=cycle+1;
    if(in_valid&&in_ready)source_count=source_count+1;
    if(out_valid&&out_ready) begin
      if(source_count!=8 || out_i!==32'(received+1) || out_q!==-32'(received+1) ||
         out_gain!==16'sd16384 || out_start!==(received==0) || out_last!==(received==7))
        $fatal(1,"data, marker, or prefill mismatch at %0d",received);
      received=received+1;
    end
    if(protocol_fault)$fatal(1,"unexpected protocol fault");
  end
  initial begin
    repeat(3)@(negedge clk);rst_n=1;
    for(int i=0;i<8;i++) begin
      if(i%3==1)begin @(negedge clk);in_valid=0;repeat(2)@(negedge clk);end
      @(negedge clk);in_valid=1;in_i=i+1;in_q=-(i+1);in_gain=16384;in_start=(i==0);in_last=(i==7);
      do @(posedge clk);while(!in_ready);
    end
    @(negedge clk);in_valid=0;in_start=0;in_last=0;
    repeat(5)@(negedge clk);if(!out_valid || out_i!==1)$fatal(1,"held output changed before ready");out_ready=1;
    wait(received==8);@(negedge clk);out_ready=0;
    repeat(2)@(negedge clk);if(frame_occupied||!in_ready)$fatal(1,"frame did not drain");
    $display("AXIS_FRAME_PREFILL_PASS words=8 source_bubbles=1 output_stall=1");$finish;
  end
  initial begin #100000;$fatal(1,"timeout");end
endmodule
