class thermo5_source_driver extends uvm_driver#(thermo5_source_item);
  `uvm_component_utils(thermo5_source_driver)
  virtual thermo5_sku_if vif;
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_sku_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF","thermo5 source interface is missing")
  endfunction
  task run_phase(uvm_phase phase);
    thermo5_source_item tr;
    wait(vif.src_rst_n && vif.core_rst_n);
    forever begin
      @(negedge vif.src_clk);
      tr=null;
      seq_item_port.try_next_item(tr);
      if (tr==null) begin
        vif.src_valid=1'b0;
        vif.frame_start=1'b0;
        continue;
      end
      if (tr.valid_gap_cycles != 0) begin
        vif.src_valid=1'b0;
        vif.frame_start=1'b0;
        repeat (tr.valid_gap_cycles) @(negedge vif.src_clk);
      end
      vif.src_valid=1'b1;
      vif.src_i=tr.i_vec;
      vif.src_q=tr.q_vec;
      vif.frame_start=tr.frame_start;
      vif.frame_gain=tr.frame_gain;
      do @(posedge vif.src_clk); while (vif.src_ready !== 1'b1);
      seq_item_port.item_done();
    end
  endtask
endclass
