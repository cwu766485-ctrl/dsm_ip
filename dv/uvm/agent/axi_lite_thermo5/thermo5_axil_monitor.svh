class thermo5_axil_monitor extends uvm_monitor;
  `uvm_component_utils(thermo5_axil_monitor)
  virtual thermo5_axil_if vif;
  uvm_analysis_port #(thermo5_axil_item) ap;
  int unsigned writes, reads, decerr_count, slverr_count;
  int unsigned aw_cycle, w_cycle, cycle_count;
  int unsigned b_stall_cycles, r_stall_cycles;
  bit aw_seen, w_seen, read_seen;
  bit [7:0] awaddr_seen, araddr_seen;
  bit [31:0] wdata_seen;
  bit [3:0] wstrb_seen;
  covergroup write_cg with function sample(bit [3:0] address_kind,
                                            bit [1:0] response,
                                            bit [1:0] strobe_kind,
                                            bit [1:0] channel_order,
                                            bit response_stalled);
    option.per_instance = 1;
    cp_address: coverpoint address_kind {
      bins control = {0}; bins status = {1}; bins taps = {2};
      bins coeff_low = {3}; bins coeff_high = {4};
      bins readonly_id = {5}; bins unmapped = {6};
    }
    cp_response: coverpoint response {
      bins okay = {0}; bins slverr = {2}; bins decerr = {3};
      ignore_bins reserved = {1};
    }
    cp_strobe: coverpoint strobe_kind {
      bins zero = {0}; bins partial = {1}; bins full = {2};
    }
    cp_aw_w_order: coverpoint channel_order {
      bins same_cycle = {0}; bins aw_first = {1}; bins w_first = {2};
    }
    cp_response_stall: coverpoint response_stalled {
      bins no_stall = {0}; bins stalled = {1};
    }
  endgroup
  covergroup read_cg with function sample(bit [3:0] address_kind,
                                           bit [1:0] response,
                                           bit response_stalled);
    option.per_instance = 1;
    cp_address: coverpoint address_kind {
      bins control = {0}; bins status = {1}; bins taps = {2}; bins id = {3};
      bins coeff_low = {4}; bins coeff_high = {5}; bins unmapped = {6};
    }
    cp_response: coverpoint response {
      bins okay = {0}; bins decerr = {3}; ignore_bins reserved = {1,2};
    }
    cp_response_stall: coverpoint response_stalled {
      bins no_stall = {0}; bins stalled = {1};
    }
  endgroup
  covergroup reset_cg with function sample(bit reset_released);
    option.per_instance = 1;
    cp_reset: coverpoint reset_released {
      bins asserted = {0}; bins released = {1};
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
    write_cg = new();
    read_cg = new();
    reset_cg = new();
  endfunction

  function automatic bit [3:0] classify_write_address(bit [7:0] addr);
    case (addr)
      8'h00: return 0;
      8'h04: return 1;
      8'h08: return 2;
      8'h10,8'h18,8'h20,8'h28,8'h30,8'h38: return 3;
      8'h14,8'h1c,8'h24,8'h2c,8'h34,8'h3c: return 4;
      8'h0c: return 5;
      default: return 6;
    endcase
  endfunction

  function automatic bit [3:0] classify_read_address(bit [7:0] addr);
    case (addr)
      8'h00: return 0;
      8'h04: return 1;
      8'h08: return 2;
      8'h0c: return 3;
      8'h10,8'h18,8'h20,8'h28,8'h30,8'h38: return 4;
      8'h14,8'h1c,8'h24,8'h2c,8'h34,8'h3c: return 5;
      default: return 6;
    endcase
  endfunction

  function automatic bit [1:0] classify_strobe(bit [3:0] strb);
    if (strb == 4'h0) return 0;
    if (strb == 4'hf) return 2;
    return 1;
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
    b_stall_cycles = 0; r_stall_cycles = 0;
    forever begin
      @(posedge vif.aclk);
      cycle_count++;
      reset_cg.sample(vif.aresetn === 1'b1);
      if (!vif.aresetn) begin
        aw_seen = 0; w_seen = 0; read_seen = 0;
        b_stall_cycles = 0; r_stall_cycles = 0;
      end else begin
        if (vif.bvalid && !vif.bready) b_stall_cycles++;
        if (vif.rvalid && !vif.rready) r_stall_cycles++;
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
          if (aw_cycle == w_cycle)
            write_cg.sample(classify_write_address(awaddr_seen), vif.bresp,
                            classify_strobe(wstrb_seen), 2'd0,
                            b_stall_cycles != 0);
          else if (aw_cycle < w_cycle)
            write_cg.sample(classify_write_address(awaddr_seen), vif.bresp,
                            classify_strobe(wstrb_seen), 2'd1,
                            b_stall_cycles != 0);
          else
            write_cg.sample(classify_write_address(awaddr_seen), vif.bresp,
                            classify_strobe(wstrb_seen), 2'd2,
                            b_stall_cycles != 0);
          writes++;
          if (vif.bresp == 2'b10) slverr_count++;
          if (vif.bresp == 2'b11) decerr_count++;
          ap.write(tr);
          aw_seen = 0; w_seen = 0;
          b_stall_cycles = 0;
        end
        if (vif.arvalid && vif.arready) begin
          read_seen = 1; araddr_seen = vif.araddr;
        end
        if (vif.rvalid && vif.rready && read_seen) begin
          tr = thermo5_axil_item::type_id::create("observed_read", this);
          tr.is_write = 0; tr.addr = araddr_seen; tr.rdata = vif.rdata; tr.resp = vif.rresp;
          read_cg.sample(classify_read_address(araddr_seen), vif.rresp,
                         r_stall_cycles != 0);
          reads++;
          if (vif.rresp == 2'b10) slverr_count++;
          if (vif.rresp == 2'b11) decerr_count++;
          ap.write(tr);
          read_seen = 0;
          r_stall_cycles = 0;
        end
      end
    end
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("AXIL_FUNCTIONAL_COVERAGE",
      $sformatf("write=%.1f read=%.1f reset=%.1f writes=%0d reads=%0d SLVERR=%0d DECERR=%0d",
        write_cg.get_coverage(), read_cg.get_coverage(), reset_cg.get_coverage(),
        writes, reads, slverr_count, decerr_count), UVM_NONE)
  endfunction
endclass
