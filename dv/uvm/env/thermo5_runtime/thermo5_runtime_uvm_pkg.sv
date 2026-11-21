`timescale 1ns/1ps
package thermo5_runtime_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  class runtime_pa_word extends uvm_sequence_item;
    `uvm_object_utils(runtime_pa_word)
    bit [63:0] data[4];
    bit [3:0] mask;
    bit [1:0] arch;
    bit weighted,frame_start,frame_end,tail;
    bit [15:0] config_id;
    function new(string name="runtime_pa_word");super.new(name);endfunction
  endclass

  class runtime_pa_monitor extends uvm_component;
    `uvm_component_utils(runtime_pa_monitor)
    virtual thermo5_runtime_if vif;
    uvm_analysis_port#(runtime_pa_word) ap;
    int accepted,stall_cycles,partial_stalls;
    function new(string name,uvm_component parent);super.new(name,parent);ap=new("ap",this);endfunction
    function void build_phase(uvm_phase phase);
      if(!uvm_config_db#(virtual thermo5_runtime_if)::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","runtime monitor requires vif")
    endfunction
    task run_phase(uvm_phase phase);
      runtime_pa_word held,current;
      bit stalled=0;
      forever begin
        @(vif.sample);
        if(!vif.sample.core_rst_n) begin stalled=0;continue;end
        if(vif.sample.pa_valid!=0 && vif.sample.pa_valid!==vif.sample.pa_mask)
          `uvm_fatal("ATOMIC_VALID","Runtime PA valid disagrees with active physical mask")
        if(vif.sample.pa_valid!=0) begin
          current=runtime_pa_word::type_id::create("observed");
          for(int p=0;p<4;p++) current.data[p]=vif.sample.pa_data[p];
          current.mask=vif.sample.pa_mask;current.arch=vif.sample.arch;current.weighted=vif.sample.weighted;
          current.frame_start=vif.sample.frame_start;current.frame_end=vif.sample.frame_end;
          current.tail=vif.sample.tail;current.config_id=vif.sample.config_id;
        end
        if(stalled) begin
          if(vif.sample.pa_valid==0 || current.mask!=held.mask || current.arch!=held.arch ||
             current.weighted!=held.weighted || current.frame_start!=held.frame_start ||
             current.frame_end!=held.frame_end || current.tail!=held.tail || current.config_id!=held.config_id)
            `uvm_fatal("STALL_META","Runtime PA contract or metadata changed while stalled")
          for(int p=0;p<4;p++) if(current.data[p]!==held.data[p])
            `uvm_fatal("STALL_DATA","Runtime PA bits changed while stalled")
        end
        stalled=(vif.sample.pa_valid!=0 &&
                 ((vif.sample.pa_ready & vif.sample.pa_mask)!=vif.sample.pa_mask));
        if(stalled) begin
          held=current;stall_cycles++;
          if((vif.sample.pa_ready & vif.sample.pa_mask)!=0) partial_stalls++;
        end else if(vif.sample.pa_valid!=0) begin accepted++;ap.write(current);end
      end
    endtask
  endclass

  class runtime_pa_scoreboard extends uvm_component;
    `uvm_component_utils(runtime_pa_scoreboard)
    uvm_analysis_imp#(runtime_pa_word,runtime_pa_scoreboard) imp;
    bit [63:0] expected[3][4][$];
    int expected_arch=1,expected_config=0,checked=0,words,total_checked,phase_id;
    int capture_fd[4];
    string vector_dir,capture_dir;
    function new(string name,uvm_component parent);super.new(name,parent);imp=new("imp",this);endfunction
    function void build_phase(uvm_phase phase);
      string path;int fd,scan;bit [63:0] value;
      if(!uvm_config_db#(string)::get(this,"","vector_dir",vector_dir) &&
         !$value$plusargs("VEC_DIR=%s",vector_dir)) `uvm_fatal("NOVEC","Pass runtime VEC_DIR")
      if(!uvm_config_db#(int)::get(this,"","core_words",words))
        if(!$value$plusargs("CORE_WORDS=%d",words)) words=56;
      if(!uvm_config_db#(string)::get(this,"","capture_dir",capture_dir))
        void'($value$plusargs("CAP_DIR=%s",capture_dir));
      for(int a=0;a<3;a++) for(int p=0;p<(a==2?2:4);p++) begin
        path=$sformatf("%s/arch%0d_pa%0d.mem",vector_dir,a,p);fd=$fopen(path,"r");
        if(!fd) `uvm_fatal("VECOPEN",path)
        while(!$feof(fd)) begin scan=$fscanf(fd,"%h",value);if(scan==1)expected[a][p].push_back(value);end
        $fclose(fd);
        if(expected[a][p].size()!=words) `uvm_fatal("VECCOUNT",path)
      end
    endfunction
    function void begin_stream(int arch,int config_id,int id);
      for(int p=0;p<4;p++) if(capture_fd[p]) $fclose(capture_fd[p]);
      expected_arch=arch;expected_config=config_id;checked=0;phase_id=id;
      for(int p=0;p<4;p++) begin
        capture_fd[p]=0;
        if(capture_dir!="") capture_fd[p]=$fopen($sformatf("%s/phase%0d_arch%0d_pa%0d.mem",capture_dir,id,arch,p),"w");
      end
    endfunction
    function void write(runtime_pa_word t);
      bit [3:0] mask;
      mask=expected_arch==2 ? 4'h3 : 4'hf;
      if(t.arch!=expected_arch || t.mask!=mask || t.weighted!=(expected_arch==2) ||
         t.config_id!=expected_config || t.tail ||
         t.frame_start!=(checked==0) || t.frame_end!=(checked==words-1))
        `uvm_fatal("RUNTIME_META",$sformatf("phase=%0d word=%0d arch=%0d expected=%0d cfg=%0d/%0d fs=%0b fe=%0b",phase_id,checked,t.arch,expected_arch,t.config_id,expected_config,t.frame_start,t.frame_end))
      if(checked>=words) `uvm_fatal("EXTRA_PA","Duplicate output after complete stream")
      for(int p=0;p<4;p++) begin
        if(mask[p]) begin
          if(t.data[p]!==expected[expected_arch][p][checked])
            `uvm_fatal("RUNTIME_BITTRUE",$sformatf("phase=%0d arch=%0d word=%0d plane=%0d actual=%016h expected=%016h",phase_id,expected_arch,checked,p,t.data[p],expected[expected_arch][p][checked]))
        end else if(t.data[p]!==0) `uvm_fatal("INACTIVE_PLANE","Inactive MASH planes must be zero transport words")
        if(capture_fd[p]) $fdisplay(capture_fd[p],"%016h",t.data[p]);
      end
      checked++;total_checked++;
    endfunction
    function void final_phase(uvm_phase phase);
      for(int p=0;p<4;p++) if(capture_fd[p]) $fclose(capture_fd[p]);
    endfunction
  endclass

  `include "thermo5_runtime_switch_test.svh"
  `include "thermo5_compiletime_bittrue_test.svh"
endpackage
