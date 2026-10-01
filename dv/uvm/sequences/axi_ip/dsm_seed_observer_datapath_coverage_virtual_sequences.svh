// Directed high-entropy stimulus for the frozen Performance SKU.  It covers
// legal seed-policy classifications, observer arithmetic paths, and a broad
// range of IQ values through the real BP EFDSM2 transmit chain.
class dsm_seed_observer_datapath_coverage_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(dsm_seed_observer_datapath_coverage_virtual_sequence)
  `uvm_declare_p_sequencer(dsm_virtual_sequencer)

  function new(string name = "dsm_seed_observer_datapath_coverage_virtual_sequence");
    super.new(name);
  endfunction

  task automatic write_reg(input dsm_reg_addr_t addr, input bit [31:0] data,
                           input string name);
    dsm_axi_lite_write_sequence seq;
    seq = dsm_axi_lite_write_sequence::type_id::create(name);
    seq.addr = addr;
    seq.data = data;
    seq.addr_delay_cycles = $urandom_range(0, 8);
    seq.data_delay_cycles = $urandom_range(0, 8);
    seq.ready_delay_cycles = $urandom_range(0, 12);
    seq.start(p_sequencer.axi_sequencer);
    if (seq.resp != 2'b00)
      `uvm_error("AXIL_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task automatic read_reg(input dsm_reg_addr_t addr, output bit [31:0] data,
                          input string name);
    dsm_axi_lite_read_sequence seq;
    seq = dsm_axi_lite_read_sequence::type_id::create(name);
    seq.addr = addr;
    seq.addr_delay_cycles = $urandom_range(0, 8);
    seq.ready_delay_cycles = $urandom_range(0, 12);
    seq.start(p_sequencer.axi_sequencer);
    data = seq.rdata;
    if (seq.resp != 2'b00)
      `uvm_error("AXIL_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task automatic expect_seed(input bit [2:0] expected_package, input bit known,
                             input bit fallback, input string name);
    bit [31:0] status;
    read_reg(DSM_REG_SEED_STATUS, status, name);
    if ((status[2:0] != expected_package) || (status[3] != known) ||
        (status[4] != fallback) || (status[5] != 1'b1)) begin
      `uvm_error("SEED_STATUS", $sformatf(
        "%s got=0x%08x expected_package=%0d known=%0b fallback=%0b local=%0b",
        name, status, status[2:0], status[3], status[4], status[5]))
    end
  endtask

  task automatic send_item(input uvm_sequencer_base sequencer,
                           input int signed i_sample, input int signed q_sample,
                           input bit last, input bit invalid, input int unsigned gap,
                           input string name);
    dsm_axis_single_item_sequence seq;
    seq = dsm_axis_single_item_sequence::type_id::create(name);
    seq.i_sample = i_sample;
    seq.q_sample = q_sample;
    seq.last = last;
    seq.user_error = invalid;
    seq.valid_gap_cycles = gap;
    seq.start(sequencer);
  endtask

  task automatic wait_cycles(input int unsigned cycles);
    repeat (cycles) @(posedge p_sequencer.tx_vif.aclk);
  endtask

  task automatic program_condition(input bit valid, input bit [7:0] version,
                                   input bit [15:0] qam, input bit [31:0] bw,
                                   input bit [31:0] backoff,
                                   input bit signed [15:0] power,
                                   input bit signed [15:0] temperature,
                                   input bit [31:0] monitor, input string name);
    write_reg(DSM_REG_CONDITION_CTRL, {16'd0, version, 7'd0, valid},
              {name, "_ctrl"});
    write_reg(DSM_REG_CONDITION_QAM, {16'd0, qam}, {name, "_qam"});
    write_reg(DSM_REG_CONDITION_BW, bw, {name, "_bw"});
    write_reg(DSM_REG_CONDITION_BACKOFF, backoff, {name, "_backoff"});
    write_reg(DSM_REG_CONDITION_ENV, {temperature, power}, {name, "_env"});
    write_reg(DSM_REG_CONDITION_MONITOR, monitor, {name, "_monitor"});
  endtask

  task automatic send_entropy_tx();
    dsm_axis_random_burst_sequence random_tx;

    // Explicit extremal and low-amplitude values complement the seeded-random
    // burst and reach signed arithmetic and clipping paths deterministically.
    send_item(p_sequencer.tx_sequencer,  32767,  32767, 0, 0, 0, "tx_max_pos");
    send_item(p_sequencer.tx_sequencer, -32768, -32768, 0, 0, 1, "tx_min_neg");
    send_item(p_sequencer.tx_sequencer,  32767, -32768, 0, 0, 2, "tx_cross_a");
    send_item(p_sequencer.tx_sequencer, -32768,  32767, 0, 0, 0, "tx_cross_b");
    send_item(p_sequencer.tx_sequencer,      1,     -1, 0, 0, 3, "tx_lsb_a");
    send_item(p_sequencer.tx_sequencer,     -1,      1, 0, 0, 0, "tx_lsb_b");
    send_item(p_sequencer.tx_sequencer,      0,      0, 0, 0, 1, "tx_zero");

    random_tx = dsm_axis_random_burst_sequence::type_id::create("entropy_tx");
    random_tx.item_count = 256;
    random_tx.max_valid_gap = 7;
    random_tx.amplitude = 32767;
    random_tx.start(p_sequencer.tx_sequencer);
  endtask

  task automatic observer_window(input bit [4:0] delay, input bit signed [15:0] gain_re,
                                 input bit signed [15:0] gain_im, input bit require_clip_or_sat,
                                 input string name);
    bit [31:0] value;

    write_reg(DSM_REG_OBS_GAIN, {gain_im, gain_re}, {name, "_gain"});
    write_reg(DSM_REG_OBS_WINDOW, 32'd8, {name, "_window"});
    write_reg(DSM_REG_OBS_CTRL, {15'd0, 1'b1, 3'd0, delay, 5'd0, 3'b011},
              {name, "_start"});
    wait_cycles(8);

    // An invalid beat must take the drop path, while the remaining eight valid
    // feedback beats complete a legal window through all four spectral phases.
    send_item(p_sequencer.obs_sequencer,  12000, -12000, 0, 1, 0, {name, "_invalid"});
    send_item(p_sequencer.obs_sequencer,  32767, -32768, 0, 0, 1, {name, "_p0"});
    send_item(p_sequencer.obs_sequencer, -32768,  32767, 0, 0, 0, {name, "_p1"});
    send_item(p_sequencer.obs_sequencer,  30000,  28000, 0, 0, 2, {name, "_p2"});
    send_item(p_sequencer.obs_sequencer, -28000, -30000, 0, 0, 0, {name, "_p3"});
    send_item(p_sequencer.obs_sequencer,   4096,  -8192, 0, 0, 1, {name, "_p4"});
    send_item(p_sequencer.obs_sequencer,  -4096,   8192, 0, 0, 0, {name, "_p5"});
    send_item(p_sequencer.obs_sequencer,  16384, -16384, 0, 0, 1, {name, "_p6"});
    send_item(p_sequencer.obs_sequencer, -16384,  16384, 1, 0, 0, {name, "_p7"});
    wait_cycles(64);

    read_reg(DSM_REG_OBS_STATUS, value, {name, "_status"});
    if (!value[3])
      `uvm_error("OBS_STATUS", $sformatf("%s observer window did not complete: 0x%08x", name, value))
    read_reg(DSM_REG_OBS_CLIP_SAT, value, {name, "_clip_sat"});
    if (require_clip_or_sat && (value == 0))
      `uvm_error("OBS_STATUS", $sformatf("%s did not record clip or saturation", name))
    write_reg(DSM_REG_OBS_SNAPSHOT, 32'h1, {name, "_snapshot"});
    read_reg(DSM_REG_OBS_SNAPSHOT_ERROR_LO, value, {name, "_snapshot_lo"});
    write_reg(DSM_REG_OBS_SNAPSHOT, 32'h2, {name, "_snapshot_clear"});
  endtask

  task body();
    // Seed package two is the 20 MHz / 580 kppm anchor.  A valid condition
    // with no monitor fault is known but still requires local search by policy.
    program_condition(1, 8'd1, 16'd16, 32'd20000, 32'd580000,
                      16'sd0, 16'sd6400, 32'd0, "seed_anchor_two");
    expect_seed(3'd2, 1'b1, 1'b0, "seed_anchor_two_status");

    // Exercise the second anchor and both QAM-supported alternatives.
    program_condition(1, 8'd1, 16'd64, 32'd40000, 32'd700000,
                      -16'sd10240, 16'sd32000, 32'd0, "seed_anchor_five");
    expect_seed(3'd5, 1'b1, 1'b0, "seed_anchor_five_status");

    // Monitor faults and out-of-distribution metadata must request fallback.
    program_condition(1, 8'd1, 16'd16, 32'd20000, 32'd580000,
                      16'sd0, 16'sd6400, 32'h0000_0005, "seed_monitor_fault");
    expect_seed(3'd2, 1'b1, 1'b1, "seed_monitor_fault_status");
    program_condition(1, 8'd2, 16'd256, 32'd90000, 32'd100000,
                      16'sd12000, -16'sd12000, 32'd0, "seed_unknown");
    expect_seed(3'd2, 1'b0, 1'b1, "seed_unknown_status");

    // Restore an in-distribution condition before latching observer temperature.
    program_condition(1, 8'd1, 16'd64, 32'd40000, 32'd700000,
                      16'sd1024, 16'sd7680, 32'd0, "seed_restore");
    expect_seed(3'd5, 1'b1, 1'b0, "seed_restore_status");

    write_reg(DSM_REG_CTRL, 32'h0000_0001, "core_enable");
    send_entropy_tx();
    wait_cycles(16384);

    // The unity-gain window verifies observer start/done and snapshot behavior.
    // It must not be required to clip. The delayed complex-gain window is the
    // deliberate saturation scenario, so only that window checks clip/sat.
    observer_window(5'd0, 16'sd16384, 16'sd0, 1'b0, "observer_unity");
    observer_window(5'd3, 16'sd24576, 16'sd8192, 1'b1, "observer_complex_gain");
  endtask
endclass
