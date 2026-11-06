// Direct, checker-level fault injection for the SystemVerilog Unified
// Scoreboard.  Expected UVM errors are caught and counted; an unexpected
// report remains an error and causes the normal regression gate to fail.
class thermo5_unified_expected_error_catcher extends uvm_report_catcher;
  string expected_ids[$];
  int unsigned caught_count;

  function new(string name = "thermo5_unified_expected_error_catcher");
    super.new(name);
  endfunction

  function void expect_id(string report_id);
    expected_ids.push_back(report_id);
  endfunction

  virtual function action_e catch();
    int index;
    if (get_severity()!=UVM_ERROR) return THROW;
    for (index=0;index<expected_ids.size();index++) begin
      if (get_id()==expected_ids[index]) begin
        expected_ids.delete(index);
        caught_count++;
        set_severity(UVM_INFO);
        return CAUGHT;
      end
    end
    return THROW;
  endfunction
endclass

class thermo5_unified_scoreboard_mutation_test extends uvm_test;
  `uvm_component_utils(thermo5_unified_scoreboard_mutation_test)

  thermo5_sku_config cfg;
  thermo5_unified_scoreboard sb;
  thermo5_unified_expected_error_catcher catcher;
  longint unsigned next_event_id;

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg=thermo5_sku_config::type_id::create("mutation_cfg");
    cfg.ef2_reference_enable=0;
    uvm_config_db#(thermo5_sku_config)::set(this,"sb","cfg",cfg);
    sb=thermo5_unified_scoreboard::type_id::create("sb",this);
  endfunction

  function thermo5_transaction_event new_event(thermo5_event_kind_e kind);
    thermo5_transaction_event tr;
    tr=thermo5_transaction_event::type_id::create("mutation_event");
    tr.kind=kind;
    tr.epoch=0;
    tr.event_id=next_event_id++;
    return tr;
  endfunction

  function void start_case();
    sb.clear_epoch_state(0);
    sb.have_epoch=0;
    sb.have_event_id=0;
    sb.expected_event_id=0;
    next_event_id=0;
  endfunction

  function void require_detection(string mutation_name,
                                  int unsigned before_count,
                                  int unsigned expected_reports);
    if (catcher.caught_count-before_count!=expected_reports)
      `uvm_fatal("MUTATION_UNDETECTED",
        $sformatf("%s expected %0d checker reports, observed %0d",
          mutation_name,expected_reports,catcher.caught_count-before_count))
    `uvm_info("MUTATION_DETECTED",
      $sformatf("mutation=%s checker_reports=%0d",mutation_name,
        expected_reports),UVM_NONE)
  endfunction

  task run_phase(uvm_phase phase);
    thermo5_transaction_event tr, earlier, later;
    int unsigned before_count;
    bit drained;
    phase.raise_objection(this);
    catcher=new("expected_checker_errors");
    uvm_report_cb::add(null,catcher);

    // Lost accepted source data: normal drain must detect the orphaned
    // independent expected samples when no matching CDC transaction arrives.
    start_case();
    tr=new_event(THERMO5_EVENT_SOURCE_BEAT);
    tr.local_index=0;
    tr.frame_id=0;
    tr.frame_id_valid=1;
    tr.frame_start=1;
    sb.write_event(tr);
    catcher.expect_id("UNIFIED_DRAIN");
    before_count=catcher.caught_count;
    drained=sb.check_expected_queues_drained("mutation-lost-cdc");
    if (drained) `uvm_fatal("MUTATION_UNDETECTED","lost CDC transaction drained cleanly")
    require_detection("lost_cdc_transaction",before_count,1);

    // Duplicate source transaction: the repeated local index must fail the
    // monotonically increasing accepted-transaction index check.
    start_case();
    tr=new_event(THERMO5_EVENT_SOURCE_BEAT);
    tr.local_index=0; tr.frame_id=0; tr.frame_id_valid=1; tr.frame_start=1;
    sb.write_event(tr);
    tr=new_event(THERMO5_EVENT_SOURCE_BEAT);
    tr.local_index=0; tr.frame_id=0; tr.frame_id_valid=1;
    catcher.expect_id("UNIFIED_STAGE_INDEX");
    before_count=catcher.caught_count;
    sb.write_event(tr);
    require_detection("duplicate_source_transaction",before_count,1);

    // Reordered events: event IDs are assigned before delivery so reversing
    // their delivery order exercises the real sequence checker.
    start_case();
    earlier=new_event(THERMO5_EVENT_AXIL_READ);
    later=new_event(THERMO5_EVENT_AXIL_READ);
    sb.write_event(later);
    catcher.expect_id("UNIFIED_EVENT_ID");
    before_count=catcher.caught_count;
    sb.write_event(earlier);
    require_detection("reordered_transactions",before_count,1);

    // Incorrect source Frame ID must be rejected independently of payload.
    start_case();
    tr=new_event(THERMO5_EVENT_SOURCE_BEAT);
    tr.local_index=0; tr.frame_id=7; tr.frame_id_valid=1; tr.frame_start=1;
    catcher.expect_id("UNIFIED_FRAME_ID");
    before_count=catcher.caught_count;
    sb.write_event(tr);
    require_detection("wrong_frame_id",before_count,1);

    // A pending/apply observation without any accepted COMMIT is an
    // impossible early-apply sequence and must trigger both causal checks.
    start_case();
    tr=new_event(THERMO5_EVENT_DSP_OBSERVATION);
    tr.cfg_pending=1; tr.dpd_config_boundary=1;
    tr.pending_config_id=9; tr.config_id=9; tr.config_applied=1;
    catcher.expect_id("UNIFIED_CONFIG_PENDING");
    catcher.expect_id("UNIFIED_CONFIG_APPLY");
    before_count=catcher.caught_count;
    sb.write_event(tr);
    require_detection("apply_without_prior_commit",before_count,2);

    // EF2 data corruption: preload an independent zero-valued one-word
    // sidecar and corrupt one observed I lane.
    start_case();
    sb.cfg.ef2_reference_enable=1;
    sb.ef2_reference_loaded=1;
    for (int lane=0;lane<32;lane++) begin
      sb.expected_ef2_i_samples.push_back(16'sd0);
      sb.expected_ef2_q_samples.push_back(16'sd0);
    end
    tr=new_event(THERMO5_EVENT_EF2_WORD);
    tr.local_index=0;
    tr.ef2_i='0;
    tr.ef2_q='0;
    tr.ef2_i[15:0]=16'h0001;
    catcher.expect_id("UNIFIED_EF2_DATA");
    before_count=catcher.caught_count;
    sb.write_event(tr);
    require_detection("ef2_data_corruption",before_count,1);

    start_case();
    if (!sb.check_expected_queues_drained("mutation-clean-checkpoint"))
      `uvm_fatal("MUTATION_CLEAN_DRAIN","empty expected queues did not drain")
    if (catcher.expected_ids.size()!=0)
      `uvm_fatal("MUTATION_EXPECTATION_REMAINS",
        $sformatf("%0d expected checker reports were not observed",
          catcher.expected_ids.size()))
    if (catcher.caught_count!=7)
      `uvm_fatal("MUTATION_COUNT",
        $sformatf("expected seven checker detections, got %0d",catcher.caught_count))
    `uvm_info("THERMO5_UNIFIED_SCOREBOARD_MUTATION_PASS",
      "direct SV scoreboard mutation tests detected lost, duplicate, reordered, wrong-frame, premature-config, and EF2-corrupt events",UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
