`timescale 1ps/1ps
`default_nettype none
module tb_common_reset_coordinator;
  logic axil=0,axis=0,core=0,arst_n=0;
  wire axil_n,axis_n,core_n;
  always #5000 axil=~axil;
  always #4000 axis=~axis;
  always #2286 core=~core;
  thermo5_common_reset_coordinator dut(.common_arst_n(arst_n),.s_axil_aclk(axil),.s_axis_aclk(axis),.core_clk(core),.s_axil_aresetn(axil_n),.s_axis_aresetn(axis_n),.core_aresetn(core_n));
  initial begin
    $dumpfile("common_reset_coordinator.vcd");$dumpvars(0,tb_common_reset_coordinator);
    #17000; arst_n=1;
    wait(axil_n && axis_n && core_n); #1;
    #1371;arst_n=0;#1;
    if ({axil_n,axis_n,core_n}!==3'b000)$fatal(1,"common asynchronous assertion failed");
    #7100;arst_n=1;
    fork
      begin @(posedge axil);#1;if(axil_n!==0)$fatal(1,"AXIL early release");@(posedge axil);#1;if(axil_n!==1)$fatal(1,"AXIL release missing");end
      begin @(posedge axis);#1;if(axis_n!==0)$fatal(1,"AXIS early release");@(posedge axis);#1;if(axis_n!==1)$fatal(1,"AXIS release missing");end
      begin @(posedge core);#1;if(core_n!==0)$fatal(1,"core early release");@(posedge core);#1;if(core_n!==1)$fatal(1,"core release missing");end
    join
    $display("COMMON_RESET_COORDINATOR_PASS 3domains local_two_edge_release time_ps=%0t",$time);$finish;
  end
  initial begin #300000;$fatal(1,"timeout");end
endmodule
`default_nettype wire
