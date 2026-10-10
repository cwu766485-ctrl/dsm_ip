// Sole testbench owner of reset, core enable, and common four-plane ready.
class thermo5_control_bfm extends uvm_component;
  `uvm_component_utils(thermo5_control_bfm)
  virtual thermo5_sku_if vif;
  thermo5_sku_config cfg;
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_sku_if)::get(this,"","vif",vif) ||
        !uvm_config_db#(thermo5_sku_config)::get(this,"","cfg",cfg))
      `uvm_fatal("NOCFG","Control BFM requires vif and SKU configuration")
  endfunction
  task run_phase(uvm_phase phase);
    repeat(8) @(negedge vif.src_clk);
    vif.src_rst_n=1'b1;
    repeat(8) @(negedge vif.core_clk);
    vif.core_rst_n=1'b1;
    forever begin
      @(negedge vif.core_clk);
      if (!cfg.manual_pa_ready)
        vif.pa_ready=cfg.random_pa_ready && $urandom_range(0,99)<cfg.pa_stall_percent ? 4'h0 : 4'hf;
    end
  endtask
  task core_on();
    @(negedge vif.core_clk); vif.core_enable=1'b1;
  endtask
  task core_off();
    @(negedge vif.core_clk); vif.core_enable=1'b0;
  endtask
  task reset_both(bit core_enable_while_asserted=1'b0,
                  bit release_core_first=1'b0);
    // Caller chooses the exact core-clock falling edge (residual-state test).
    vif.core_enable=core_enable_while_asserted;
    vif.core_rst_n=1'b0;
    vif.src_rst_n=1'b0;
    fork
      begin
        while (!vif.src_rst_n || !vif.core_rst_n) begin
          @(posedge vif.src_clk);
          if ((!vif.src_rst_n || !vif.core_rst_n) &&
              vif.src_valid && vif.src_ready)
            `uvm_fatal("RESET_HANDSHAKE","Source transfer occurred during common reset epoch")
        end
      end
      begin
        while (!vif.src_rst_n || !vif.core_rst_n) begin
          @(posedge vif.core_clk);
          if ((!vif.src_rst_n || !vif.core_rst_n) &&
              ((vif.pa_valid & vif.pa_ready) != 0))
            `uvm_fatal("RESET_HANDSHAKE","PA transfer occurred during common reset epoch")
        end
      end
    join_none
    if (release_core_first) begin
      repeat(8) @(negedge vif.core_clk);
      vif.core_rst_n=1'b1;
      repeat(8) @(negedge vif.src_clk);
      vif.src_rst_n=1'b1;
    end else begin
      repeat(8) @(negedge vif.src_clk);
      vif.src_rst_n=1'b1;
      repeat(8) @(negedge vif.core_clk);
      vif.core_rst_n=1'b1;
    end
    vif.core_enable=1'b0;
    wait fork;
  endtask
endclass
