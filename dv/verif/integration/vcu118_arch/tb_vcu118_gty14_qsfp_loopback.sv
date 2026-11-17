`timescale 1ps/1fs
module tb_vcu118_gty14_qsfp_loopback;
  localparam integer WORDS=256, MAX_BITS=65536;
  localparam realtime UI=1000.0/14.0;
  reg refclk=0,freeclk=0,reset=1;
  always #4000 refclk=~refclk;
  always #2500 freeclk=~freeclk;
  wire [0:0] txclk,rxclk,txdone,rxdone,txactive,rxactive,cdr;
  wire [1:0] txp,txn,txpma,rxpma,powergood;
  wire [127:0] rxdata;
  reg [127:0] txdata={2{64'haaaaaaaaaaaaaaaa}};
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
  reg [127:0] rxwords[0:2047];
  always @(posedge rxclk[0]) if(rxdone[0] && rxcount<2048) begin
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
    reg [63:0] v;
    begin v=64'h9e3779b97f4a7c15*(word_index+1)+64'hd1b54a32d192ed03*lane;
      v=v^(v>>29);v=v^(v<<17);pattern=v^(v>>31);end
  endfunction
  initial begin
    wait(txdone[0] && (&txpma) && txactive[0] && rxdone[0] && (&rxpma) && cdr[0] && rxactive[0]);
    repeat(8) @(posedge txclk[0]);
    @(txp[0]); #(UI/2.0+3.0);
    forever begin
      if(txcount>=MAX_BITS)$fatal(1,"TX capture overflow");
      if((^txp===1'bx)||txn!==~txp)$fatal(1,"TX pins unknown/non-complementary");
      txbits[txcount]=txp;txcount=txcount+1;#(UI);
    end
  end
  initial begin : stimulus
    integer lane,start,k,best[0:1];reg found,match;reg [63:0] expected;
    #200000;reset=0;
    wait(txdone[0] && (&txpma) && txactive[0] && rxdone[0] && (&rxpma) && cdr[0] && rxactive[0]);
    $display("GT_TX_RESET_DONE powergood=%b pma=%b",powergood,txpma);
    repeat(64) @(negedge txclk[0]);
    for(int word=0;word<WORDS;word++) begin
      @(negedge txclk[0]);txdata={pattern(word,1),pattern(word,0)};
    end
    @(negedge txclk[0]);txdata={2{64'haaaaaaaaaaaaaaaa}};
    repeat(128) @(negedge txclk[0]);
    for(lane=0;lane<2;lane++) begin
      found=0;best[lane]=-1;
      for(start=0;start+WORDS*64<=txcount && !found;start++) begin
        match=1;
        for(k=0;k<WORDS*64 && match;k++) begin
          expected=pattern(k/64,lane);
          if(txbits[start+k][lane]!==expected[k%64])match=0;
        end
        if(match)begin found=1;best[lane]=start;end
      end
      if(!found)$fatal(1,"GT serial bit-true mismatch lane=%0d captured=%0d",lane,txcount);
    end
    $display("GTY_TX_SERIAL_BITTRUE_PASS lanes=2 words=%0d bits_per_lane=%0d starts=%0d,%0d skew_ui=%0d line_rate=14.000Gbps",
      WORDS,WORDS*64,best[0],best[1],best[1]-best[0]);
    for(lane=0;lane<2;lane++) begin
      found=0;best[lane]=-1;
      for(start=0;start+WORDS*64<=rxcount*64 && !found;start++) begin
        match=1;
        for(k=0;k<WORDS*64 && match;k++) begin
          expected=pattern(k/64,lane);
          if(rxwords[(start+k)/64][lane*64+(start+k)%64]!==expected[k%64])match=0;
        end
        if(match)begin found=1;best[lane]=start;end
      end
      if(!found)$fatal(1,"GT RX loopback bit-true mismatch lane=%0d captured_words=%0d",lane,rxcount);
    end
    $display("GTY_RX_LOOPBACK_BITTRUE_PASS lanes=2 words=%0d bits_per_lane=%0d starts=%0d,%0d skew_bits=%0d",WORDS,WORDS*64,best[0],best[1],best[1]-best[0]);
    $finish;
  end
  initial begin #200000000;$fatal(1,"GTY reset or simulation watchdog");end
endmodule
