class dsm_axi_lite_monitor extends uvm_monitor;
  `uvm_component_utils(dsm_axi_lite_monitor)
  virtual dsm_axi_lite_if vif;
  uvm_analysis_port #(dsm_axi_lite_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual dsm_axi_lite_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "AXI-Lite monitor virtual interface is not configured")
  endfunction

  task run_phase(uvm_phase phase);
    bit aw_pending, w_pending, ar_pending;
    dsm_reg_addr_t awaddr, araddr;
    bit [31:0] wdata;
    dsm_axi_lite_item item;
    aw_pending = 0;
    w_pending = 0;
    ar_pending = 0;
    forever begin
      @(posedge vif.aclk);
      if (!vif.aresetn) begin
        aw_pending = 0;
        w_pending = 0;
        ar_pending = 0;
      end else begin
        if (vif.awvalid && vif.awready) begin
          awaddr = vif.awaddr;
          aw_pending = 1;
        end
        if (vif.wvalid && vif.wready) begin
          wdata = vif.wdata;
          w_pending = 1;
        end
        if (vif.bvalid && vif.bready && aw_pending && w_pending) begin
          item = dsm_axi_lite_item::type_id::create("write_item");
          item.is_write = 1;
          item.addr = awaddr;
          item.data = wdata;
          item.resp = vif.bresp;
          ap.write(item);
          aw_pending = 0;
          w_pending = 0;
        end
        if (vif.arvalid && vif.arready) begin
          araddr = vif.araddr;
          ar_pending = 1;
        end
        if (vif.rvalid && vif.rready && ar_pending) begin
          item = dsm_axi_lite_item::type_id::create("read_item");
          item.is_write = 0;
          item.addr = araddr;
          item.rdata = vif.rdata;
          item.resp = vif.rresp;
          ap.write(item);
          ar_pending = 0;
        end
      end
    end
  endtask
endclass
