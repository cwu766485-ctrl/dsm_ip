// Long legal Product replay that primes the MASH recurrence at the negative
// rail, then changes frames to the positive rail. The independent frontend
// and four-plane scoreboards check every accepted output word.
class thermo5_sku_axil_mash11_rail_history_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_mash11_rail_history_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function void configure_case();
    integer fd;
    integer scan_result;
    logic [15:0] marker;
    string path;
    super.configure_case();
    if (cfg.dsm_arch!=3 || cfg.core_words!=4200 || cfg.source_beats!=2400)
      `uvm_fatal("MASH_RAIL_WORDS",
        "Use the 4200-word MASH rail-history vectors with the MASH Product SKU")
    path=$sformatf("%s/tid32_thermo5_frontend_frame_start.mem",cfg.vector_dir);
    fd=$fopen(path,"r");
    if (fd==0) `uvm_fatal("MASH_RAIL_FRAME_FILE",$sformatf("Cannot open %s",path))
    scan_result=$fscanf(fd,"%h",marker);
    cfg.frame_starts=0;
    while (scan_result==1) begin
      if (marker[0]) cfg.frame_starts++;
      scan_result=$fscanf(fd,"%h",marker);
    end
    $fclose(fd);
    if (scan_result!=-1 || cfg.frame_starts!=3)
      `uvm_fatal("MASH_RAIL_FRAME_COUNT",
        $sformatf("Expected 3 legal frame starts, found %0d",cfg.frame_starts))
  endfunction

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    phase.raise_objection(this);
    fork
      send_source(cfg.source_beats);
      begin
        wait(vif.src_rst_n && vif.core_rst_n);
        wait(env.source.monitor.accepted_beats>=16);
        axil_write(8'h00,32'h1,0,0,resp);
        if (resp!=2'b00)
          `uvm_fatal("MASH_RAIL_RUN","RUN request failed")
        for (int cycles=0;cycles<12000 && env.scoreboard.checked<cfg.core_words;cycles++)
          @(posedge vif.core_clk);
        if (env.scoreboard.checked!=cfg.core_words)
          `uvm_fatal("MASH_RAIL_TIMEOUT",
            $sformatf("Scoreboard drained %0d/%0d words",
              env.scoreboard.checked,cfg.core_words))
        check_full();
        if (env.register_predictor.mismatches!=0)
          `uvm_fatal("MASH_RAIL_AXIL_MISMATCH",
            $sformatf("AXI-Lite predictor mismatches=%0d",
              env.register_predictor.mismatches))
        axil_write(8'h00,32'h0,0,0,resp);
        if (resp!=2'b00)
          `uvm_fatal("MASH_RAIL_STOP","RUN clear failed after the full drain")
        if (!env.unified_scoreboard.check_expected_queues_drained("mash11-rail-history"))
          `uvm_fatal("MASH_RAIL_QUEUE","Independent expected transaction queues did not drain")
        `uvm_info("SKU_PASS",
          "THERMO5_AXIL_MASH11_RAIL_HISTORY_PASS: 4200-word negative-to-positive rail replay bit-true",
          UVM_NONE)
      end
    join
    phase.drop_objection(this);
  endtask
endclass
