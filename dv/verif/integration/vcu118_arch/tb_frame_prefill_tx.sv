`timescale 1ns/1ps
module tb_frame_prefill_tx;
  localparam int WORDS=56;
  logic clk=0,rst_n=0,run=0,link=1,valid=0,start=0,last=0;
  logic [255:0] in_data=0;logic [3:0] mask=3;logic[1:0] arch=2;logic[15:0] cfg=16'h1234,epoch=16'h0007;
  wire ready,drain,protocol_error,overflow,link_fault,out_start,out_end,out_tail;wire [1:0] out_arch;wire [15:0] out_epoch;
  wire [255:0] out_data;wire [3:0] out_mask;wire [15:0] out_cfg;
  integer sent=0,got=0,cycle=0,last_cycle=-1,first_out=-1;bit continuous_required=0,expect_fault=0;
  always #2.286 clk=~clk;
  thermo5_frame_prefill_tx #(.MAX_FRAME_WORDS(WORDS)) dut(.clk(clk),.rst_n(rst_n),.run_request(run),.link_ready(link),
    .in_valid(valid),.in_ready(ready),.in_data(in_data),.in_mask(mask),.in_arch(arch),.in_start(start),.in_end(last),.in_tail(last),.in_config_id(cfg),.in_epoch(epoch),
    .gt_data(out_data),.pa_enable_mask(out_mask),.out_start(out_start),.out_end(out_end),.out_tail(out_tail),.out_arch(out_arch),.out_config_id(out_cfg),.out_epoch(out_epoch),
    .drain_done(drain),.protocol_fault(protocol_error),.frame_overflow(overflow),.link_fault(link_fault));
  function automatic [255:0] payload(input integer n);
    return {64'h3333000000000000+n,64'h2222000000000000+n,64'h1111000000000000+n,64'h0001000000000000+n};
  endfunction
  always @(posedge clk) if(rst_n) begin
    cycle=cycle+1;
    if(valid && ready)sent=sent+1;
    if(out_mask!=0) begin
      if(!run && drain)$fatal(1,"drain asserted while the final output word is still active");
      if(sent<WORDS)$fatal(1,"frame started before full prefill");
      if(out_mask!==mask || out_cfg!==cfg || out_epoch!==epoch || out_arch!==arch || out_data!==payload(got))
        $fatal(1,"lane/config/order mismatch word=%0d",got);
      if(out_start!==(got%WORDS==0) || out_end!==(got%WORDS==WORDS-1) || out_tail!==out_end)
        $fatal(1,"frame marker mismatch word=%0d",got);
      if(last_cycle>=0 && (continuous_required || got%WORDS!=0) && cycle!=last_cycle+1)$fatal(1,"bubble inside buffered frame");
      if(first_out<0)first_out=cycle;
      last_cycle=cycle;got=got+1;
    end
    if(!expect_fault && (protocol_error||overflow||link_fault))$fatal(1,"unexpected adapter fault");
  end
  initial begin
    repeat(4) @(negedge clk);rst_n=1;run=1;
    // Source pause is absorbed before frame release. STOP at word20 must
    // still accept the rest of the open frame and transmit all 56 words.
    for(int i=0;i<WORDS;i++) begin
      if(i==12)begin @(negedge clk);valid=0;repeat(7)@(negedge clk);end
      @(negedge clk);valid=1;start=(i==0);last=(i==WORDS-1);in_data=payload(i);
      if(i==20)run=0;
      do @(posedge clk);while(!ready);
    end
    @(negedge clk);valid=0;start=0;last=0;
    wait(got==WORDS);repeat(3)@(negedge clk);
    if(!drain || sent!=WORDS || ready)$fatal(1,"STOP did not drain cleanly");
    $display("PREFILL_STOP_DRAIN_PASS words=%0d first_out_cycle=%0d",got,first_out);
    // Paired reset then repeat with the four-plane mask and two back-to-back
    // frames, checking full ordering and every active cycle within each frame.
    rst_n=0;repeat(3)@(negedge clk);rst_n=1;run=1;mask=15;arch=0;continuous_required=1;sent=0;got=0;last_cycle=-1;first_out=-1;
    for(int i=0;i<2*WORDS;i++) begin
      @(negedge clk);valid=1;start=(i%WORDS==0);last=(i%WORDS==WORDS-1);in_data=payload(i);
      do @(posedge clk);while(!ready);
    end
    @(negedge clk);valid=0;start=0;last=0;
    wait(got==2*WORDS);@(negedge clk);run=0;repeat(3)@(negedge clk);
    if(!drain || sent!=2*WORDS)$fatal(1,"restart did not drain");
    $display("PREFILL_TWO_FRAME_RESTART_PASS words=%0d no_interframe_gap=1",got);
    // A live EF1->EF2 change has the same PA mask and must still fail closed.
    rst_n=0;repeat(3)@(negedge clk);rst_n=1;run=1;mask=15;arch=0;expect_fault=1;
    @(negedge clk);valid=1;start=1;last=0;in_data=payload(0);
    @(negedge clk);valid=0;start=0;arch=1;
    @(negedge clk);
    if(protocol_error)$fatal(1,"invalid input payload must be ignored");
    $display("PREFILL_INVALID_PAYLOAD_IGNORED_PASS");
    valid=1;
    @(negedge clk);
    if(!protocol_error || out_mask!=0)$fatal(1,"live architecture switch not rejected");
    $display("PREFILL_LIVE_MODE_CHANGE_EXPECTED_FAULT_PASS same_mask=1");
    rst_n=0;valid=0;repeat(3)@(negedge clk);rst_n=1;run=1;mask=3;arch=2;
    for(int i=0;i<WORDS;i++) begin
      @(negedge clk);valid=1;start=(i==0);last=0;in_data=payload(i);
      do @(posedge clk);while(!ready);
    end
    @(negedge clk);valid=0;start=0;
    if(!overflow || out_mask!=0)$fatal(1,"overlong frame was not rejected before output");
    $display("PREFILL_OVERSIZE_EXPECTED_FAULT_PASS max_words=%0d",WORDS);
    rst_n=0;repeat(3)@(negedge clk);rst_n=1;run=1;link=1;mask=3;arch=2;
    got=0;sent=0;last_cycle=-1;continuous_required=0;
    for(int i=0;i<WORDS;i++) begin
      @(negedge clk);valid=1;start=(i==0);last=(i==WORDS-1);in_data=payload(i);
      do @(posedge clk);while(!ready);
    end
    @(negedge clk);valid=0;start=0;last=0;
    wait(out_mask!=0);@(negedge clk);link=0;@(negedge clk);
    if(!link_fault || out_mask!=0)$fatal(1,"link loss did not blank output and set fault");
    $display("PREFILL_LINK_LOSS_EXPECTED_FAULT_PASS");
    $finish;
  end
  initial begin : optional_trace
    string path;
    if($value$plusargs("VCD=%s",path)) begin
      $dumpfile(path);
      $dumpvars(0,clk,rst_n,run,link,valid,ready,start,last,in_data,mask,arch,cfg,epoch,
        out_data,out_mask,out_start,out_end,out_tail,out_arch,out_cfg,out_epoch,drain,protocol_error,overflow,link_fault);
    end
  end
  initial begin #100000;$fatal(1,"prefill timeout");end
endmodule
