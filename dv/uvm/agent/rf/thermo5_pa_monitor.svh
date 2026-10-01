class thermo5_pa_monitor extends uvm_component;
  `uvm_component_utils(thermo5_pa_monitor)
  virtual thermo5_sku_if vif;
  uvm_analysis_port#(thermo5_pa_word) ap;
  bit stalled = 0;
  logic [63:0] stalled_data[4];
  int stall_cycles = 0;
  function new(string name, uvm_component parent);
    super.new(name,parent); ap=new("ap",this);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_sku_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF","thermo5 monitor interface is missing")
  endfunction
  task run_phase(uvm_phase phase);
    thermo5_pa_word tr;
    forever begin
      @(posedge vif.core_clk);
      if (vif.core_rst_n) begin
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
          tr=thermo5_pa_word::type_id::create("tr");
          for (int p=0;p<4;p++) tr.plane[p]=vif.pa_data[p];
          ap.write(tr);
        end
      end else begin
        stalled=0;
      end
    end
  endtask
endclass
