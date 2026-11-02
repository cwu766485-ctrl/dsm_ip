// Independent AXI-Lite shadow-register and sampled-read predictor.
// The model advances on monitor write-fire events, not the later B response.
class thermo5_axil_register_predictor extends uvm_component;
  `uvm_component_utils(thermo5_axil_register_predictor)
  uvm_analysis_imp_axil_fire#(thermo5_axil_item,thermo5_axil_register_predictor) write_fire_imp;
  uvm_analysis_imp_axil_addr#(thermo5_axil_item,thermo5_axil_register_predictor) read_addr_imp;
  uvm_analysis_imp_axil_done#(thermo5_axil_item,thermo5_axil_register_predictor) completion_imp;
  uvm_analysis_imp_axil_cycle#(thermo5_axil_item,thermo5_axil_register_predictor) cycle_imp;
  virtual thermo5_axil_if axil_vif;
  virtual thermo5_sku_if sku_vif;

  typedef struct packed {
    int unsigned id;
    bit [1:0] response;
  } write_expectation_t;
  typedef struct packed {
    int unsigned id;
    bit [1:0] response;
    bit [31:0] data;
    bit [31:0] mask;
  } read_expectation_t;
  write_expectation_t write_expected[$];
  read_expectation_t read_expected[$];

  bit [63:0] shadow_coeff[0:5];
  bit [2:0] shadow_taps;
  bit run_request_model, busy_model, done_model, error_model;
  bit cfg_ack_sync1_model, cfg_ack_sync2_model, cfg_seen_ack_model;
  bit tx_active_sync1_model, tx_active_sync2_model;
  bit draining_sync1_model, draining_sync2_model;
  bit [31:0] sampled_status_model;
  int unsigned sampled_status_cycle;
  bit sampled_status_valid;
  int unsigned max_taps = 4;
  int unsigned checked_reads, checked_write_responses, mismatches;

  function new(string name, uvm_component parent);
    super.new(name,parent);
    write_fire_imp = new("write_fire_imp",this);
    read_addr_imp = new("read_addr_imp",this);
    completion_imp = new("completion_imp",this);
    cycle_imp = new("cycle_imp",this);
    reset_model();
  endfunction

  function void reset_model();
    shadow_taps = 3'd1;
    shadow_coeff[0] = 64'h0000_0000_0000_4000;
    for (int index=1; index<6; index++) shadow_coeff[index] = '0;
    run_request_model = 0;
    busy_model = 0;
    done_model = 0;
    error_model = 0;
    cfg_ack_sync1_model = 0;
    cfg_ack_sync2_model = 0;
    cfg_seen_ack_model = 0;
    tx_active_sync1_model = 0;
    tx_active_sync2_model = 0;
    draining_sync1_model = 0;
    draining_sync2_model = 0;
    sampled_status_model = 0;
    sampled_status_cycle = 0;
    sampled_status_valid = 0;
    write_expected.delete();
    read_expected.delete();
  endfunction

  function void build_phase(uvm_phase phase);
    int configured_max_taps;
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_axil_if)::get(this,"","axil_vif",axil_vif) ||
        !uvm_config_db#(virtual thermo5_sku_if)::get(this,"","sku_vif",sku_vif))
      `uvm_fatal("PREDICTOR_VIF","AXI-Lite predictor interfaces are missing")
    if (uvm_config_db#(int)::get(this,"","max_taps",configured_max_taps))
      max_taps = configured_max_taps;
  endfunction

  function automatic int coeff_index(bit [7:0] address);
    case (address & 8'hf8)
      8'h10: return 0;
      8'h18: return 1;
      8'h20: return 2;
      8'h28: return 3;
      8'h30: return 4;
      8'h38: return 5;
      default: return -1;
    endcase
  endfunction

  function automatic bit is_coeff_addr(bit [7:0] address);
    int index;
    index=coeff_index(address);
    return index >= 0 && ((address & 8'h03) == 0);
  endfunction

  function automatic bit [31:0] merge_bytes(bit [31:0] old_value,
                                             bit [31:0] new_value,
                                             bit [3:0] strobe);
    bit [31:0] merged;
    merged=old_value;
    for (int byte_index=0; byte_index<4; byte_index++)
      if (strobe[byte_index]) merged[byte_index*8+:8]=new_value[byte_index*8+:8];
    return merged;
  endfunction

  function automatic bit [1:0] predict_write_response(thermo5_axil_item tr);
    if (tr.addr==8'h00) begin
      if (tr.strb[0] && tr.data[1] &&
          (busy_model || shadow_taps < 1 || shadow_taps > max_taps))
        return 2'b10;
      return 2'b00;
    end
    if (tr.addr==8'h04 || tr.addr==8'h08 || is_coeff_addr(tr.addr)) return 2'b00;
    return 2'b11;
  endfunction

  function void write_axil_fire(thermo5_axil_item tr);
    write_expectation_t expected;
    int index;
    bit [31:0] old_word, new_word;
    expected.id=tr.txn_id;
    expected.response=predict_write_response(tr);
    write_expected.push_back(expected);
    if (expected.response != 2'b00) begin
      if (tr.addr==8'h00) error_model=1;
      return;
    end

    case (tr.addr)
      8'h00: if (tr.strb[0]) begin
        run_request_model=tr.data[0];
        if (tr.data[1]) begin
          busy_model=1;
          done_model=0;
          cfg_seen_ack_model=0;
        end
      end
      8'h04: if (tr.strb[0]) begin
        if (tr.data[1]) done_model=0;
        if (tr.data[2]) error_model=0;
      end
      8'h08: if (tr.strb[0]) shadow_taps=tr.data[2:0];
      default: begin
        index=coeff_index(tr.addr);
        if (index>=0 && is_coeff_addr(tr.addr)) begin
          old_word=tr.addr[2] ? shadow_coeff[index][63:32] : shadow_coeff[index][31:0];
          new_word=merge_bytes(old_word,tr.data,tr.strb);
          if (tr.addr[2]) shadow_coeff[index][63:32]=new_word;
          else shadow_coeff[index][31:0]=new_word;
        end
      end
    endcase
  endfunction

  // Called once per AXI-Lite rising edge before same-edge AR/write events.
  // STATUS read prediction uses the pre-NBA value that the RTL samples on AR.
  function void write_axil_cycle(thermo5_axil_item tr);
    bit old_ack_sync2;
    if (!tr.reset_n) begin
      reset_model();
      return;
    end

    sampled_status_model={27'd0,draining_sync2_model,tx_active_sync2_model,
                          error_model,done_model,busy_model};
    sampled_status_cycle=tr.event_cycle;
    sampled_status_valid=1;

    old_ack_sync2=cfg_ack_sync2_model;
    cfg_ack_sync2_model=cfg_ack_sync1_model;
    cfg_ack_sync1_model=sku_vif.cfg_ack_core;
    tx_active_sync2_model=tx_active_sync1_model;
    tx_active_sync1_model=sku_vif.core_tx_active;
    draining_sync2_model=draining_sync1_model;
    draining_sync1_model=sku_vif.core_draining;

    if (busy_model) begin
      if (old_ack_sync2) cfg_seen_ack_model=1;
      else if (cfg_seen_ack_model) begin
        busy_model=0;
        done_model=1;
        cfg_seen_ack_model=0;
      end
    end
  endfunction

  function bit [31:0] predict_read_data(bit [7:0] address,
                                        output bit [1:0] response,
                                        output bit [31:0] compare_mask);
    int index;
    bit [31:0] value;
    response=2'b00;
    compare_mask=32'hffff_ffff;
    value='0;
    case (address)
      8'h00: value={31'd0,run_request_model};
      8'h04: begin
        if (!sampled_status_valid || sampled_status_cycle==0) begin
          `uvm_error("AXIL_STATUS_SAMPLE","STATUS read has no AXI-cycle predictor snapshot")
        end
        value=sampled_status_model;
        compare_mask=32'h0000_001f;
      end
      8'h08: value={29'd0,shadow_taps};
      8'h0c: value=32'h5448_3501;
      default: begin
        index=coeff_index(address);
        if (is_coeff_addr(address))
          value=address[2] ? shadow_coeff[index][63:32] : shadow_coeff[index][31:0];
        else begin
          response=2'b11;
          compare_mask='0;
        end
      end
    endcase
    return value;
  endfunction

  function void write_axil_addr(thermo5_axil_item tr);
    read_expectation_t expected;
    expected.id=tr.txn_id;
    if (tr.addr==8'h04 && sampled_status_cycle!=tr.event_cycle) begin
      mismatches++;
      `uvm_error("AXIL_STATUS_CYCLE",
        $sformatf("STATUS predictor snapshot cycle=%0d AR cycle=%0d",
          sampled_status_cycle,tr.event_cycle))
    end
    expected.data=predict_read_data(tr.addr,expected.response,expected.mask);
    read_expected.push_back(expected);
  endfunction

  function void write_axil_done(thermo5_axil_item tr);
    if (tr.is_write) begin
      write_expectation_t expected;
      if (write_expected.size()==0) begin
        mismatches++;
        `uvm_error("AXIL_PREDICTOR","B response has no matching write-fire event")
      end else begin
        expected=write_expected.pop_front();
        checked_write_responses++;
        if (expected.id!=tr.txn_id || expected.response!=tr.resp) begin
          mismatches++;
          `uvm_error("AXIL_PREDICTOR_WRITE",
            $sformatf("write id=%0d expected id=%0d response=%b got=%b addr=%02x",
              tr.txn_id,expected.id,expected.response,tr.resp,tr.addr))
        end
      end
    end else begin
      read_expectation_t expected;
      if (read_expected.size()==0) begin
        mismatches++;
        `uvm_error("AXIL_PREDICTOR","R response has no matching AR sample event")
      end else begin
        expected=read_expected.pop_front();
        checked_reads++;
        if (expected.id!=tr.txn_id || expected.response!=tr.resp ||
            ((expected.data ^ tr.rdata) & expected.mask)!=0) begin
          mismatches++;
          `uvm_error("AXIL_PREDICTOR_READ",
            $sformatf("read id=%0d addr=%02x expected=%08x/%b mask=%08x got=%08x/%b",
              tr.txn_id,tr.addr,expected.data,expected.response,expected.mask,tr.rdata,tr.resp))
        end
      end
    end
  endfunction

  task run_phase(uvm_phase phase);
    fork
      begin : core_boundary_observer
        bit was_reset;
        was_reset=1;
        forever begin
          @(posedge sku_vif.core_clk);
          if (!sku_vif.core_rst_n) begin
            if (!was_reset) reset_model();
            was_reset=1;
          end else begin
            was_reset=0;
          end
        end
      end
    join
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("AXIL_REGISTER_PREDICTOR",
      $sformatf("read_checks=%0d write_response_checks=%0d mismatches=%0d pending_reads=%0d pending_writes=%0d",
        checked_reads,checked_write_responses,mismatches,read_expected.size(),write_expected.size()),
      UVM_NONE)
  endfunction
endclass
