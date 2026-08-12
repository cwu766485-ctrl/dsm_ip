class dsm_axis_monitor extends uvm_monitor;
  `uvm_component_utils(dsm_axis_monitor)
  virtual dsm_axis_if vif;
  uvm_analysis_port #(dsm_axis_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual dsm_axis_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "AXI-Stream monitor virtual interface is not configured")
  endfunction

  task run_phase(uvm_phase phase);
    dsm_axis_item item;
    forever begin
      @(posedge vif.aclk);
      if (vif.aresetn && vif.tvalid && vif.tready) begin
        item = dsm_axis_item::type_id::create("item");
        item.i_sample = vif.tdata[15:0];
        item.q_sample = vif.tdata[31:16];
        item.last = vif.tlast;
        item.user_error = vif.tuser;
        ap.write(item);
      end
    end
  endtask
endclass
