// Full-chain oracle test for a four-tap non-identity polynomial DPD image.
// Run with centered-cubic RTL and vectors generated using
// --dpd-profile nonlinear_test_4tap. CORE_WORDS=56 covers one short packet;
// 112 covers two consecutive one-quantum packets and their frame tails.
class thermo5_sku_axil_nonlinear_tap4_bittrue_test extends thermo5_sku_axil_nonlinear_bittrue_test;
  `uvm_component_utils(thermo5_sku_axil_nonlinear_tap4_bittrue_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function int unsigned configured_active_taps();
    return 4;
  endfunction

  virtual function bit [386:0] configured_payload();
    return {3'd4,64'h0100_0200_0400_4000,64'd0,
            64'h0080_ff00_0200_0800,64'd0,64'd0,64'd0};
  endfunction

  virtual function string scenario_pass_message();
    return $sformatf("THERMO5_AXIL_NONLINEAR_TAP4_BITTRUE_UVM_PASS: four-tap polynomial DPD image matched all four planes across %0d packet(s), %0d frame(s)",
                     expected_tlast_count,cfg.frame_starts);
  endfunction

  virtual task program_dpd_image(output bit [1:0] resp);
    axil_write(8'h08,32'd4,0,0,resp);
    if (resp!=2'b00) `uvm_fatal("AXIL_TAPS","Could not select four active DPD taps")
    for (int word=0; word<12; word++) begin
      bit [7:0] addr;
      bit [31:0] coeff_word;
      addr=8'h10+8'(4*word);
      case (word)
        0: coeff_word=32'h0400_4000; // c1_re taps 0 and 1
        1: coeff_word=32'h0100_0200; // c1_re taps 2 and 3
        4: coeff_word=32'h0200_0800; // c3_re taps 0 and 1
        5: coeff_word=32'h0080_ff00; // c3_re taps 2 and 3
        default: coeff_word=32'd0;
      endcase
      axil_write(addr,coeff_word,0,0,resp);
      if (resp!=2'b00)
        `uvm_fatal("AXIL_NONLINEAR_COEFF_WRITE",
          $sformatf("Coefficient write failed addr=%02x",addr))
    end
  endtask
endclass
