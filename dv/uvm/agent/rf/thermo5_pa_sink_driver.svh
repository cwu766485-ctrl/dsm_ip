// Active PA sink driver. This component is the only procedural owner of
// pa_ready; tests request readiness through thermo5_pa_sink_agent::set_ready.
class thermo5_pa_sink_driver extends uvm_component;
  `uvm_component_utils(thermo5_pa_sink_driver)
  virtual thermo5_sku_if vif;
  thermo5_sku_config cfg;
  logic [3:0] requested_ready = 4'hf;

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_sku_if)::get(this,"","vif",vif) ||
        !uvm_config_db#(thermo5_sku_config)::get(this,"","cfg",cfg))
      `uvm_fatal("NOVIF","PA sink driver requires interface and SKU configuration")
  endfunction

  task set_requested_ready(input logic [3:0] ready);
    cfg.manual_pa_ready=1'b1;
    requested_ready=ready;
    do @(posedge vif.core_clk); while (vif.pa_ready !== ready);
  endtask

  task run_phase(uvm_phase phase);
    logic [3:0] random_ready;
    vif.pa_ready=4'hf;
    forever begin
      @(negedge vif.core_clk);
      if (cfg.manual_pa_ready) begin
        vif.pa_ready <= requested_ready;
      end else if (cfg.random_pa_ready &&
                   $urandom_range(0,99)<cfg.pa_stall_percent) begin
        if (cfg.random_partial_pa_ready) begin
          random_ready=$urandom_range(0,15);
          vif.pa_ready <= (random_ready==4'hf) ? 4'h0 : random_ready;
        end else begin
          vif.pa_ready <= 4'h0;
        end
      end else begin
        vif.pa_ready <= 4'hf;
      end
    end
  endtask
endclass
