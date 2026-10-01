// Sole testbench owner of reset, core enable, and common four-plane ready.
class thermo5_control_bfm extends uvm_component;
  `uvm_component_utils(thermo5_control_bfm)
  virtual thermo5_sku_if vif;
  thermo5_sku_config cfg;
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_sku_if)::get(this,"","vif",vif) ||
        !uvm_config_db#(thermo5_sku_config)::get(this,"","cfg",cfg))
      `uvm_fatal("NOCFG","Control BFM requires vif and SKU configuration")
  endfunction
  task run_phase(uvm_phase phase);
    repeat(8) @(negedge vif.src_clk);
    vif.src_rst_n=1'b1;
    repeat(8) @(negedge vif.core_clk);
    vif.core_rst_n=1'b1;
    forever begin
      @(negedge vif.core_clk);
      vif.pa_ready=cfg.random_pa_ready && $urandom_range(0,3)==0 ? 4'h0 : 4'hf;
    end
  endtask
  task core_on();
    @(negedge vif.core_clk); vif.core_enable=1'b1;
  endtask
  task core_off();
    @(negedge vif.core_clk); vif.core_enable=1'b0;
  endtask
  task reset_both();
    // Caller chooses the exact core-clock falling edge (residual-state test).
    vif.core_enable=1'b0;
    vif.core_rst_n=1'b0;
    vif.src_rst_n=1'b0;
    repeat(8) @(negedge vif.src_clk);
    vif.src_rst_n=1'b1;
    repeat(8) @(negedge vif.core_clk);
    vif.core_rst_n=1'b1;
  endtask
endclass
