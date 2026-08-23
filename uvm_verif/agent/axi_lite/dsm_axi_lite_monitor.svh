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
    bit ar_pending;
    dsm_reg_addr_t awaddr_q[$], araddr;
    bit [31:0] wdata_q[$];
    int unsigned aw_cycle_q[$], w_cycle_q[$];
    dsm_axi_lite_item item;
    int unsigned cycle_count;
    int unsigned b_stall_cycles, r_stall_cycles;
    ar_pending = 0;
    cycle_count = 0;
    b_stall_cycles = 0;
    r_stall_cycles = 0;
    forever begin
      @(posedge vif.aclk);
      cycle_count++;
      if (!vif.aresetn) begin
        awaddr_q.delete();
        wdata_q.delete();
        aw_cycle_q.delete();
        w_cycle_q.delete();
        ar_pending = 0;
        b_stall_cycles = 0;
        r_stall_cycles = 0;
      end else begin
        if (vif.awvalid && vif.awready) begin
          awaddr_q.push_back(vif.awaddr);
          aw_cycle_q.push_back(cycle_count);
        end
        if (vif.wvalid && vif.wready) begin
          wdata_q.push_back(vif.wdata);
          w_cycle_q.push_back(cycle_count);
        end
        if (vif.bvalid && !vif.bready) b_stall_cycles++;
        if (vif.bvalid && vif.bready && awaddr_q.size() && wdata_q.size()) begin
          item = dsm_axi_lite_item::type_id::create("write_item");
          item.is_write = 1;
          item.addr = awaddr_q.pop_front();
          item.data = wdata_q.pop_front();
          item.resp = vif.bresp;
          item.observed_channel_skew_cycles = (aw_cycle_q[0] >= w_cycle_q[0]) ?
              (aw_cycle_q[0] - w_cycle_q[0]) : (w_cycle_q[0] - aw_cycle_q[0]);
          void'(aw_cycle_q.pop_front());
          void'(w_cycle_q.pop_front());
          item.observed_response_stall_cycles = b_stall_cycles;
          ap.write(item);
          b_stall_cycles = 0;
        end
        if (vif.arvalid && vif.arready) begin
          araddr = vif.araddr;
          ar_pending = 1;
        end
        if (vif.rvalid && !vif.rready) r_stall_cycles++;
        if (vif.rvalid && vif.rready && ar_pending) begin
          item = dsm_axi_lite_item::type_id::create("read_item");
          item.is_write = 0;
          item.addr = araddr;
          item.rdata = vif.rdata;
          item.resp = vif.rresp;
          item.observed_channel_skew_cycles = 0;
          item.observed_response_stall_cycles = r_stall_cycles;
          ap.write(item);
          ar_pending = 0;
          r_stall_cycles = 0;
        end
      end
    end
  endtask
endclass
