class thermo5_source_monitor extends uvm_component;
  `uvm_component_utils(thermo5_source_monitor)
  virtual thermo5_sku_if vif;
  uvm_analysis_port#(thermo5_source_item) ap;
  int accepted_beats, stall_cycles;
  bit stalled;
  logic [223:0] held_i, held_q;
  logic held_start;
  logic signed [15:0] held_gain;
  function new(string name, uvm_component parent);
    super.new(name,parent); ap=new("ap",this);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_sku_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF","thermo5 source interface is missing")
  endfunction
  task run_phase(uvm_phase phase);
    thermo5_source_item tr;
    forever begin
      @(posedge vif.src_clk);
      if (!vif.src_rst_n) begin
        accepted_beats=0;
        vif.accepted_beats=0;
        stalled=0;
      end else begin
        if (stalled && (vif.src_valid !== 1'b1 || vif.src_i !== held_i ||
                        vif.src_q !== held_q || vif.frame_start !== held_start ||
                        vif.frame_gain !== held_gain))
          `uvm_error("AXIS_STABLE","Source changed a backpressured beat")
        stalled=(vif.src_valid && !vif.src_ready);
        if (stalled) begin
          stall_cycles++;
          held_i=vif.src_i; held_q=vif.src_q;
          held_start=vif.frame_start; held_gain=vif.frame_gain;
        end
        if (vif.src_valid && vif.src_ready) begin
          tr=thermo5_source_item::type_id::create("observed_beat");
          tr.i_vec=vif.src_i; tr.q_vec=vif.src_q;
          tr.frame_start=vif.frame_start; tr.frame_gain=vif.frame_gain;
          tr.beat_index=accepted_beats;
          accepted_beats++;
          vif.accepted_beats=accepted_beats;
          ap.write(tr);
        end
      end
    end
  endtask
endclass
