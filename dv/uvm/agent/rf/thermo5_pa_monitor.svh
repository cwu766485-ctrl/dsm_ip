class thermo5_pa_monitor extends uvm_component;
  `uvm_component_utils(thermo5_pa_monitor)
  virtual thermo5_sku_if vif;
  uvm_analysis_port#(thermo5_pa_word) ap;
  bit stalled = 0;
  logic [63:0] stalled_data[4];
  int stall_cycles = 0;
  int output_gap_cycles = 0;
  int accepted_words = 0;
  int unsigned reset_epoch;
  bit reset_active;
  bit output_started = 0;
  thermo5_sku_config cfg;
  integer trace_fd = 0;
  string trace_path;
  function new(string name, uvm_component parent);
    super.new(name,parent); ap=new("ap",this);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_sku_if)::get(this,"","vif",vif) ||
        !uvm_config_db#(thermo5_sku_config)::get(this,"","cfg",cfg))
      `uvm_fatal("NOVIF","thermo5 monitor interface is missing")
    if ($value$plusargs("PA_TRACE_FILE=%s",trace_path)) begin
      trace_fd=$fopen(trace_path,"w");
      if (trace_fd==0)
        `uvm_fatal("PA_TRACE",$sformatf("Cannot open PA trace %s",trace_path))
      $fdisplay(trace_fd,"time_ps,epoch,word_index,plane0,plane1,plane2,plane3");
    end
  endfunction
  task run_phase(uvm_phase phase);
    thermo5_pa_word tr;
    forever begin
      @(posedge vif.core_clk);
      if (vif.core_rst_n) begin
        reset_active=0;
        if ((vif.pa_valid == 4'h0) && output_started && accepted_words < cfg.core_words) begin
          output_gap_cycles++;
        end
        if (stalled) begin
          if (vif.pa_valid !== 4'hf)
            `uvm_error("STALL_VALID","Output valid dropped during backpressure")
          for (int p=0;p<4;p++)
            if (vif.pa_data[p] !== stalled_data[p])
              `uvm_error("STALL_DATA",$sformatf("plane %0d changed during backpressure",p))
        end
        if (vif.pa_valid !== 4'h0 && vif.pa_valid !== 4'hf)
          `uvm_error("PLANE_VALID",$sformatf("four output valids diverged: %b",vif.pa_valid))
        stalled = (vif.pa_valid == 4'hf && vif.pa_ready != 4'hf);
        if (stalled) begin
          stall_cycles++;
          for (int p=0;p<4;p++) stalled_data[p]=vif.pa_data[p];
        end
        if (vif.pa_valid == 4'hf && vif.pa_ready == 4'hf) begin
          accepted_words++;
          output_started=1;
          tr=thermo5_pa_word::type_id::create("tr");
          tr.epoch=reset_epoch;
          tr.word_index=accepted_words-1;
          for (int p=0;p<4;p++) tr.plane[p]=vif.pa_data[p];
          ap.write(tr);
          if (trace_fd!=0)
            $fdisplay(trace_fd,"%0d,%0d,%0d,%016h,%016h,%016h,%016h",
              longint'($realtime*1000.0),tr.epoch,tr.word_index,
              tr.plane[0],tr.plane[1],tr.plane[2],tr.plane[3]);
        end
      end else begin
        if (!reset_active) reset_epoch++;
        reset_active=1;
        stalled=0;
        output_gap_cycles=0;
        accepted_words=0;
        output_started=0;
      end
    end
  endtask
  function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    if (trace_fd!=0) $fclose(trace_fd);
  endfunction
endclass
