`uvm_analysis_imp_decl(_tx)

class dsm_scoreboard extends uvm_subscriber #(dsm_rf_item);
  `uvm_component_utils(dsm_scoreboard)
  dsm_uvm_config cfg;
  int unsigned rf_count;
  int unsigned one_count;
  int unsigned zero_count;
  dsm_rf_cg rf_cg;
  uvm_analysis_imp_tx #(dsm_axis_item, dsm_scoreboard) tx_export;
  int expected_input_i[$];
  int expected_input_q[$];
  bit expected_input_last[$];
  bit expected_rf_bit[$];
  bit signed [15:0] expected_rf_signed[$];
  bit [23:0] expected_rf_phase[$];

  function new(string name, uvm_component parent);
    super.new(name, parent);
    rf_cg = new();
    tx_export = new("tx_export", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(dsm_uvm_config)::get(this, "", "cfg", cfg))
      cfg = dsm_uvm_config::type_id::create("cfg");
    if (cfg.enable_fullchain_check)
      load_performance_vectors();
  endfunction

  function void load_performance_vectors();
    integer fd;
    integer code;
    integer n;
    integer i_value;
    integer q_value;
    integer last_value;
    integer bit_value;
    integer signed_value;
    integer phase_value;
    integer if_value;
    string header;
    string input_path;
    string rf_path;
    input_path = $sformatf("%s/%s_input.csv", dsm_vector_dir(), cfg.fullchain_vector_set);
    rf_path = $sformatf("%s/%s_expected_rf.csv", dsm_vector_dir(), cfg.fullchain_vector_set);
    fd = $fopen(input_path, "r");
    if (fd == 0)
      `uvm_fatal("VECTOR_OPEN", $sformatf("Input vector is missing: %s", input_path))
    void'($fgets(header, fd));
    while (!$feof(fd)) begin
      code = $fscanf(fd, "%d,%d,%d,%d\n", n, i_value, q_value, last_value);
      if (code == 4) begin
        expected_input_i.push_back(i_value);
        expected_input_q.push_back(q_value);
        expected_input_last.push_back(last_value[0]);
      end
    end
    $fclose(fd);
    fd = $fopen(rf_path, "r");
    if (fd == 0)
      `uvm_fatal("VECTOR_OPEN", $sformatf("RF vector is missing: %s", rf_path))
    void'($fgets(header, fd));
    while (!$feof(fd)) begin
      code = $fscanf(fd, "%d,%d,%d,%d,%d\n", n, bit_value, signed_value, phase_value, if_value);
      if (code == 5) begin
        expected_rf_bit.push_back(bit_value[0]);
        expected_rf_signed.push_back(signed_value);
        expected_rf_phase.push_back(phase_value[23:0]);
      end
    end
    $fclose(fd);
    if (!expected_input_i.size() || !expected_rf_bit.size())
      `uvm_fatal("VECTOR_EMPTY", "Performance-SKU vectors are empty")
  endfunction

  function void write_tx(dsm_axis_item t);
    int i_value;
    int q_value;
    bit last_value;
    if (!cfg.enable_fullchain_check)
      return;
    if (!expected_input_i.size()) begin
      `uvm_error("TX_UNEXPECTED", "Observed TX transaction beyond vector length")
      return;
    end
    i_value = expected_input_i.pop_front();
    q_value = expected_input_q.pop_front();
    last_value = expected_input_last.pop_front();
    if ((t.i_sample !== i_value) || (t.q_sample !== q_value) || (t.last !== last_value))
      `uvm_error("TX_BITTRUE", $sformatf("TX actual=(%0d,%0d,%0b) expected=(%0d,%0d,%0b)",
                 t.i_sample, t.q_sample, t.last, i_value, q_value, last_value))
  endfunction

  function void write(dsm_rf_item t);
    bit expected_bit;
    bit signed [15:0] expected_signed;
    bit [23:0] expected_phase;
    rf_count++;
    if (t.rf_bit) one_count++; else zero_count++;
    rf_cg.sample(t.rf_bit, t.rf_signed, t.phase);
    if (t.rf_signed !== (t.rf_bit ? 16'sh7fff : -16'sh7fff))
      `uvm_error("RF_SIGN", "rf_signed does not match rf_bit")
    if (cfg.enable_fullchain_check) begin
      if (!expected_rf_bit.size()) begin
        `uvm_error("RF_UNEXPECTED", "Observed RF transaction beyond vector length")
      end else begin
        expected_bit = expected_rf_bit.pop_front();
        expected_signed = expected_rf_signed.pop_front();
        expected_phase = expected_rf_phase.pop_front();
        if ((t.rf_bit !== expected_bit) || (t.rf_signed !== expected_signed) ||
            (t.phase[1:0] !== expected_phase[1:0]))
          `uvm_error("RF_BITTRUE", $sformatf(
            "RF actual=(%0b,%0d,%0d) expected=(%0b,%0d,%0d)",
            t.rf_bit, t.rf_signed, t.phase[1:0], expected_bit, expected_signed, expected_phase[1:0]))
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    if (cfg.require_rf_output && !rf_count)
      `uvm_error("BP_SMOKE", "No valid RF output was observed")
    if (cfg.require_rf_toggle && (!one_count || !zero_count))
      `uvm_error("BP_SMOKE", "RF stream did not toggle")
    if (cfg.expected_rf_count && rf_count != cfg.expected_rf_count)
      `uvm_error("BP_COUNT", $sformatf("RF count %0d expected %0d", rf_count,
                 cfg.expected_rf_count))
    if (cfg.enable_fullchain_check && (expected_input_i.size() || expected_rf_bit.size()))
      `uvm_error("VECTOR_DRAIN", $sformatf("Undrained vectors: tx=%0d rf=%0d",
                 expected_input_i.size(), expected_rf_bit.size()))
    `uvm_info("BP_SCORE", $sformatf("rf=%0d one=%0d zero=%0d", rf_count,
              one_count, zero_count), UVM_LOW)
  endfunction
endclass
