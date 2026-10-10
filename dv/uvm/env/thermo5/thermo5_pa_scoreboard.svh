class thermo5_pa_scoreboard extends uvm_component;
  `uvm_component_utils(thermo5_pa_scoreboard)
  uvm_analysis_imp_src#(thermo5_source_item,thermo5_pa_scoreboard) source_imp;
  uvm_analysis_imp_pa#(thermo5_pa_word,thermo5_pa_scoreboard) pa_imp;
  virtual thermo5_sku_if vif;
  thermo5_sku_config cfg;
  logic [63:0] expected[4][];
  logic [63:0] loaded_plane[];
  logic [15:0] i_mem[], q_mem[], frame_mem[], gain_mem[];
  int checked, source_checked, reset_epochs;
  function new(string name, uvm_component parent);
    super.new(name,parent);
    source_imp=new("source_imp",this);
    pa_imp=new("pa_imp",this);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_sku_if)::get(this,"","vif",vif) ||
        !uvm_config_db#(thermo5_sku_config)::get(this,"","cfg",cfg))
      `uvm_fatal("NOCFG","Scoreboard requires vif and SKU configuration")
    i_mem=new[cfg.core_words*8]; q_mem=new[cfg.core_words*8];
    frame_mem=new[cfg.core_words]; gain_mem=new[cfg.core_words];
    loaded_plane=new[cfg.core_words];
    $readmemh({cfg.vector_dir,"/tid32_thermo5_frontend_i.mem"},i_mem);
    $readmemh({cfg.vector_dir,"/tid32_thermo5_frontend_q.mem"},q_mem);
    $readmemh({cfg.vector_dir,"/tid32_thermo5_frontend_frame_start.mem"},frame_mem);
    $readmemh({cfg.vector_dir,"/tid32_thermo5_frontend_frame_gain.mem"},gain_mem);
    for (int p=0;p<4;p++) begin
      expected[p]=new[cfg.core_words];
      $readmemh($sformatf("%s/tid32_thermo5_frontend_pa%0d.mem",cfg.vector_dir,p),loaded_plane);
      for (int w=0;w<cfg.core_words;w++) expected[p][w]=loaded_plane[w];
    end
  endfunction
  task run_phase(uvm_phase phase);
    forever begin
      @(negedge vif.core_rst_n);
      checked=0;
      source_checked=0;
      reset_epochs++;
    end
  endtask
  function void write_src(thermo5_source_item tr);
    int sample, core_word;
    bit expected_start;
    if (source_checked>=cfg.source_beats)
      `uvm_fatal("EXTRA_INPUT","Unexpected extra source beat")
    sample=14*source_checked;
    core_word=sample/8;
    expected_start=frame_mem[core_word][0] ||
                   (cfg.illegal_frame && source_checked==1);
    if (tr.frame_start !== expected_start || tr.frame_gain !== gain_mem[core_word])
      `uvm_fatal("SOURCE_META",$sformatf("epoch=%0d beat=%0d frame/gain mismatch",
                  reset_epochs,source_checked))
    for (int lane=0;lane<14;lane++) begin
      if (tr.i_vec[lane*16+:16] !== i_mem[sample+lane] ||
          tr.q_vec[lane*16+:16] !== q_mem[sample+lane])
        `uvm_fatal("SOURCE_DATA",$sformatf("epoch=%0d beat=%0d lane=%0d mismatch",
                   reset_epochs,source_checked,lane))
    end
    source_checked++;
  endfunction
  function void write_pa(thermo5_pa_word tr);
    if (!cfg.expect_pa) return;
    if (checked>=cfg.core_words) `uvm_fatal("EXTRA_WORD","Unexpected extra output word")
    for (int p=0;p<4;p++)
      if (tr.plane[p] !== expected[p][checked])
        `uvm_fatal("BITTRUE",$sformatf("epoch=%0d word=%0d plane=%0d got=%016h expected=%016h",
                   reset_epochs,checked,p,tr.plane[p],expected[p][checked]))
    checked++;
  endfunction
endclass
