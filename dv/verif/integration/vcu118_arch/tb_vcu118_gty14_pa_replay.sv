`timescale 1ps/1fs
module tb_vcu118_gty14_pa_replay;
  localparam integer WORDS=5264, MAX_BITS=1000000;
  localparam realtime UI=1000.0/14.0;
  reg refclk=0,freeclk=0,reset=1;
  always #4000 refclk=~refclk;
  always #2500 freeclk=~freeclk;
  wire [0:0] txclk,rxclk,txdone,rxdone,txactive,rxactive,cdr;
  wire [1:0] txp,txn,txpma,rxpma,powergood;
  wire [127:0] rxdata;
  wire [127:0] txdata;
  reg rst_n=0,run_request=0,in_valid=0,in_start=0,in_end=0;
  reg [255:0] in_data=0;
  reg [63:0] pa0[0:WORDS-1],pa1[0:WORDS-1];
  wire in_ready,drain_done,fault,overflow,link_fault,out_start,out_end,out_tail;
  wire [255:0] gt_data; wire [3:0] out_mask;
  wire [15:0] out_cfg,out_epoch; wire [1:0] out_arch;
  integer sent=0, emitted=0;
  assign txdata=gt_data[127:0];
  thermo5_frame_prefill_tx #(.MAX_FRAME_WORDS(WORDS)) buffer (
    .clk(txclk[0]), .rst_n(rst_n), .run_request(run_request), .link_ready(txdone[0]),
    .in_valid(in_valid),.in_ready(in_ready),.in_data(in_data),.in_mask(4'h3),.in_arch(2'd2),
    .in_start(in_start),.in_end(in_end),.in_tail(in_end),.in_config_id(16'h1234),.in_epoch(16'h0099),
    .gt_data(gt_data),.pa_enable_mask(out_mask),.out_start(out_start),.out_end(out_end),.out_tail(out_tail),
    .out_arch(out_arch),.out_config_id(out_cfg),.out_epoch(out_epoch),.drain_done(drain_done),
    .protocol_fault(fault),.frame_overflow(overflow),.link_fault(link_fault));
  always @(posedge txclk[0]) if(rst_n) begin
    if(in_valid && in_ready) sent=sent+1;
    if(out_mask!=0) begin
      if(sent!=WORDS || out_mask!==4'h3 || out_arch!==2 || out_cfg!==16'h1234 || out_epoch!==16'h0099 ||
         out_start!==(emitted==0) || out_end!==(emitted==WORDS-1) || out_tail!==out_end ||
         gt_data[63:0]!==pa0[emitted] || gt_data[127:64]!==pa1[emitted])
        $fatal(1,"prefill data/metadata mismatch word=%0d",emitted);
      emitted=emitted+1;
    end
    if(fault || overflow || link_fault) $fatal(1,"prefill fault");
  end
  reg [1:0] txbits[0:MAX_BITS-1];
  integer txcount=0,rxcount=0,clk_checks=0;
  realtime previous_tx_clock=0;
  always @(posedge txclk[0]) if(txdone[0]) begin
    if(previous_tx_clock>0 && clk_checks==0) begin
      if(($realtime-previous_tx_clock)<4571.0 || ($realtime-previous_tx_clock)>4572.0)
        $fatal(1,"TXUSRCLK2 period mismatch ps=%f",$realtime-previous_tx_clock);
      $display("GTY_TXUSRCLK2_PASS period_ps=%f",$realtime-previous_tx_clock);
      clk_checks=1;
    end
    previous_tx_clock=$realtime;
  end
  reg [127:0] rxwords[0:15999];
  always @(posedge rxclk[0]) if(rxdone[0] && rxcount<16000) begin
    rxwords[rxcount]=rxdata;rxcount=rxcount+1;
  end
  vcu118_gty14 dut(
    .gtwiz_userclk_tx_reset_in(reset),.gtwiz_userclk_tx_srcclk_out(),.gtwiz_userclk_tx_usrclk_out(),
    .gtwiz_userclk_tx_usrclk2_out(txclk),.gtwiz_userclk_tx_active_out(txactive),
    .gtwiz_userclk_rx_reset_in(reset),.gtwiz_userclk_rx_srcclk_out(),.gtwiz_userclk_rx_usrclk_out(),
    .gtwiz_userclk_rx_usrclk2_out(rxclk),.gtwiz_userclk_rx_active_out(rxactive),
    .gtwiz_reset_clk_freerun_in(freeclk),.gtwiz_reset_all_in(reset),
    .gtwiz_reset_tx_pll_and_datapath_in(1'b0),.gtwiz_reset_tx_datapath_in(1'b0),
    .gtwiz_reset_rx_pll_and_datapath_in(1'b0),.gtwiz_reset_rx_datapath_in(1'b0),
    .gtwiz_reset_rx_cdr_stable_out(cdr),.gtwiz_reset_tx_done_out(txdone),.gtwiz_reset_rx_done_out(rxdone),
    .gtwiz_userdata_tx_in(txdata),.gtwiz_userdata_rx_out(rxdata),.gtrefclk00_in(refclk),
    .qpll0outclk_out(),.qpll0outrefclk_out(),.gtyrxn_in(txn),.gtyrxp_in(txp),
    .loopback_in({2{3'b010}}),.rxslide_in(2'b0),.gtpowergood_out(powergood),
    .gtytxn_out(txn),.gtytxp_out(txp),.rxpmaresetdone_out(rxpma),.txpmaresetdone_out(txpma));
  function automatic [63:0] pattern(input integer word_index,input integer lane);
    if(lane==0) pattern=pa0[word_index]; else pattern=pa1[word_index];
  endfunction
  initial begin
    wait(txdone[0] && (&txpma) && txactive[0] && rxdone[0] && (&rxpma) && cdr[0] && rxactive[0]);
    repeat(8) @(posedge txclk[0]);
    @(txp[0]); #(UI/2.0+3.0);
    forever begin
      if(txcount>=MAX_BITS)$fatal(1,"TX capture overflow");
      if((^txp===1'bx)||txn!==~txp)$fatal(1,"TX pins unknown/non-complementary");
      txbits[txcount]=txp;txcount=txcount+1;
      // 14 Gb/s is exactly seven UIs per 500 ps. Alternating integral-fs
      // delays prevents a 1 fs rounded UI from drifting across a long frame.
      if ((txcount % 7)==0 || (txcount % 7)==2 || (txcount % 7)==4) #(71.428);
      else #(71.429);
    end
  end
  initial begin : stimulus
    integer lane,start,k,best[0:1];reg found,match;reg [63:0] expected;
    #200000;reset=0;
    wait(txdone[0] && (&txpma) && txactive[0] && rxdone[0] && (&rxpma) && cdr[0] && rxactive[0]);
    $display("GT_TX_RESET_DONE powergood=%b pma=%b",powergood,txpma);
    $readmemh("phase1_arch2_pa0.mem",pa0);$readmemh("phase1_arch2_pa1.mem",pa1);
    repeat(8) @(negedge txclk[0]); rst_n=1;run_request=1;
    for(int word=0;word<WORDS;word++) begin
      if(word%37==9) begin @(negedge txclk[0]);in_valid=0;repeat(2) @(negedge txclk[0]);end
      @(negedge txclk[0]);in_valid=1;in_start=(word==0);in_end=(word==WORDS-1);
      in_data={128'd0,pa1[word],pa0[word]};if(word==3000)run_request=0;
      do @(posedge txclk[0]);while(!in_ready);
    end
    @(negedge txclk[0]);in_valid=0;in_start=0;in_end=0;
    wait(emitted==WORDS);repeat(128) @(negedge txclk[0]);
    if(!drain_done) $fatal(1,"STOP drain incomplete");
    for(lane=0;lane<2;lane++) begin
      found=0;best[lane]=-1;
      for(start=0;start+WORDS*64<=txcount && !found;start++) begin
        match=1;
        for(k=0;k<128 && match;k++) begin
          expected=pattern(k/64,lane);
          if(txbits[start+k][lane]!==expected[k%64])match=0;
        end
        if(match) begin
          for(k=128;k<WORDS*64 && match;k++) begin
            expected=pattern(k/64,lane);
            if(txbits[start+k][lane]!==expected[k%64])match=0;
          end
          if(match)begin found=1;best[lane]=start;end
        end
      end
      if(!found)$fatal(1,"GT serial bit-true mismatch lane=%0d captured=%0d",lane,txcount);
      begin : dump_serial
        integer fd; reg [63:0] recovered;
        if(lane==0) fd=$fopen("serial_pa0.mem","w"); else fd=$fopen("serial_pa1.mem","w");
        if(!fd) $fatal(1,"cannot open serial capture");
        for(int w=0;w<WORDS;w++) begin
          for(int b=0;b<64;b++) recovered[b]=txbits[best[lane]+w*64+b][lane];
          $fdisplay(fd,"%016h",recovered);
        end
        $fclose(fd);
      end
    end
    $display("GTY_TX_SERIAL_BITTRUE_PASS lanes=2 words=%0d bits_per_lane=%0d starts=%0d,%0d skew_ui=%0d line_rate=14.000Gbps",
      WORDS,WORDS*64,best[0],best[1],best[1]-best[0]);
    for(lane=0;lane<2;lane++) begin
      found=0;best[lane]=-1;
      for(start=0;start+WORDS*64<=rxcount*64 && !found;start++) begin
        match=1;
        for(k=0;k<128 && match;k++) begin
          expected=pattern(k/64,lane);
          if(rxwords[(start+k)/64][lane*64+(start+k)%64]!==expected[k%64])match=0;
        end
        if(match) begin
          for(k=128;k<WORDS*64 && match;k++) begin
            expected=pattern(k/64,lane);
            if(rxwords[(start+k)/64][lane*64+(start+k)%64]!==expected[k%64])match=0;
          end
          if(match)begin found=1;best[lane]=start;end
        end
      end
      if(!found)$fatal(1,"GT RX loopback bit-true mismatch lane=%0d captured_words=%0d",lane,rxcount);
    end
    $display("GTY_RX_LOOPBACK_BITTRUE_PASS lanes=2 words=%0d bits_per_lane=%0d starts=%0d,%0d skew_bits=%0d",WORDS,WORDS*64,best[0],best[1],best[1]-best[0]);
    $finish;
  end
  initial begin #200000000;$fatal(1,"GTY reset or simulation watchdog");end
endmodule
