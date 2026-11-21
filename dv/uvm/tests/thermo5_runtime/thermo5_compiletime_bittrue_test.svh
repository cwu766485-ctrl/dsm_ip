class thermo5_compiletime_bittrue_test extends thermo5_runtime_switch_test;
  `uvm_component_utils(thermo5_compiletime_bittrue_test)
  int static_arch;

  function new(string name,uvm_component parent);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(virtual thermo5_runtime_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF","compile-time test requires vif")
    if(!uvm_config_db#(int)::get(this,"","static_arch",static_arch) || static_arch<0 || static_arch>2)
      `uvm_fatal("DSM_ARCH","Compile-time architecture configuration is missing or invalid")
    source_beats=32;words=56;mode_config=0;
    source_i=new[source_beats*14];source_q=new[source_beats*14];
    $readmemh("axis_i_samples.mem",source_i);
    $readmemh("axis_q_samples.mem",source_q);
    uvm_config_db#(virtual thermo5_runtime_if)::set(this,"*","vif",vif);
    uvm_config_db#(string)::set(this,"scoreboard","vector_dir",".");
    uvm_config_db#(string)::set(this,"scoreboard","capture_dir",".");
    uvm_config_db#(int)::set(this,"scoreboard","core_words",words);
    monitor=runtime_pa_monitor::type_id::create("monitor",this);
    scoreboard=runtime_pa_scoreboard::type_id::create("scoreboard",this);
  endfunction

  task run_phase(uvm_phase phase);
    bit [1:0] response;
    int cycle=0;
    phase.raise_objection(this);
    fork
      begin
        forever begin
          @(negedge vif.core_clk);
          cycle++;
          if (static_arch==2) begin
            case (cycle%5)
              0: vif.pa_ready=4'h1;
              1: vif.pa_ready=4'h2;
              default: vif.pa_ready=4'h3;
            endcase
          end else begin
            case (cycle%5)
              0: vif.pa_ready=4'he;
              1: vif.pa_ready=4'h0;
              default: vif.pa_ready=4'hf;
            endcase
          end
        end
      end
    join_none

    reset_all();
    if (vif.arch !== static_arch[1:0])
      `uvm_fatal("STATIC_ARCH","Elaborated architecture does not match DSM_ARCH")
    if (vif.pa_mask !== (static_arch==2 ? 4'h3 : 4'hf) ||
        vif.weighted !== (static_arch==2) || vif.mode_busy !== 1'b0)
      `uvm_fatal("STATIC_PA_CONTRACT","Static PA mask/weight/mode-busy contract mismatch")

    write_reg(8'h40,32'd2,response);
    if (response !== 2'b11)
      `uvm_fatal("RUNTIME_MODE_PRESENT","Compile-time top must reject runtime DSM selection")
    scoreboard.begin_stream(static_arch,0,0);
    fork
      send_stream();
      begin
        expect_write(8'h00,32'd1,2'b00);
        finish_stream(static_arch);
      end
    join

    if (monitor.accepted != words || vif.protocol_error || vif.underflow)
      `uvm_fatal("STATIC_STREAM",$sformatf("accepted=%0d expected=%0d protocol=%b underflow=%b",
        monitor.accepted,words,vif.protocol_error,vif.underflow))
    `uvm_info("COMPILE_TIME_PRODUCT_PASS",$sformatf("DSM_ARCH=%0d words=%0d mask=%h weighted=%b",
      static_arch,scoreboard.total_checked,vif.pa_mask,vif.weighted),UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
