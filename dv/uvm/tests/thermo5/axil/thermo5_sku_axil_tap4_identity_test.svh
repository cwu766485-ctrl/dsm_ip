class thermo5_sku_axil_tap4_identity_test extends thermo5_sku_axil_config_test;
  `uvm_component_utils(thermo5_sku_axil_tap4_identity_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function int unsigned configured_active_taps();
    return 4;
  endfunction

  virtual function bit [386:0] configured_payload();
    return {3'd4,64'h0000_0000_0000_4000,64'd0,64'd0,64'd0,64'd0,64'd0};
  endfunction

  virtual function string scenario_pass_message();
    return "THERMO5_AXIL_TAP4_IDENTITY_UVM_PASS: legal MAX_TAPS configuration crossed atomically; all four planes matched the identity bit-true oracle";
  endfunction

  virtual task program_dpd_image(output bit [1:0] resp);
    // Tap 0 remains unity and taps 1..3 remain zero after reset. Selecting all
    // four taps changes the active count but keeps the transfer identity.
    axil_write(8'h08,32'd4,0,0,resp);
    if (resp!=2'b00) `uvm_fatal("AXIL_TAPS","Legal four-tap configuration was rejected")
  endtask
endclass
