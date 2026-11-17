`timescale 1ns/1ps
module tb_existing_serializer_contract;
  logic clk=0,rst_n=0,link_ready=1,run=0;
  logic [3:0] valid=0;
  logic [63:0] data[0:3];
  wire [3:0] ready;wire [255:0] txdata;wire pa_enable,fault;
  always #2.286 clk=~clk;
  thermo5_raw64_continuous_tx dut(.clk(clk),.rst_n(rst_n),.link_ready(link_ready),.run_request(run),
    .pa_valid(valid),.pa_data(data),.pa_ready(ready),.gt_txdata(txdata),.pa_enable(pa_enable),.stream_fault(fault));
  initial begin
    for(int i=0;i<4;i++)data[i]=64'h0123456789abcdef;
    repeat(3) @(negedge clk);rst_n=1;run=1;valid=4'h3;
    @(negedge clk);
    if(!fault || pa_enable) $fatal(1,"two-plane mismatch not detected");
    $display("EXISTING_SERIALIZER_MASH_MASK_EXPECTED_FAULT_PASS ready=%h valid=%h",ready,valid);
    rst_n=0;run=0;valid=0;repeat(2) @(negedge clk);rst_n=1;run=1;valid=4'hf;
    @(negedge clk);
    if(fault || !pa_enable)$fatal(1,"equal-plane start failed");
    run=0;valid=4'hf;
    @(negedge clk);
    if(!fault)$fatal(1,"STOP while draining must flag existing contract fault");
    $display("EXISTING_SERIALIZER_STOP_DRAIN_EXPECTED_FAULT_PASS");
    $finish;
  end
endmodule
