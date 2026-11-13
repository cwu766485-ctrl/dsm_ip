`timescale 1ns/1ps
// Component-level evidence only; not a product-level FIFO/epoch oracle.
module tb_thermo5_reset_release_contract;
  reg [2:0] clk=0, arst=0;
  reg [2:0] clk_run=3'b111;
  wire [2:0] srst;
  integer checks=0;
  always #4 if (clk_run[0]) clk[0]=~clk[0];
  always #2.286 if (clk_run[1]) clk[1]=~clk[1];
  always #5 if (clk_run[2]) clk[2]=~clk[2];
  for(genvar g=0;g<3;g=g+1) begin: domains
    dsm_reset_sync dut(.clk(clk[g]),.arst_n(arst[g]),.srst_n(srst[g]));
  end
  task automatic release_domain(input integer d,input integer phase_ps);
    begin
      #(phase_ps * 1ps); arst[d]=1;
      @(posedge clk[d]); #1ps;
      if(srst[d]!==0) $fatal(1,"early release domain%0d",d);
      @(posedge clk[d]); #1ps;
      if(srst[d]!==1) $fatal(1,"late release domain%0d",d);
      checks++;
    end
  endtask
  task automatic assert_all;
    begin
      arst=0; #1ps;
      if(srst!==0) $fatal(1,"async assertion did not clear all domains");
      checks++;
    end
  endtask
  initial begin
    #1; arst=7; #1; assert_all();
    @(negedge clk[2]); clk_run[2]=1'b0;
    #1; arst[2]=1'b1;
    #20;
    if(srst[2]!==1'b0) $fatal(1,"reset released without local clock edges");
    clk_run[2]=1'b1;
    @(posedge clk[2]); #1ps;
    if(srst[2]!==1'b0) $fatal(1,"reset released on first edge after stopped clock");
    @(posedge clk[2]); #1ps;
    if(srst[2]!==1'b1) $fatal(1,"reset did not release on second edge after stopped clock");
    checks++;
    assert_all();
    repeat(3) @(negedge clk[0]);
    for(integer epoch=0;epoch<6;epoch++) begin
      for(integer n=0;n<3;n++) begin
        // All cyclic release orders; avoid ambiguous exact-active-edge request.
        release_domain((epoch+n)%3,137+epoch*113);
      end
      #1.117; assert_all();
      repeat(3) @(negedge clk[0]);
    end
    $display("RESET_RELEASE_CONTRACT_PASS epochs=6 domain_releases=18 checks=%0d async_assert=PASS own_clock_two_edge_release=PASS",checks);
    $finish;
  end
  initial begin #10000; $fatal(1,"reset contract watchdog"); end
endmodule
