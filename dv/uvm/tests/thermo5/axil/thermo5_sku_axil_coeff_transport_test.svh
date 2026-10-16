class thermo5_sku_axil_coeff_transport_test extends thermo5_sku_axil_config_test;
  `uvm_component_utils(thermo5_sku_axil_coeff_transport_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function int unsigned configured_active_taps();
    return 1;
  endfunction

  virtual function bit [386:0] configured_payload();
    return {3'd1,64'hffff_ffff_ffff_4000,64'hffff_ffff_ffff_0000,
            64'hffff_ffff_ffff_0000,64'hffff_ffff_ffff_0000,
            64'hffff_ffff_ffff_0000,64'hffff_ffff_ffff_0000};
  endfunction

  virtual function bit check_pending_payload();
    return 1;
  endfunction

  virtual function string scenario_pass_message();
    return "THERMO5_AXIL_COEFF_TRANSPORT_UVM_PASS: legal AXI coefficient payload crossed mailbox atomically with inactive taps; 56 four-plane words bit-true";
  endfunction

  virtual task program_dpd_image(output bit [1:0] resp);
    axil_write(8'h08,32'd1,0,0,resp);
    if (resp!=2'b00) `uvm_fatal("AXIL_TAPS","Could not select one active tap")
    for (int word=0; word<12; word++) begin
      bit [7:0] addr;
      bit [31:0] coeff_word;
      addr=8'h10+8'(4*word);
      coeff_word=(word==0) ? 32'hffff_4000 :
                 ((word==2 || word==4 || word==6 || word==8 || word==10) ?
                   32'hffff_0000 : 32'hffff_ffff);
      axil_write(addr,coeff_word,0,0,resp);
      if (resp!=2'b00)
        `uvm_fatal("AXIL_COEFF_TRANSPORT_WRITE",$sformatf("Coefficient write failed addr=%02x",addr))
    end
  endtask
endclass
