`timescale 1ps/1fs
module tb_vcu118_live_axis_gty;
  localparam integer WORDS=5264, MAX_BITS=1500000;
`ifdef LIVE_CONTIGUOUS
  localparam bit INJECT_BUBBLES=0;
`else
  localparam bit INJECT_BUBBLES=1;
`endif
  localparam realtime UI=1000.0/14.0;
  reg refclk=0,freeclk=0,reset=1;
  always #4000 refclk=~refclk;
  always #2500 freeclk=~freeclk;
  wire [0:0] txclk,rxclk,txdone,rxdone,txactive,rxactive,cdr;
  wire [1:0] txp,txn,txpma,rxpma,powergood;
  wire [127:0] rxdata;
  wire [127:0] txdata;
  reg rst_n=0;
  wire run_request,in_valid,in_start,in_end,in_tail;
  wire [255:0] in_data;
  reg srcclk=0,axilclk=0,src_rst_n=0,axil_rst_n=0;
  always #4000 srcclk=~srcclk;
  always #5000 axilclk=~axilclk;
  reg src_valid=0,src_start=0,src_last=0;
  reg signed [223:0] src_i=0,src_q=0;
  wire src_ready,src_full,underflow,protocol_error,tx_active;
  wire pipe_valid,pipe_ready,pipe_start,pipe_last,source_prefill_fault;
  wire signed [223:0] pipe_i,pipe_q;
  wire signed [15:0] pipe_gain;
`ifdef SOURCE_PREFILL
  thermo5_axis_frame_prefill #(.MAX_BEATS(3008)) input_buffer(
    .clk(srcclk),.rst_n(src_rst_n),.in_valid(src_valid),.in_ready(src_ready),
    .in_i(src_i),.in_q(src_q),.in_start(src_start),.in_last(src_last),.in_gain(16'sd16384),
    .out_valid(pipe_valid),.out_ready(pipe_ready),.out_i(pipe_i),.out_q(pipe_q),
    .out_start(pipe_start),.out_last(pipe_last),.out_gain(pipe_gain),
    .protocol_fault(source_prefill_fault),.frame_occupied());
`else
  assign src_ready=pipe_ready;assign pipe_valid=src_valid;assign pipe_i=src_i;assign pipe_q=src_q;
  assign pipe_start=src_start;assign pipe_last=src_last;assign pipe_gain=16'sd16384;
  assign source_prefill_fault=0;
`endif
  reg [7:0] awaddr=0,araddr=0;
  reg awvalid=0,wvalid=0,bready=0,arvalid=0,rready=0;
  reg [31:0] wdata=0; wire [31:0] rdata;
  wire awready,wready,bvalid,arready,rvalid;wire [1:0] bresp,rresp;
  wire [3:0] pa_valid,pa_ready,pa_mask;wire [63:0] pa_data[0:3];
  wire [1:0] arch;wire weighted,mode_busy,frame_start,frame_end,tail;
  wire [15:0] config_id;wire cfg_busy,cfg_done,cfg_error;
  reg [15:0] source_i[0:42111],source_q[0:42111];
  assign in_valid=pa_valid==4'h3;assign in_start=frame_start;assign in_end=frame_end;assign in_tail=tail;
  assign in_data={pa_data[3],pa_data[2],pa_data[1],pa_data[0]};
  assign pa_ready=in_ready ? 4'hf : 4'h0;
  tid32_thermo5_runtime_tx #(.FPGA_USE_XPM_FIFO(1'b1)) live (
    .s_axil_aclk(axilclk),.s_axil_aresetn(axil_rst_n),
    .s_axil_awaddr(awaddr),.s_axil_awvalid(awvalid),.s_axil_awready(awready),
    .s_axil_wdata(wdata),.s_axil_wstrb(4'hf),.s_axil_wvalid(wvalid),.s_axil_wready(wready),
    .s_axil_bresp(bresp),.s_axil_bvalid(bvalid),.s_axil_bready(bready),
    .s_axil_araddr(araddr),.s_axil_arvalid(arvalid),.s_axil_arready(arready),
    .s_axil_rdata(rdata),.s_axil_rresp(rresp),.s_axil_rvalid(rvalid),.s_axil_rready(rready),
    .s_axis_aclk(srcclk),.s_axis_aresetn(src_rst_n),.s_axis_tvalid(pipe_valid),.s_axis_tready(pipe_ready),
    .s_axis_i_vec(pipe_i),.s_axis_q_vec(pipe_q),.s_axis_tuser_frame_start(pipe_start),
    .s_axis_tlast(pipe_last),.s_axis_tuser_frame_gain(pipe_gain),.s_axis_fifo_full(src_full),
    .core_clk(txclk[0]),.core_aresetn(rst_n),.core_underflow(underflow),.core_protocol_error(protocol_error),
    .core_run_request(run_request),.core_tx_active(tx_active),
    .pa_valid(pa_valid),.pa_ready(pa_ready),.pa_data(pa_data),.cfg_busy(cfg_busy),.cfg_done(cfg_done),.cfg_error(cfg_error),
    .active_dsm_arch(arch),.pa_contract_weighted(weighted),.pa_channel_mask(pa_mask),.dsm_switch_busy(mode_busy),
    .pa_frame_start(frame_start),.pa_frame_end(frame_end),.pa_tail(tail),.pa_config_id(config_id));
  reg [63:0] pa0[0:WORDS-1],pa1[0:WORDS-1];
  wire in_ready,drain_done,fault,overflow,link_fault,out_start,out_end,out_tail;
  wire [255:0] gt_data; wire [3:0] out_mask;
  wire [15:0] out_cfg,out_epoch; wire [1:0] out_arch;
  integer sent=0, emitted=0, source_sent=0;
  reg underflow_seen=0;
  always @(posedge txclk[0]) if (rst_n && underflow && !underflow_seen) begin
    underflow_seen=1;
    $display("LIVE_FIRST_UNDERFLOW time_ps=%0t source_beats=%0d accepted_pa_words=%0d run=%b",$time,source_sent,sent,run_request);
  end
  reg final_drain_ok,final_underflow,final_protocol;
  assign txdata=gt_data[127:0];
  thermo5_frame_prefill_tx #(.MAX_FRAME_WORDS(WORDS)) buffer (
    .clk(txclk[0]), .rst_n(rst_n), .run_request(run_request), .link_ready(txdone[0]),
    .in_valid(in_valid),.in_ready(in_ready),.in_data(in_data),.in_mask(pa_mask),.in_arch(arch),
    .in_start(in_start),.in_end(in_end),.in_tail(in_tail),.in_config_id(config_id),.in_epoch(16'h0000),
    .gt_data(gt_data),.pa_enable_mask(out_mask),.out_start(out_start),.out_end(out_end),.out_tail(out_tail),
    .out_arch(out_arch),.out_config_id(out_cfg),.out_epoch(out_epoch),.drain_done(drain_done),
    .protocol_fault(fault),.frame_overflow(overflow),.link_fault(link_fault));
  always @(posedge txclk[0]) if(rst_n) begin
    if(in_valid && in_ready) sent=sent+1;
    if(out_mask!=0) begin
      if(sent!=WORDS || out_mask!==4'h3 || out_arch!==2 || out_cfg!==16'h0001 || out_epoch!==16'h0000 ||
         out_start!==(emitted==0) || out_end!==(emitted==WORDS-1) || out_tail!==1'b0 ||
         gt_data[63:0]!==pa0[emitted] || gt_data[127:64]!==pa1[emitted])
        $fatal(1,"prefill data/metadata mismatch word=%0d",emitted);
      emitted=emitted+1;
    end
    if(fault || overflow || link_fault || source_prefill_fault) $fatal(1,"prefill fault");
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
  reg [127:0] rxwords[0:23999];
  always @(posedge rxclk[0]) if(rxdone[0] && rxcount<24000) begin
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
  task automatic write_reg(input [7:0] addr,input [31:0] data);
    fork
      begin @(negedge axilclk);awaddr=addr;awvalid=1;do @(posedge axilclk);while(!awready);@(negedge axilclk);awvalid=0;end
      begin @(negedge axilclk);wdata=data;wvalid=1;do @(posedge axilclk);while(!wready);@(negedge axilclk);wvalid=0;end
    join
    wait(bvalid);if(bresp!==0)$fatal(1,"AXIL write failed");
    @(negedge axilclk);bready=1;@(posedge axilclk);@(negedge axilclk);bready=0;
  endtask
  initial begin : stimulus
    integer lane,start,k,best[0:1];reg found,match;reg [63:0] expected;
    #200000;reset=0;
    wait(txdone[0] && (&txpma) && txactive[0] && rxdone[0] && (&rxpma) && cdr[0] && rxactive[0]);
    $display("GT_TX_RESET_DONE powergood=%b pma=%b",powergood,txpma);
    $readmemh("arch2_pa0.mem",pa0);$readmemh("arch2_pa1.mem",pa1);
    $readmemh("axis_i_samples.mem",source_i);$readmemh("axis_q_samples.mem",source_q);
    repeat(8) @(negedge txclk[0]);rst_n=1;src_rst_n=1;axil_rst_n=1;
    repeat(10) @(negedge axilclk);write_reg(8'h40,2);
    wait(arch==2 && !mode_busy);write_reg(8'h00,1);
    fork
      begin
        for(int beat=0;beat<3008;beat++) begin
          if(INJECT_BUBBLES && beat%37==9) begin @(negedge srcclk);src_valid=0;repeat(2) @(negedge srcclk);end
          @(negedge srcclk);src_valid=1;src_start=(beat==0);src_last=(beat==3007);
          for(int l=0;l<14;l++) begin src_i[l*16+:16]=source_i[beat*14+l];src_q[l*16+:16]=source_q[beat*14+l];end
          do @(posedge srcclk);while(!src_ready);source_sent=source_sent+1;
        end
        @(negedge srcclk);src_valid=0;src_start=0;src_last=0;
      end
      begin wait(sent>=16);write_reg(8'h00,0);end
    join
    wait(emitted==WORDS);repeat(128) @(negedge txclk[0]);
    final_drain_ok=drain_done;final_underflow=underflow;final_protocol=protocol_error;
    $display("LIVE_DRAIN_DIAGNOSTIC drain=%b underflow=%b protocol=%b sent=%0d emitted=%0d",drain_done,underflow,protocol_error,sent,emitted);
    $display("LIVE_AXIS_PA_PREFILL_PASS words=%0d frame_config_id=1 stop_during_frame=1",WORDS);
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
    if(!final_drain_ok || final_underflow || final_protocol)
      $fatal(1,"live drain/underflow/protocol failure drain=%b underflow=%b protocol=%b",final_drain_ok,final_underflow,final_protocol);
    $finish;
  end
  initial begin #200000000;$fatal(1,"GTY reset or simulation watchdog");end
endmodule
