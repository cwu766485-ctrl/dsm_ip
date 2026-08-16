class dsm_axi_lite_driver extends uvm_driver #(dsm_axi_lite_item);
  `uvm_component_utils(dsm_axi_lite_driver)
  virtual dsm_axi_lite_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual dsm_axi_lite_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "AXI-Lite virtual interface is not configured")
  endfunction

  task run_phase(uvm_phase phase);
    dsm_axi_lite_item req;
    wait (vif.aresetn === 1'b1);
    vif.awvalid <= 0;
    vif.wvalid <= 0;
    vif.arvalid <= 0;
    vif.bready <= 0;
    vif.rready <= 0;
    forever begin
      seq_item_port.get_next_item(req);
      if (req.is_write)
        drive_write(req);
      else
        drive_read(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_write(dsm_axi_lite_item req);
    int unsigned timeout;
    fork
      begin
        repeat (req.addr_delay_cycles) @(posedge vif.aclk);
        vif.awaddr <= req.addr;
        vif.awvalid <= 1;
        timeout = 0;
        do begin
          @(posedge vif.aclk);
          if (++timeout > 1000)
            `uvm_fatal("AXI_TIMEOUT", "AXI-Lite write address handshake timed out")
        end while (!vif.awready);
        vif.awvalid <= 0;
      end
      begin
        int unsigned data_timeout;
        repeat (req.data_delay_cycles) @(posedge vif.aclk);
        vif.wdata <= req.data;
        vif.wstrb <= req.wstrb;
        vif.wvalid <= 1;
        data_timeout = 0;
        do begin
          @(posedge vif.aclk);
          if (++data_timeout > 1000)
            `uvm_fatal("AXI_TIMEOUT", "AXI-Lite write data handshake timed out")
        end while (!vif.wready);
        vif.wvalid <= 0;
      end
    join
    repeat (req.ready_delay_cycles) @(posedge vif.aclk);
    vif.bready <= 1;
    timeout = 0;
    while (!(vif.bvalid && vif.bready)) begin
      @(posedge vif.aclk);
      if (++timeout > 1000)
        `uvm_fatal("AXI_TIMEOUT", "AXI-Lite write response timed out")
    end
    req.resp = vif.bresp;
    @(posedge vif.aclk);
    vif.bready <= 0;
  endtask

  task drive_read(dsm_axi_lite_item req);
    int unsigned timeout;
    repeat (req.addr_delay_cycles) @(posedge vif.aclk);
    vif.araddr <= req.addr;
    vif.arvalid <= 1;
    timeout = 0;
    while (!vif.arready) begin
      @(posedge vif.aclk);
      if (++timeout > 1000)
        `uvm_fatal("AXI_TIMEOUT", "AXI-Lite read address handshake timed out")
    end
    vif.arvalid <= 0;
    repeat (req.ready_delay_cycles) @(posedge vif.aclk);
    vif.rready <= 1;
    timeout = 0;
    while (!(vif.rvalid && vif.rready)) begin
      @(posedge vif.aclk);
      if (++timeout > 1000)
        `uvm_fatal("AXI_TIMEOUT", "AXI-Lite read response timed out")
    end
    req.rdata = vif.rdata;
    req.resp = vif.rresp;
    @(posedge vif.aclk);
    vif.rready <= 0;
  endtask
endclass
