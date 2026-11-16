`timescale 1ns/1ps
`default_nettype none
module tb_mash_control_replay #(
  parameter integer WORDS=5257,
  parameter integer STRESS=0
);
  logic clk=0,rst_n=0,stop_req=0,valid=0,ready_out=1;
  logic [511:0] iv=0,qv=0;
  logic fs=0,fe=0;
  logic [15:0] epoch=1;
  wire ready,ov,drained,overflow;
  wire [63:0] pa0,pa1;
  wire [15:0] ocfg,oe;
  wire ofs,ofe,ot;
  logic [511:0] ii[0:WORDS-1],qq[0:WORDS-1];
  logic [63:0] e0[0:WORDS-1],e1[0:WORDS-1];
  integer n,produced=0,cycles=0,errors=0,fd;
  logic checking=1,force_block=0;
  always #2.285714 clk=~clk;
  always @(negedge clk) begin
    ready_out=!force_block && (!STRESS || cycles%1024<300 || cycles%1024>=700);
  end
  thermo5_weighted_mash_backend_adapter #(
    .FIFO_DEPTH(64),.USE_ACCUMULATOR_RESIDUE(1'b1)
  ) dut(.clk(clk),.rst_n(rst_n),.stop_req(stop_req),.drain_done(drained),
    .in_valid(valid),.in_ready(ready),.in_i_poly_vec(iv),.in_q_poly_vec(qv),
    .in_config_id(16'h0042),.in_epoch(epoch),.in_frame_start(fs),.in_frame_end(fe),.in_tail(1'b0),
    .out_valid(ov),.out_ready(ready_out),.out_stage1_data(),.out_stage2_data(),
    .out_pa0_data(pa0),.out_pa1_data(pa1),.out_config_id(ocfg),.out_epoch(oe),
    .out_frame_start(ofs),.out_frame_end(ofe),.out_tail(ot),.overflow_error(overflow),.inflight_count());
  task automatic send(input integer count);
    integer k;
    begin
      for(k=0;k<count;k=k+1) begin
        if(STRESS && k%113==37) begin
          @(negedge clk);valid=0;
          repeat(3) @(negedge clk);
        end
        if(STRESS && k==1000) begin
          @(negedge clk);valid=0;stop_req=1;
          wait(drained);
          repeat(17) @(negedge clk);
          if(ready || !drained) $fatal(1,"STOP not held");
          stop_req=0;
        end
        @(negedge clk);valid=1;iv=ii[k];qv=qq[k];fs=(k==0);fe=(k==WORDS-1);
        do @(posedge clk);while(!ready);
      end
      @(negedge clk);valid=0;fs=0;fe=0;
    end
  endtask
  always @(posedge clk) begin
    cycles=cycles+1;
    if(rst_n && ov && ready_out && checking) begin
      if(produced>=WORDS || pa0!==e0[produced] || pa1!==e1[produced] ||
         ocfg!==16'h0042 || oe!==epoch || ot || ofs!==(produced==0) || ofe!==(produced==WORDS-1)) begin
        errors=errors+1;
        if(errors<5) $display("CONTROL_MISMATCH epoch=%0d word=%0d time_ps=%0.0f actual=%016h/%016h expected=%016h/%016h",
          epoch,produced,$realtime*1000,pa0,pa1,e0[produced],e1[produced]);
      end
      $fdisplay(fd,"%0d,%0d,%0.0f,%016h,%016h",epoch,produced,$realtime*1000,pa0,pa1);
      produced=produced+1;
    end
    if(rst_n && overflow) $fatal(1,"overflow");
    if(cycles>100000) $fatal(1,"watchdog produced=%0d",produced);
  end
  initial begin
    $readmemh("stage1_replay_i.mem",ii);$readmemh("stage1_replay_q.mem",qq);
    $readmemh("corrected_expected_pa0.mem",e0);$readmemh("corrected_expected_pa1.mem",e1);
    fd=$fopen("control_pa.csv","w");$fdisplay(fd,"epoch,id,time_ps,pa0,pa1");
    $dumpfile("controls.vcd");
    $dumpvars(0,clk,rst_n,valid,ready,ready_out,ov,stop_req,drained,overflow,pa0,pa1,epoch,oe);
    repeat(4) @(negedge clk);rst_n=1;
    send(WORDS);wait(produced==WORDS);
    if(errors) $fatal(1,"control comparison failed errors=%0d",errors);
    if(STRESS) begin
      @(negedge clk);checking=0;force_block=1;
      send(16);repeat(4) @(negedge clk);
      rst_n=0;repeat(3) @(negedge clk);
      if(ov) $fatal(1,"old epoch not flushed");
      produced=0;epoch=2;force_block=0;checking=1;rst_n=1;
      send(WORDS);wait(produced==WORDS);
      if(errors) $fatal(1,"post-reset comparison failed errors=%0d",errors);
    end
    $display("MASH_CONTROL_REPLAY_PASS stress=%0d words=%0d errors=%0d",STRESS,WORDS,errors);
    $fclose(fd);$finish;
  end
endmodule
`default_nettype wire
