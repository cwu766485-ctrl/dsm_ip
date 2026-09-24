class dsm_axis_driver extends uvm_driver #(dsm_axis_item);
  `uvm_component_utils(dsm_axis_driver)
  virtual dsm_axis_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual dsm_axis_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "AXI-Stream virtual interface is not configured")
  endfunction

  task run_phase(uvm_phase phase);
    dsm_axis_item req;
    int unsigned timeout;
    wait (vif.aresetn === 1'b1);
    vif.tvalid <= 0;
    vif.tdata <= 0;
    vif.tlast <= 0;
    vif.tuser <= 0;
    forever begin
      seq_item_port.get_next_item(req);
      repeat (req.valid_gap_cycles) @(posedge vif.aclk);
      vif.tdata <= {req.q_sample, req.i_sample};
      vif.tlast <= req.last;
      vif.tuser <= req.user_error;
      vif.tvalid <= 1;
      timeout = 0;
      do begin
        @(posedge vif.aclk);
        if (++timeout > 1000)
          `uvm_fatal("AXIS_TIMEOUT", "AXI-Stream ready handshake timed out")
      end while (!vif.tready);
      vif.tvalid <= 0;
      vif.tlast <= 0;
      vif.tuser <= 0;
      seq_item_port.item_done();
    end
  endtask
endclass
