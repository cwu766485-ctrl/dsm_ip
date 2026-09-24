class dsm_rf_monitor extends uvm_monitor;
  `uvm_component_utils(dsm_rf_monitor)
  virtual dsm_rf_if vif;
  uvm_analysis_port #(dsm_rf_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual dsm_rf_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "RF virtual interface is not configured")
  endfunction

  task run_phase(uvm_phase phase);
    dsm_rf_item item;
    wait (vif.aresetn === 1'b1);
    forever begin
      @(posedge vif.aclk);
      if (vif.rf_valid) begin
        item = dsm_rf_item::type_id::create("item");
        item.rf_bit = vif.rf_bit;
        item.rf_signed = vif.rf_signed;
        item.phase = vif.phase_acc_dbg;
        ap.write(item);
      end
    end
  endtask
endclass
