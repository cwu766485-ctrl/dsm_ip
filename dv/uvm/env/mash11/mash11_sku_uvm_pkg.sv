`timescale 1ns/1ps

package mash11_sku_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class mash11_sku_cfg extends uvm_object;
    `uvm_object_utils(mash11_sku_cfg)
    virtual mash11_sku_if vif;
    string vector_dir;
    int expected_count;
    int expected_stage1[0:8191];
    int expected_stage2[0:8191];
    int expected_level[0:8191];
    int expected_sign[0:8191];
    function new(string name="mash11_sku_cfg"); super.new(name); endfunction
  endclass

  class mash11_item extends uvm_sequence_item;
    `uvm_object_utils(mash11_item)
    bit reset_before;
    bit valid;
    logic signed [15:0] sample;
    function new(string name="mash11_item"); super.new(name); endfunction
  endclass

  class mash11_sequencer extends uvm_sequencer #(mash11_item);
    `uvm_component_utils(mash11_sequencer)
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
  endclass

  class mash11_driver extends uvm_driver #(mash11_item);
    `uvm_component_utils(mash11_driver)
    mash11_sku_cfg cfg;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(mash11_sku_cfg)::get(this,"","cfg",cfg))
        `uvm_fatal("MASH_CFG","MASH driver configuration missing")
    endfunction
    task run_phase(uvm_phase phase);
      mash11_item req;
      forever begin
        seq_item_port.get_next_item(req);
        if (req.reset_before) begin
          @(negedge cfg.vif.clk);
          cfg.vif.in_valid <= 1'b0;
          cfg.vif.rst_n <= 1'b0;
          cfg.vif.sample <= '0;
          repeat (2) @(posedge cfg.vif.clk);
          @(negedge cfg.vif.clk);
          cfg.vif.rst_n <= 1'b1;
        end else begin
          @(negedge cfg.vif.clk);
        end
        cfg.vif.sample <= req.sample;
        cfg.vif.in_valid <= req.valid;
        @(posedge cfg.vif.clk);
        #1ps;
        seq_item_port.item_done();
      end
    endtask
  endclass

  class mash11_agent extends uvm_agent;
    `uvm_component_utils(mash11_agent)
    mash11_sku_cfg cfg;
    mash11_sequencer sequencer;
    mash11_driver driver;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(mash11_sku_cfg)::get(this,"","cfg",cfg))
        `uvm_fatal("MASH_CFG","MASH agent configuration missing")
      sequencer=mash11_sequencer::type_id::create("sequencer",this);
      driver=mash11_driver::type_id::create("driver",this);
      uvm_config_db#(mash11_sku_cfg)::set(this,"driver","cfg",cfg);
    endfunction
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass

  class mash11_vector_sequence extends uvm_sequence #(mash11_item);
    `uvm_object_utils(mash11_vector_sequence)
    string vector_dir;
    function new(string name="mash11_vector_sequence"); super.new(name); endfunction
    task body();
      string stimulus_path;
      integer fd, rc;
      integer reset_before, valid;
      reg [15:0] sample_bits;
      mash11_item item;
      if (!$value$plusargs("MASH_VECTORS=%s", vector_dir))
        `uvm_fatal("MASH_VECTORS","Pass +MASH_VECTORS=<vector directory>")
      stimulus_path=$sformatf("%s/stimulus.csv",vector_dir);
      fd=$fopen(stimulus_path,"r");
      if (!fd) `uvm_fatal("MASH_STIMULUS",$sformatf("Cannot open %s",stimulus_path))
      while (!$feof(fd)) begin
        rc=$fscanf(fd,"%d %d %h\n",reset_before,valid,sample_bits);
        if (rc==3) begin
          item=mash11_item::type_id::create("item");
          start_item(item);
          item.reset_before=reset_before[0];
          item.valid=valid[0];
          item.sample=$signed(sample_bits);
          finish_item(item);
        end else if (rc!=0 && rc!=-1) begin
          $fclose(fd);
          `uvm_fatal("MASH_STIMULUS","Malformed row in MASH stimulus file")
        end
      end
      $fclose(fd);
    endtask
  endclass

  class mash11_scoreboard extends uvm_component;
    `uvm_component_utils(mash11_scoreboard)
    mash11_sku_cfg cfg;
    int checked, bubbles, resets;
    int level_hits[0:6];
    integer trace_fd=0;
    string trace_path;
    bit have_previous;
    logic previous_stage1, previous_stage2;
    logic signed [2:0] previous_level;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      integer fd, rc;
      integer s1, s2, level, sign;
      string expected_path;
      super.build_phase(phase);
      if (!uvm_config_db#(mash11_sku_cfg)::get(this,"","cfg",cfg))
        `uvm_fatal("MASH_CFG","MASH scoreboard configuration missing")
      if ($value$plusargs("MASH_TRACE=%s",trace_path)) begin
        trace_fd=$fopen(trace_path,"w");
        if (trace_fd==0) `uvm_fatal("MASH_TRACE","Cannot open actual RTL trace")
        $fdisplay(trace_fd,"time_ps,transaction,stage1_bit,stage2_bit,combined_level,sign_bit");
      end
      expected_path=$sformatf("%s/expected.csv",cfg.vector_dir);
      fd=$fopen(expected_path,"r");
      if (!fd) `uvm_fatal("MASH_EXPECTED",$sformatf("Cannot open %s",expected_path))
      while (!$feof(fd)) begin
        rc=$fscanf(fd,"%d %d %d %d\n",s1,s2,level,sign);
        if (rc==4) begin
          if (cfg.expected_count>=8192) `uvm_fatal("MASH_EXPECTED","Golden vector exceeds scoreboard capacity")
          cfg.expected_stage1[cfg.expected_count]=s1;
          cfg.expected_stage2[cfg.expected_count]=s2;
          cfg.expected_level[cfg.expected_count]=level;
          cfg.expected_sign[cfg.expected_count]=sign;
          cfg.expected_count++;
        end else if (rc!=0 && rc!=-1) begin
          $fclose(fd);
          `uvm_fatal("MASH_EXPECTED","Malformed row in MASH golden file")
        end
      end
      $fclose(fd);
    endfunction
    task run_phase(uvm_phase phase);
      integer index, observed_level;
      forever begin
        @(posedge cfg.vif.clk);
        #1ps;
        if (!cfg.vif.rst_n) begin
          resets++;
          have_previous=0;
          if (cfg.vif.out_valid)
            `uvm_error("MASH_RESET_VALID","out_valid asserted during reset")
        end else if (cfg.vif.out_valid) begin
          index=checked;
          if (index>=cfg.expected_count) begin
            `uvm_error("MASH_EXTRA","Output transaction exceeded golden count")
          end else begin
            observed_level=$signed(cfg.vif.combined_level);
            if (cfg.vif.stage1_bit!==cfg.expected_stage1[index] ||
                cfg.vif.stage2_bit!==cfg.expected_stage2[index] ||
                observed_level!==cfg.expected_level[index] ||
                (observed_level>=0)!==cfg.expected_sign[index])
              `uvm_error("MASH_MISMATCH",
                $sformatf("index=%0d got=(%0d,%0d,%0d) expected=(%0d,%0d,%0d)",
                  index,cfg.vif.stage1_bit,cfg.vif.stage2_bit,observed_level,
                  cfg.expected_stage1[index],cfg.expected_stage2[index],
                  cfg.expected_level[index]))
            else begin
              if (observed_level>=-3 && observed_level<=3)
                level_hits[observed_level+3]++;
            end
          end
          if (trace_fd!=0)
            $fdisplay(trace_fd,"%0d,%0d,%0d,%0d,%0d,%0d",
              longint'($realtime*1000.0),checked,
              cfg.vif.stage1_bit,cfg.vif.stage2_bit,$signed(cfg.vif.combined_level),
              ($signed(cfg.vif.combined_level)>=0));
          checked++;
          have_previous=1;
          previous_stage1=cfg.vif.stage1_bit;
          previous_stage2=cfg.vif.stage2_bit;
          previous_level=cfg.vif.combined_level;
        end else begin
          bubbles++;
          if (have_previous &&
              (cfg.vif.stage1_bit!==previous_stage1 ||
               cfg.vif.stage2_bit!==previous_stage2 ||
               cfg.vif.combined_level!==previous_level))
            `uvm_error("MASH_IDLE_HOLD","Output payload changed without an enabled sample")
        end
      end
    endtask
    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info("MASH_UVM_COVERAGE",
        $sformatf("checked=%0d expected=%0d bubbles=%0d reset_cycles=%0d levels=[%0d,%0d,%0d,%0d,%0d,%0d,%0d]",
        checked,cfg.expected_count,bubbles,resets,level_hits[0],level_hits[1],
        level_hits[2],level_hits[3],level_hits[4],level_hits[5],level_hits[6]),UVM_NONE)
    endfunction
    function void final_phase(uvm_phase phase);
      super.final_phase(phase);
      if (trace_fd!=0) $fclose(trace_fd);
    endfunction
  endclass

  class mash11_env extends uvm_env;
    `uvm_component_utils(mash11_env)
    mash11_sku_cfg cfg;
    mash11_agent agent;
    mash11_scoreboard scoreboard;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(mash11_sku_cfg)::get(this,"","cfg",cfg))
        `uvm_fatal("MASH_CFG","MASH environment configuration missing")
      agent=mash11_agent::type_id::create("agent",this);
      scoreboard=mash11_scoreboard::type_id::create("scoreboard",this);
      uvm_config_db#(mash11_sku_cfg)::set(this,"agent","cfg",cfg);
      uvm_config_db#(mash11_sku_cfg)::set(this,"scoreboard","cfg",cfg);
    endfunction
  endclass

  class mash11_vector_test extends uvm_test;
    `uvm_component_utils(mash11_vector_test)
    mash11_sku_cfg cfg;
    mash11_env env;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg=mash11_sku_cfg::type_id::create("cfg");
      if (!uvm_config_db#(virtual mash11_sku_if)::get(this,"","vif",cfg.vif))
        `uvm_fatal("MASH_VIF","MASH virtual interface missing")
      if (!$value$plusargs("MASH_VECTORS=%s",cfg.vector_dir))
        `uvm_fatal("MASH_VECTORS","Pass +MASH_VECTORS=<vector directory>")
      uvm_config_db#(mash11_sku_cfg)::set(this,"env","cfg",cfg);
      env=mash11_env::type_id::create("env",this);
    endfunction
    task run_phase(uvm_phase phase);
      mash11_vector_sequence seq;
      phase.raise_objection(this);
      seq=mash11_vector_sequence::type_id::create("seq");
      seq.start(env.agent.sequencer);
      @(negedge cfg.vif.clk);
      cfg.vif.in_valid=1'b0;
      repeat (2) @(posedge cfg.vif.clk);
      #1ps;
      if (env.scoreboard.checked!=cfg.expected_count)
        `uvm_fatal("MASH_COUNT",
          $sformatf("checked %0d of %0d golden outputs",
            env.scoreboard.checked,cfg.expected_count))
      if (env.scoreboard.bubbles==0 || env.scoreboard.resets==0)
        `uvm_fatal("MASH_COVERAGE","Directed stream did not exercise bubbles and reset")
      `uvm_info("MASH_UVM_PASS",
        $sformatf("DSM_V13_MASH11_UVM_PASS accepted=%0d bubbles=%0d",
          env.scoreboard.checked,env.scoreboard.bubbles),UVM_NONE)
      phase.drop_objection(this);
    endtask
  endclass
endpackage
