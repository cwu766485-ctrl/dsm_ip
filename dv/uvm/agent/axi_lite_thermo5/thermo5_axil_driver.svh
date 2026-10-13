class thermo5_axil_driver extends uvm_driver #(thermo5_axil_item);
  `uvm_component_utils(thermo5_axil_driver)
  virtual thermo5_axil_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_axil_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Thermo5 AXI-Lite virtual interface is missing")
  endfunction

  task run_phase(uvm_phase phase);
    thermo5_axil_item req;
    wait (vif.aresetn === 1'b1);
    forever begin
      seq_item_port.get_next_item(req);
      if (req.is_write) drive_write(req);
      else drive_read(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_write(thermo5_axil_item req);
    int unsigned timeout;
    @(negedge vif.aclk);
    vif.bready <= req.ready_before_response;
    fork
      begin
        repeat (req.aw_delay) @(negedge vif.aclk);
        vif.awaddr <= req.addr;
        vif.awvalid <= 1'b1;
        timeout = 0;
        do begin
          @(posedge vif.aclk);
          if (++timeout > 1000) `uvm_fatal("AXIL_TIMEOUT", "AW handshake timeout")
        end while (!vif.awready);
        @(negedge vif.aclk);
        vif.awvalid <= 1'b0;
      end
      begin
        int unsigned data_timeout;
        repeat (req.w_delay) @(negedge vif.aclk);
        vif.wdata <= req.data;
        vif.wstrb <= req.strb;
        vif.wvalid <= 1'b1;
        data_timeout = 0;
        do begin
          @(posedge vif.aclk);
          if (++data_timeout > 1000) `uvm_fatal("AXIL_TIMEOUT", "W handshake timeout")
        end while (!vif.wready);
        @(negedge vif.aclk);
        vif.wvalid <= 1'b0;
    end
    join
    if (!req.ready_before_response) begin
      repeat (req.response_delay) @(negedge vif.aclk);
      vif.bready <= 1'b1;
    end
    timeout = 0;
    do begin
      @(posedge vif.aclk);
      if (++timeout > 1000) `uvm_fatal("AXIL_TIMEOUT", "B response timeout")
    end while (!vif.bvalid);
    req.resp = vif.bresp;
    @(negedge vif.aclk);
    vif.bready <= 1'b0;
  endtask

  task drive_read(thermo5_axil_item req);
    int unsigned timeout;
    @(negedge vif.aclk);
    vif.rready <= req.ready_before_response;
    repeat (req.aw_delay) @(negedge vif.aclk);
    vif.araddr <= req.addr;
    vif.arvalid <= 1'b1;
    timeout = 0;
    do begin
      @(posedge vif.aclk);
      if (++timeout > 1000) `uvm_fatal("AXIL_TIMEOUT", "AR handshake timeout")
    end while (!vif.arready);
    @(negedge vif.aclk);
    vif.arvalid <= 1'b0;
    if (!req.ready_before_response) begin
      repeat (req.response_delay) @(negedge vif.aclk);
      vif.rready <= 1'b1;
    end
    timeout = 0;
    do begin
      @(posedge vif.aclk);
      if (++timeout > 1000) `uvm_fatal("AXIL_TIMEOUT", "R response timeout")
    end while (!vif.rvalid);
    req.rdata = vif.rdata;
    req.resp = vif.rresp;
    @(negedge vif.aclk);
    vif.rready <= 1'b0;
  endtask
endclass
