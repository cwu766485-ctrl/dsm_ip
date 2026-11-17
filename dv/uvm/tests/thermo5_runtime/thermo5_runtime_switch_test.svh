class thermo5_runtime_switch_test extends uvm_test;
  `uvm_component_utils(thermo5_runtime_switch_test)
  virtual thermo5_runtime_if vif;
  runtime_pa_monitor monitor;
  runtime_pa_scoreboard scoreboard;
  bit [15:0] source_i[],source_q[];
  int source_beats=32,words=56,sent,phase_index,mode_config=0;
  bit allow_remaining=0,force_block=0,sink_enabled=1;
  int negative_checks,switch_count,reset_count;
  bit transition_hit[3][3];
  int accepted_arch[3];
  function new(string name,uvm_component parent);super.new(name,parent);endfunction
  function void build_phase(uvm_phase phase);
    string dir;
    if(!uvm_config_db#(virtual thermo5_runtime_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","runtime test requires vif")
    void'($value$plusargs("SOURCE_BEATS=%d",source_beats));
    void'($value$plusargs("CORE_WORDS=%d",words));
    if(source_beats%32!=0 || words!=source_beats*14/8) `uvm_fatal("SHAPE","runtime packets require 32-beat quanta")
    if(!$value$plusargs("VEC_DIR=%s",dir)) `uvm_fatal("NOVEC","Pass VEC_DIR")
    source_i=new[source_beats*14];source_q=new[source_beats*14];
    $readmemh({dir,"/axis_i_samples.mem"},source_i);
    $readmemh({dir,"/axis_q_samples.mem"},source_q);
    uvm_config_db#(virtual thermo5_runtime_if)::set(this,"*","vif",vif);
    monitor=runtime_pa_monitor::type_id::create("monitor",this);
    scoreboard=runtime_pa_scoreboard::type_id::create("scoreboard",this);
  endfunction
  function void connect_phase(uvm_phase phase);monitor.ap.connect(scoreboard.imp);endfunction
  task write_reg(bit[7:0] addr,bit[31:0] data,output bit[1:0] response,
                 input bit[3:0] strobe=4'hf,input int aw_delay=0,input int w_delay=0,input int b_hold=0);
    fork
      begin
        repeat(aw_delay) @(negedge vif.axil_clk);
        @(negedge vif.axil_clk);vif.awaddr=addr;vif.awvalid=1;
        do @(posedge vif.axil_clk);while(!vif.awready);
        @(negedge vif.axil_clk);vif.awvalid=0;
      end
      begin
        repeat(w_delay) @(negedge vif.axil_clk);
        @(negedge vif.axil_clk);vif.wdata=data;vif.wstrb=strobe;vif.wvalid=1;
        do @(posedge vif.axil_clk);while(!vif.wready);
        @(negedge vif.axil_clk);vif.wvalid=0;
      end
    join
    wait(vif.bvalid);response=vif.bresp;
    repeat(b_hold) begin
      @(negedge vif.axil_clk);
      if(!vif.bvalid || vif.bresp!==response) `uvm_fatal("B_HOLD","AXI-Lite B response changed under backpressure")
    end
    @(negedge vif.axil_clk);vif.bready=1;
    @(posedge vif.axil_clk);
    @(negedge vif.axil_clk);vif.bready=0;
  endtask
  task read_reg(bit[7:0] addr,output bit[31:0] data);
    @(negedge vif.axil_clk);vif.araddr=addr;vif.arvalid=1;
    do @(posedge vif.axil_clk);while(!vif.arready);
    @(negedge vif.axil_clk);vif.arvalid=0;vif.rready=1;
    do @(posedge vif.axil_clk);while(!vif.rvalid);
    data=vif.rdata;
    if(vif.rresp!=0) `uvm_fatal("RRESP","Runtime register read failed")
    @(negedge vif.axil_clk);vif.rready=0;
  endtask
  task expect_write(bit[7:0] addr,bit[31:0] data,bit[1:0] expected,
                    input bit[3:0] strobe=4'hf,input int aw_delay=0,input int w_delay=0,input int b_hold=0);
    bit[1:0] response;
    write_reg(addr,data,response,strobe,aw_delay,w_delay,b_hold);
    if(response!==expected) `uvm_fatal("BRESP",$sformatf("addr=%02h data=%08h response=%0d expected=%0d",addr,data,response,expected))
    if(expected!=0)negative_checks++;
  endtask
  task wait_mode_done(int expected_arch,bit expect_error=0);
    bit[31:0] status;bit done;
    done=0;
    repeat(200) begin
      read_reg(8'h44,status);
      if(!status[8]) begin done=1;break;end
    end
    if(!done || status[1:0]!=expected_arch || status[10]!=expect_error || status[9]===expect_error)
      `uvm_fatal("MODE_STATUS",$sformatf("status=%08h expected_arch=%0d error=%b",status,expected_arch,expect_error))
    read_reg(8'h40,status);
    if(status[1:0]!=expected_arch) `uvm_fatal("MODE_READBACK","Mode readback not coherent with completed handshake")
    if(vif.arch!=expected_arch) `uvm_fatal("CORE_MODE","Core selected another architecture")
  endtask
  task select_mode(int previous_arch,int target,bit test_busy=0);
    expect_write(8'h40,target,0,4'hf,1,0,2);
    if(test_busy) begin
      expect_write(8'h00,1,2'b10);
      expect_write(8'h04,4,0);
    end
    wait_mode_done(target);
    mode_config++;switch_count++;transition_hit[previous_arch][target]=1;
  endtask
  task send_stream(bit boot_prefix=0,int limit=-1);
    int count;
    count=limit<0 ? source_beats : limit;
    sent=0;
    for(int b=0;b<count;b++) begin
      if(boot_prefix && b==4) begin
        @(negedge vif.src_clk);vif.src_valid=0;
        wait(allow_remaining);
      end
      // Gap occurs after STOP request, while the legal packet is draining.
      if(b==20) begin
        @(negedge vif.src_clk);vif.src_valid=0;
        repeat(3) @(negedge vif.src_clk);
      end
      @(negedge vif.src_clk);vif.src_valid=1;vif.src_start=(b==0);
      vif.src_last=(b==source_beats-1);
      for(int l=0;l<14;l++) begin
        vif.src_i[l*16+:16]=source_i[b*14+l];vif.src_q[l*16+:16]=source_q[b*14+l];
      end
      do @(posedge vif.src_clk);while(!vif.src_ready);
      sent++;
    end
    @(negedge vif.src_clk);vif.src_valid=0;vif.src_start=0;vif.src_last=0;
  endtask
  task finish_stream(int expected_arch,bit long_stall=0);
    bit[31:0] status;bit drained;
    wait(sent>=16);
    expect_write(8'h00,0,0);
    if(long_stall) begin
      repeat(400) @(negedge vif.core_clk);
      if(!vif.tx_active || !vif.pa_valid) `uvm_fatal("DRAIN_STALL","STOP incorrectly discarded blocked PA work")
      expect_write(8'h40,0,2'b10);
      force_block=0;
    end
    wait(scoreboard.checked==words);
    drained=0;
    repeat(300) begin
      read_reg(8'h04,status);
      if(status[4:3]==0 && !vif.tx_active) begin drained=1;break;end
    end
    if(!drained || sent!=source_beats || vif.protocol_error || vif.underflow)
      `uvm_fatal("DRAIN",$sformatf("sent=%0d/%0d active=%b status=%h protocol=%b underflow=%b",sent,source_beats,vif.tx_active,status,vif.protocol_error,vif.underflow))
    accepted_arch[expected_arch]++;
    `uvm_info("RUNTIME_STREAM_PASS",$sformatf("phase=%0d arch=%0d words=%0d cfg=%0d",phase_index,expected_arch,words,mode_config),UVM_NONE)
  endtask
  task reset_all();
    @(negedge vif.core_clk);vif.src_rst_n=0;vif.core_rst_n=0;vif.axil_rst_n=0;
    vif.src_valid=0;vif.awvalid=0;vif.wvalid=0;vif.bready=0;vif.arvalid=0;vif.rready=0;
    repeat(6) @(negedge vif.src_clk);
    vif.src_rst_n=1;
    repeat(4) @(negedge vif.core_clk);vif.core_rst_n=1;
    repeat(3) @(negedge vif.axil_clk);vif.axil_rst_n=1;
    repeat(4) @(negedge vif.core_clk);
  endtask
  task run_phase(uvm_phase phase);
    int mode_sequence[7]='{1,2,0,2,1,0,1};
    bit[31:0] value;
    phase.raise_objection(this);
    fork
      begin
        int cycle=0;
        forever begin
          @(negedge vif.core_clk);cycle++;
          if(force_block || !sink_enabled) vif.pa_ready=0;
          else if(vif.weighted) begin
            case(cycle%5)
              0:vif.pa_ready=4'h1;
              1:vif.pa_ready=4'h2;
              default:vif.pa_ready=4'h3;
            endcase
          end else begin
            case(cycle%5)
              0:vif.pa_ready=4'he;
              1:vif.pa_ready=0;
              default:vif.pa_ready=4'hf;
            endcase
          end
        end
      end
    join_none
    reset_all();
    read_reg(8'h0c,value);if(value!=32'h54483502) `uvm_fatal("ID","Not the runtime product register map")
    read_reg(8'h40,value);if(value!=1) `uvm_fatal("RESET_MODE","Reset must select EF2")
    expect_write(8'h40,3,2'b10);
    expect_write(8'h40,2,0,4'h0);
    read_reg(8'h40,value);if(value!=1) `uvm_fatal("WSTRB","Zero byte strobe changed architecture")
    // Accepted request with already queued boot data must reject in the core,
    // leave the selected architecture unchanged, and retain all source data.
    scoreboard.begin_stream(1,0,0);
    fork
      send_stream(1);
      begin
        wait(sent==4);repeat(3) @(negedge vif.src_clk);
        expect_write(8'h40,2,0);
        wait_mode_done(1,1);negative_checks++;
        if(vif.pa_valid) `uvm_fatal("PREFILL","Data emitted before RUN")
        allow_remaining=1;
        expect_write(8'h00,1,0);
        wait(sent>=10);expect_write(8'h40,2,2'b10);
        finish_stream(1);
      end
    join
    for(int n=1;n<7;n++) begin
      phase_index=n;
      select_mode(mode_sequence[n-1],mode_sequence[n],n==1);
      scoreboard.begin_stream(mode_sequence[n],mode_config,n);
      force_block=(n==1);
      fork
        send_stream();
        begin expect_write(8'h00,1,0);finish_stream(mode_sequence[n],n==1);end
      join
    end
    // Reset with accepted source prefix and blocked output. The next complete
    // stream must start at default EF2 with no old mode/config/payload leakage.
    phase_index=7;
    `uvm_info("RESET_STAGE","select MASH for blocked-PA reset",UVM_NONE)
    select_mode(1,2);
    `uvm_info("RESET_STAGE","MASH mode acknowledged",UVM_NONE)
    scoreboard.begin_stream(2,mode_config,7);force_block=1;
    fork
      begin
        repeat(300) @(posedge vif.core_clk);
        if(phase_index==7 && sent<32)
          `uvm_fatal("RESET_SOURCE_TIMEOUT",$sformatf("sent=%0d run=%b active=%b arch=%0d src=%b/%b pa=%h/%h busy=%b protocol=%b underflow=%b",sent,vif.run_request,vif.tx_active,vif.arch,vif.src_valid,vif.src_ready,vif.pa_valid,vif.pa_ready,vif.mode_busy,vif.protocol_error,vif.underflow))
      end
    join_none
    fork
      send_stream(0,32);
      begin expect_write(8'h00,1,0);end
    join
    `uvm_info("RESET_STAGE",$sformatf("source prefix sent=%0d valid=%h active=%b",sent,vif.pa_valid,vif.tx_active),UVM_NONE)
    repeat(200) begin
      @(negedge vif.core_clk);
      if(vif.pa_valid==4'h3) break;
    end
    if(vif.pa_valid!=4'h3) `uvm_fatal("RESET_SETUP_PA",$sformatf("No blocked PA before reset: sent=%0d active=%b arch=%0d valid=%h ready=%h underflow=%b",sent,vif.tx_active,vif.arch,vif.pa_valid,vif.pa_ready,vif.underflow))
    repeat(3) @(negedge vif.core_clk);
    if(!vif.tx_active) `uvm_fatal("RESET_SETUP","No live work before reset")
    reset_all();reset_count++;mode_config=0;force_block=0;
    scoreboard.begin_stream(1,0,8);phase_index=8;
    read_reg(8'h40,value);if(value!=1) `uvm_fatal("RESET_MODE","Reset did not restore EF2")
    fork
      send_stream();
      begin expect_write(8'h00,1,0);finish_stream(1);end
    join
    for(int a=0;a<3;a++) for(int b=0;b<3;b++) if(a!=b && !transition_hit[a][b])
      `uvm_fatal("MODE_COVERAGE",$sformatf("missing transition %0d -> %0d",a,b))
    if(monitor.stall_cycles<400 || monitor.partial_stalls==0 || reset_count!=1 || negative_checks<5)
      `uvm_fatal("CONTROL_COVERAGE","Required controls not exercised")
    `uvm_info("RUNTIME_PRODUCT_PASS",$sformatf("words=%0d streams=%0d transitions=6/6 negative=%0d stalls=%0d partial=%0d reset=%0d",
      scoreboard.total_checked,accepted_arch[0]+accepted_arch[1]+accepted_arch[2],negative_checks,monitor.stall_cycles,monitor.partial_stalls,reset_count),UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
