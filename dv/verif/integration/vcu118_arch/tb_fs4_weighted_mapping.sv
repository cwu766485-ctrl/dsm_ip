`timescale 1ns/1ps
module tb_fs4_weighted_mapping;
  logic clk=0,rst_n=0,in_valid=0;
  logic [63:0] q1=0,q2=0;
  wire in_ready,out_valid;wire [63:0] pa0,pa1;
  always #2.286 clk=~clk;
  thermo5_mash_weighted_encoder dut(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_ready(in_ready),
    .in_stage1_data(q1),.in_stage2_data(q2),.out_valid(out_valid),.out_ready(1'b1),.out_pa0_data(pa0),.out_pa1_data(pa1));
  initial begin
    repeat(3) @(negedge clk);rst_n=1;
    // q1: I=+1, Q=-1 at every Cartesian time. q2: I=Q=-1,
    // identical to reset, so cancellation equals q1 without a transient.
    @(negedge clk);in_valid=1;q1=64'h3333333333333333;q2=64'h6666666666666666;
    @(negedge clk);in_valid=0;
    if(!out_valid || pa0!==64'hcccccccccccccccc || pa1!==64'h3333333333333333)
      $fatal(1,"unexpected Fs/4 mapping PA0=%h PA1=%h",pa0,pa1);
    for(int bit_index=0;bit_index<64;bit_index++) begin
      int y;y=(pa0[bit_index]?1:-1)+2*(pa1[bit_index]?1:-1);
      if(y!=((bit_index%4<2)?1:-1))$fatal(1,"RF bit order mismatch bit=%0d y=%0d",bit_index,y);
    end
    $display("FS4_ENCODER_MAPPING_PASS bit0_first=1 phase=I,-Q,-I,Q weights=1,2 samples=64");
    $finish;
  end
endmodule
