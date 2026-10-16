// Deliberate protocol-negative test for the AXI-Lite-controlled integration.
// The RTL $error is expected and is checked by the dedicated Make target;
// this test also checks sticky-error recovery through the public reset.
class thermo5_sku_axil_illegal_frame_test extends thermo5_sku_axil_config_test;
  `uvm_component_utils(thermo5_sku_axil_illegal_frame_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function void configure_case();
    super.configure_case();
    cfg.illegal_frame=1'b1;
    cfg.expect_pa=0;
  endfunction

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(cfg.source_beats,1'b1);
          begin
            wait(env.source.monitor.accepted_beats>=4);
            axil_write(8'h00,32'h1,0,0,resp);
            if (resp!=2'b00)
              `uvm_fatal("AXIL_NEG_RUN","Could not start AXI-Lite-controlled negative stream")
            wait(vif.protocol_error===1'b1);
            repeat(2) @(posedge vif.core_clk);
            if (env.coverage.protocol_error_cycles==0)
              `uvm_fatal("AXIL_NEG_COVERAGE","Illegal-frame functional bin was not sampled")
            `uvm_info("NEGATIVE","THERMO5_AXIL_ILLEGAL_FRAME_OBSERVED; expected RTL assertion must also appear",UVM_NONE)
            wait(env.source.monitor.accepted_beats==cfg.source_beats);
            axil_write(8'h00,32'd0,0,0,resp);
            if (resp!=2'b00)
              `uvm_fatal("AXIL_NEG_STOP","Could not stop after illegal-frame detection")
            env.control.reset_both();
            wait_axil_reset_release();
            if (vif.protocol_error!==1'b0)
              `uvm_fatal("AXIL_NEG_RESET","Public reset did not clear sticky protocol error")
            `uvm_info("SKU_PASS","THERMO5_AXIL_ILLEGAL_FRAME_UVM_PASS sticky error cleared by public reset",UVM_NONE)
          end
        join
      end
      begin
        repeat(10000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","AXI-Lite illegal-frame scenario did not complete")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
