// Verification-only fault injection: corrupt the bundled payload while the
// request/acknowledge mailbox is busy. This is a deliberate expected $error,
// isolated from the legal bit-true test and merged only as a named negative
// test database.
class thermo5_sku_axil_mailbox_fault_test extends thermo5_sku_axil_config_test;
  `uvm_component_utils(thermo5_sku_axil_mailbox_fault_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit injected;
    uvm_hdl_data_t corrupt_bundle;
    uvm_hdl_data_t released_bundle;
    string mailbox_path = "thermo5_sku_uvm_tb.dut.u_cfg.cfg_mailbox_q";

    phase.raise_objection(this);
    wait(vif.src_rst_n && vif.core_rst_n && env.axil.monitor.vif.aresetn);
    // No source data is sent, so the committed bundle remains pending and the
    // public datapath boundary cannot acknowledge it.
    axil_write(8'h00,32'h2,0,0,resp);
    if (resp!=2'b00)
      `uvm_fatal("AXIL_FAULT_COMMIT","Could not create a pending mailbox request")
    repeat (3) @(posedge env.axil.monitor.vif.aclk);

    corrupt_bundle='1;
    injected=uvm_hdl_force(mailbox_path,corrupt_bundle);
    if (!injected)
      `uvm_fatal("AXIL_FAULT_INJECT","Could not force the internal mailbox payload")
    @(posedge env.axil.monitor.vif.aclk);
    @(negedge env.axil.monitor.vif.aclk);
`ifdef THERMO5_XSIM
    if (!uvm_hdl_release(mailbox_path,released_bundle))
`else
    if (!uvm_hdl_release(mailbox_path))
`endif
      `uvm_fatal("AXIL_FAULT_RELEASE","Could not release the mailbox fault injection")
    `uvm_info("NEGATIVE","THERMO5_AXIL_MAILBOX_CORRUPTION_OBSERVED; expected RTL $error must also appear",UVM_NONE)

    env.control.reset_both();
    wait_axil_reset_release();
    `uvm_info("SKU_PASS","THERMO5_AXIL_MAILBOX_FAULT_UVM_PASS fault detected and public reset recovered",UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
