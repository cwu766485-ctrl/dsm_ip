`timescale 1ns/1ps
// Replay only the formal witness inputs against the actual frontend chain.
module thermo5_v14_cubic_chain_trace_tb;
  logic clk=0, rst_n=0, source_offer=0;
  logic [3:0] pa_ready=0;
  logic [4:0] stimulus[128];
  string path;
  int cycles, arch, stage;
  int hits=0;
  thermo5_v14_cubic_chain_harness dut (.*);
  always #2.286 clk=~clk;
  initial begin
    if (!$value$plusargs("TRACE=%s",path) || !$value$plusargs("CYCLES=%d",cycles) ||
        !$value$plusargs("ARCH=%d",arch) || !$value$plusargs("STAGE=%d",stage))
      $fatal(1,"Trace options missing");
    if (cycles<1 || cycles>128 || !(arch inside {1,3}) || !(stage inside {1,2}))
      $fatal(1,"Trace length, SKU or stage is invalid");
    $readmemh(path,stimulus,0,cycles-1);
    repeat (4) @(negedge clk);
    rst_n=1;
    for (int cycle=0;cycle<cycles;cycle++) begin
      {source_offer,pa_ready}=stimulus[cycle];
      @(posedge clk);
      if (arch==1 ? (stage==1 ? dut.g_sku[1].replace1 : dut.g_sku[1].replace2) :
                    (stage==1 ? dut.g_sku[3].replace1 : dut.g_sku[3].replace2)) begin
        $display("CUBIC_WITNESS_ARCH=%0d STAGE=%0d CYCLE=%0d",arch,stage,cycle);
        hits++;
      end
      @(negedge clk);
    end
    if (!hits) $fatal(1,"Exact single-entry replacement was not replayed");
    $display("CUBIC_CHAIN_TRACE_REPLAY_PASS");
    $finish;
  end
endmodule
