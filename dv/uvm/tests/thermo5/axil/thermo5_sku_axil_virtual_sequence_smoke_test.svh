class thermo5_sku_axil_virtual_sequence_smoke_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_virtual_sequence_smoke_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function void configure_case();
    super.configure_case();
    cfg.core_words=56;
    cfg.source_beats=32;
    cfg.frame_starts=3;
    cfg.pa_sink_active=UVM_ACTIVE;
  endfunction

  task run_phase(uvm_phase phase);
    thermo5_sku_axil_packet_vseq vseq;
    phase.raise_objection(this);
    vseq=thermo5_sku_axil_packet_vseq::type_id::create("packet_vseq");
    vseq.start(env.virtual_sequencer);
    check_full();
    if (vif.protocol_error || vif.underflow ||
        env.register_predictor.mismatches!=0)
      `uvm_fatal("VSEQ_CHECK",
        $sformatf("protocol=%b underflow=%b predictor_mismatches=%0d",
          vif.protocol_error,vif.underflow,env.register_predictor.mismatches))
    `uvm_info("SKU_PASS",
      "THERMO5_AXIL_VIRTUAL_SEQUENCE_UVM_PASS: AXIS packet, AXI-Lite RUN/STOP, and PA drain coordinated through independent agents",
      UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
