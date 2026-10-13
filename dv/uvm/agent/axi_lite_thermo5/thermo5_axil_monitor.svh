class thermo5_axil_monitor extends uvm_monitor;
  `uvm_component_utils(thermo5_axil_monitor)
  virtual thermo5_axil_if vif;
  uvm_analysis_port #(thermo5_axil_item) ap;
  int unsigned writes, reads, decerr_count, slverr_count;
  int unsigned aw_cycle, w_cycle, cycle_count;
  bit aw_seen, w_seen, read_seen;
  bit [7:0] awaddr_seen, araddr_seen;
  bit [31:0] wdata_seen;
  bit [3:0] wstrb_seen;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_axil_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Thermo5 AXI-Lite monitor interface is missing")
  endfunction

  task run_phase(uvm_phase phase);
    thermo5_axil_item tr;
    cycle_count = 0;
    aw_seen = 0; w_seen = 0; read_seen = 0;
    forever begin
      @(posedge vif.aclk);
      cycle_count++;
      if (!vif.aresetn) begin
        aw_seen = 0; w_seen = 0; read_seen = 0;
      end else begin
        if (vif.awvalid && vif.awready) begin
          aw_seen = 1; awaddr_seen = vif.awaddr; aw_cycle = cycle_count;
        end
        if (vif.wvalid && vif.wready) begin
          w_seen = 1; wdata_seen = vif.wdata; wstrb_seen = vif.wstrb; w_cycle = cycle_count;
        end
        if (vif.bvalid && vif.bready && aw_seen && w_seen) begin
          tr = thermo5_axil_item::type_id::create("observed_write", this);
          tr.is_write = 1; tr.addr = awaddr_seen; tr.data = wdata_seen;
          tr.strb = wstrb_seen; tr.resp = vif.bresp;
          writes++;
          if (vif.bresp == 2'b10) slverr_count++;
          if (vif.bresp == 2'b11) decerr_count++;
          ap.write(tr);
          aw_seen = 0; w_seen = 0;
        end
        if (vif.arvalid && vif.arready) begin
          read_seen = 1; araddr_seen = vif.araddr;
        end
        if (vif.rvalid && vif.rready && read_seen) begin
          tr = thermo5_axil_item::type_id::create("observed_read", this);
          tr.is_write = 0; tr.addr = araddr_seen; tr.rdata = vif.rdata; tr.resp = vif.rresp;
          reads++;
          if (vif.rresp == 2'b10) slverr_count++;
          if (vif.rresp == 2'b11) decerr_count++;
          ap.write(tr);
          read_seen = 0;
        end
      end
    end
  endtask
endclass
