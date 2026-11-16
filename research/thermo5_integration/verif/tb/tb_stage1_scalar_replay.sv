`timescale 1ns/1ps
`default_nettype none
// Replay only captured Pre-DSM words. Extra zero words clock out the known
// 32-word algorithmic tail; these are not added to the full-chain OFDM input.
module tb_stage1_scalar_replay #(
  parameter integer WORDS=5257,
  parameter integer BUBBLES=0
);
  logic clk=0, rst_n=0, valid=0;
  wire ready, out_valid;
  logic [511:0] i_vec=0,q_vec=0;
  wire [63:0] raw;
  logic [511:0] i_mem[0:WORDS-1],q_mem[0:WORDS-1];
  integer n, produced=0,fd, cycles=0;
  always #2.285714 clk=~clk;
  tid32_cartesian_fs4_gt_tx dut(.clk(clk),.rst_n(rst_n),
    .in_valid(valid),.in_ready(ready),.in_i_poly_vec(i_vec),.in_q_poly_vec(q_vec),
    .gt_valid(out_valid),.gt_ready(1'b1),.gt_data(raw));
  initial begin
    $readmemh("stage1_replay_i.mem",i_mem);
    $readmemh("stage1_replay_q.mem",q_mem);
    fd=$fopen("stage1_replay.csv","w");
    if (!fd) $fatal(1,"capture open failed");
    $fdisplay(fd,"id,time_ps,cycle,raw_hex");
    $dumpfile("stage1_replay.vcd");
    $dumpvars(0,clk,rst_n,valid,ready,out_valid,raw,i_vec,q_vec);
    repeat(4) @(negedge clk);
    rst_n=1;
    for(n=0;n<WORDS+32;n=n+1) begin
      if(BUBBLES && n%7==3) begin
        @(negedge clk);valid=0;
        repeat(3) @(negedge clk);
      end
      @(negedge clk);valid=1;
      i_vec=(n<WORDS)?i_mem[n]:512'b0;
      q_vec=(n<WORDS)?q_mem[n]:512'b0;
      do @(posedge clk);while(!ready);
    end
    @(negedge clk); valid=0;
    wait(produced==WORDS+32);
    repeat(4) @(negedge clk);
    $display("STAGE1_REPLAY_PASS words=%0d produced=%0d bubbles=%0d",WORDS,produced,BUBBLES);
    $fclose(fd);$finish;
  end
  always @(posedge clk) begin
    cycles=cycles+1;
    if(rst_n && out_valid) begin
      $fdisplay(fd,"%0d,%0.0f,%0d,%016h",produced,$realtime*1000,cycles,raw);
      produced=produced+1;
    end
    if(cycles>100000) $fatal(1,"replay watchdog");
  end
endmodule
`default_nettype wire
