`timescale 1ps/1ps
`default_nettype none

// Four-channel GT Wizard loopback at ideal clocks. This checks the parallel
// user-data boundary; it is not a measurement of board serial phase/skew.
module tb_thermo5_qsfp_gt14_parent;
  logic axi_clk125 = 1'b0, freerun_clk200 = 1'b0;
  logic mgtrefclk125_p = 1'b0;
  wire logic mgtrefclk125_n = ~mgtrefclk125_p;
  always #4000 axi_clk125 = ~axi_clk125;
  always #2500 freerun_clk200 = ~freerun_clk200;
  always #4000 mgtrefclk125_p = ~mgtrefclk125_p;
  logic reset_n = 1'b0, run_request_axi = 1'b0;
  logic s_axis_tvalid = 1'b0, s_axis_frame_start = 1'b0;
  logic signed [223:0] s_axis_i_vec = '0, s_axis_q_vec = '0;
  logic signed [15:0] s_axis_frame_gain = 16'sd16384;
  wire logic s_axis_tready, s_axis_fifo_full, core_underflow;
  wire logic core_protocol_error, core_clk218, link_ready;
  wire logic pa_enable, stream_fault;
  wire logic [255:0] gt_rxdata;
  wire logic [3:0] qsfp_tx_p, qsfp_tx_n;
  wire logic [3:0] qsfp_rx_p = qsfp_tx_p;
  wire logic [3:0] qsfp_rx_n = qsfp_tx_n;
  localparam logic [255:0] GT_IDLE = {4{64'hAAAA_AAAA_AAAA_AAAA}};
  logic [255:0] expected_words [0:255];
  integer accepted = 0, output_words = 0, expected_count = 0;
  integer rx_seek_base = 0, rx_index = -1, rx_checked_frames = 0;
  integer rx_idle_run = 0;
  integer rx_debug_words = 0;
  logic rx_check_enable = 1'b1, expected_stream_fault = 1'b0;
  integer cycles = 0, beat, tx_lane, rx_lane;
  integer sim_stage = 0;
  bit skip_rx_compare = 1'b0;

  thermo5_qsfp_gt14_parent #(.ENABLE_INTERNAL_PMA_LOOPBACK(1'b1)) dut (.*);

  always @(posedge freerun_clk200) begin
    cycles <= cycles + 1;
    if (cycles > 5000)
      $fatal(1, "GT parent timeout stage=%0d time=%0t ready=%b accepted=%0d output=%0d rx_frames=%0d rx_active=%b rx_done=%b rx_cdr=%b rx_clk=%b rxdata=%h",
             sim_stage, $time, link_ready, accepted, output_words, rx_checked_frames,
             dut.rx_active_unused[0], dut.rx_done_unused[0], dut.rx_cdr_unused[0],
             dut.rx_clk_unused[0], gt_rxdata);
  end

  // Save exactly the 256-bit word consumed by the TX Wizard on each enabled
  // PA cycle; this avoids deriving a second expected stream from the frontend.
  always @(posedge core_clk218) if (reset_n) begin
    if (pa_enable) begin
      output_words <= output_words + 1;
      if (expected_count < 256) begin
        expected_words[expected_count] <= dut.tx_word;
        expected_count <= expected_count + 1;
      end
    end
    if (stream_fault && !expected_stream_fault)
      $fatal(1, "GT parent stream fault stage=%0d expected=%b pa_valid=%b pa_enable=%b run_req_axi=%b run_core=%b word_index=%0d streaming=%b output_words=%0d underflow=%b protocol=%b",
             sim_stage, expected_stream_fault, dut.pa_valid, pa_enable,
             run_request_axi, dut.run_core, dut.u_continuous.word_index,
             dut.u_continuous.streaming, output_words, core_underflow,
             core_protocol_error);
  end

  // Loopback is checked at the common recovered RX user clock. Seek each
  // frame's first word, then compare every 64-bit channel slice on every RX
  // word, preserving lane order and all 256 payload bits.
  always @(posedge dut.rx_clk_unused[0]) begin
    if (rx_debug_words < 16 && reset_n) begin
      $display("GT_RX_DEBUG t=%0t active=%b done=%b cdr=%b data=%h",
               $time, dut.rx_active_unused[0], dut.rx_done_unused[0],
               dut.rx_cdr_unused[0], gt_rxdata);
      rx_debug_words <= rx_debug_words + 1;
    end
    if (reset_n && dut.rx_active_unused[0] && dut.rx_done_unused[0] && dut.rx_cdr_unused[0]) begin
      if (gt_rxdata === GT_IDLE) rx_idle_run <= rx_idle_run + 1;
      else rx_idle_run <= 0;
      if (rx_check_enable && expected_count > rx_seek_base) begin
      if (rx_index < 0) begin
        if (gt_rxdata === expected_words[rx_seek_base]) begin
          for (rx_lane = 0; rx_lane < 4; rx_lane = rx_lane + 1)
            if (gt_rxdata[rx_lane*64 +: 64] !== expected_words[rx_seek_base][rx_lane*64 +: 64])
              $fatal(1, "RX lane %0d frame %0d word 0 mismatch", rx_lane, rx_checked_frames);
          rx_index <= 1;
        end
      end else begin
        for (rx_lane = 0; rx_lane < 4; rx_lane = rx_lane + 1)
          if (gt_rxdata[rx_lane*64 +: 64] !== expected_words[rx_seek_base+rx_index][rx_lane*64 +: 64])
            $fatal(1, "RX lane %0d frame %0d word %0d got=%h expected=%h",
                   rx_lane, rx_checked_frames, rx_index,
                   gt_rxdata[rx_lane*64 +: 64],
                   expected_words[rx_seek_base+rx_index][rx_lane*64 +: 64]);
        if (rx_index == 55) begin
          rx_checked_frames <= rx_checked_frames + 1;
          rx_index <= -1;
        end else rx_index <= rx_index + 1;
      end
      end
    end
  end

  task automatic send_frame(input integer frame_id);
    integer value;
    begin
      beat = 0;
      while (beat < 32) begin
        @(negedge axi_clk125);
        s_axis_tvalid = 1'b1;
        s_axis_frame_start = (beat == 0);
        for (tx_lane = 0; tx_lane < 14; tx_lane = tx_lane + 1) begin
          value = frame_id*1000 + beat*14 + tx_lane + 1;
          s_axis_i_vec[tx_lane*16 +: 16] = 16'(value);
          s_axis_q_vec[tx_lane*16 +: 16] = -16'(value);
        end
        if (beat >= 8) run_request_axi = 1'b1;
        @(posedge axi_clk125);
        if (s_axis_tready) begin
          accepted = accepted + 1;
          beat = beat + 1;
        end
      end
      @(negedge axi_clk125);
      s_axis_tvalid = 1'b0;
      s_axis_frame_start = 1'b0;
    end
  endtask

  task automatic send_partial_frame(input integer frame_id, input integer beats);
    integer value;
    begin
      beat = 0;
      while (beat < beats) begin
        @(negedge axi_clk125);
        s_axis_tvalid = 1'b1;
        s_axis_frame_start = (beat == 0);
        for (tx_lane = 0; tx_lane < 14; tx_lane = tx_lane + 1) begin
          value = frame_id*1000 + beat*14 + tx_lane + 1;
          s_axis_i_vec[tx_lane*16 +: 16] = 16'(value);
          s_axis_q_vec[tx_lane*16 +: 16] = -16'(value);
        end
        @(posedge axi_clk125);
        if (s_axis_tready) begin
          accepted = accepted + 1;
          beat = beat + 1;
        end
      end
      @(negedge axi_clk125);
      s_axis_tvalid = 1'b0;
      s_axis_frame_start = 1'b0;
    end
  endtask

  task automatic wait_link_recovery;
    begin
      wait (link_ready);
      wait (dut.rst125_n && dut.rst218_n);
      repeat (4) @(posedge core_clk218);
      if (!link_ready || !dut.rst125_n || !dut.rst218_n || pa_enable)
        $fatal(1, "GT link recovery/reset release contract failed");
    end
  endtask

  initial begin
    skip_rx_compare = $test$plusargs("SKIP_RX_COMPARE");
    if (skip_rx_compare)
      $display("GT_PARENT_DIAGNOSTIC RX word comparison disabled; reset/recovery only");
    sim_stage = 1;
    repeat (50) @(negedge freerun_clk200);
    reset_n = 1'b1;
    wait_link_recovery();
    $display("GT_PARENT_STAGE 1 link recovered at %0t", $time);
    repeat (10) @(negedge axi_clk125);

    // Normal four-plane, 32 AXI beat -> 56 raw-word loopback.
    sim_stage = 2;
    send_frame(0);
    wait (output_words >= 56);
    if (!skip_rx_compare) wait (rx_checked_frames >= 1);
    repeat (20) @(posedge core_clk218);
    if (stream_fault) $fatal(1, "GT parent faulted on legal post-frame idle");
    if (!skip_rx_compare && rx_idle_run < 8)
      $fatal(1, "GT RX did not observe repeated four-lane idle words: run=%0d", rx_idle_run);
    $display("GT_PARENT_STAGE 2 TX frame emitted%s at %0t",
             skip_rx_compare ? " (RX check intentionally skipped)" : "; RX loopback/idle checked", $time);
    @(negedge axi_clk125); run_request_axi = 1'b0;
    repeat (4) @(posedge core_clk218);
    if (stream_fault || pa_enable) $fatal(1, "GT parent failed clean stop/blanking");

    // Simulated loss of GT power-good must reset both FIFO domains and blank
    // the PA; restoring lock must create a clean new FIFO epoch.
    force dut.powergood = 4'b0000;
    wait (!link_ready);
    #1;
    if (pa_enable || dut.rst125_n || dut.rst218_n)
      $fatal(1, "GT power-good loss did not reset and blank both domains");
    repeat (8) @(negedge freerun_clk200);
    release dut.powergood;
    wait_link_recovery();
    $display("GT_PARENT_STAGE 3 power-good recovery at %0t", $time);

    // Also exercise TX-user-clock-active asynchronous loss/blanking and
    // synchronized reset response/recovery (clock itself remains running in
    // this forced status test). PA blanking is immediate; reset is qualified
    // only after the status crosses into freerun_clk200.
    force dut.tx_active = 1'b0;
    #1;
    if (!link_ready || pa_enable)
      $fatal(1, "TX-active must blank PA immediately but qualify reset synchronously");
    wait (!link_ready);
    #1;
    if (dut.rst125_n || dut.rst218_n)
      $fatal(1, "synchronized TX-active loss did not reset both data domains");
    repeat (8) @(negedge freerun_clk200);
    release dut.tx_active;
    wait_link_recovery();
    $display("GT_PARENT_STAGE 4 TX-active recovery at %0t", $time);

    // Restart from a fresh epoch and check another complete 56-word RX frame.
    rx_seek_base = 56;
    sim_stage = 5;
    send_frame(1);
    wait (output_words >= 112);
    if (!skip_rx_compare) wait (rx_checked_frames >= 2);
    repeat (20) @(posedge core_clk218);
    // A finite single-frame source intentionally drains after its last word;
    // sticky FIFO underflow is therefore expected while run_request remains
    // asserted. This reset-only diagnostic checks framing/serializer faults,
    // not an indefinitely sustained source contract.
    if (stream_fault || core_protocol_error)
      $fatal(1, "GT recovery replay raised a framing/serializer error fault=%b protocol=%b underflow=%b",
             stream_fault, core_protocol_error, core_underflow);
    @(negedge axi_clk125); run_request_axi = 1'b0;

    @(negedge freerun_clk200); reset_n = 1'b0;
    repeat (4) @(posedge freerun_clk200);
    if (link_ready || pa_enable) $fatal(1, "GT parent common reset did not blank output");
    repeat (30) @(negedge freerun_clk200);
    reset_n = 1'b1;
    wait_link_recovery();
    $display("GT_PARENT_STAGE 5 common-reset recovery at %0t", $time);
    if (skip_rx_compare) begin
      $display("THERMO5_QSFP_GT14_PARENT_RESET_SIM_PASS accepted=%0d output=%0d recovery=powergood+tx_active+common_reset rx_compare=SKIPPED",
               accepted, output_words);
      $finish;
    end

    // A real mid-frame source interruption is a sticky stream fault because
    // the continuous GT serializer cannot backpressure or pause. Require an
    // explicit common reset epoch before accepting a clean replay.
    @(negedge axi_clk125); run_request_axi = 1'b0;
    repeat (4) @(posedge core_clk218);
    rx_check_enable = 1'b0;
    expected_stream_fault = 1'b1;
    @(negedge axi_clk125); run_request_axi = 1'b1;
    send_partial_frame(2, 16);
    wait (stream_fault);
    repeat (4) @(posedge core_clk218);
    if (pa_enable || dut.tx_word !== GT_IDLE)
      $fatal(1, "mid-frame stream interruption did not blank all GT planes");
    // Stop the source-side request before the reset epoch ends. The producer
    // must prefill the FIFO again before re-enabling the consumer.
    @(negedge axi_clk125); run_request_axi = 1'b0;
    @(negedge freerun_clk200); reset_n = 1'b0;
    repeat (8) @(posedge freerun_clk200);
    if (pa_enable || link_ready) $fatal(1, "common reset failed after stream fault");
    repeat (30) @(negedge freerun_clk200);
    reset_n = 1'b1;
    wait_link_recovery();
    expected_stream_fault = 1'b0;
    rx_seek_base = expected_count;
    rx_check_enable = 1'b1;
    sim_stage = 6;
    send_frame(3);
    wait (output_words >= 168);
    if (!skip_rx_compare) wait (rx_checked_frames >= 3);
    if (stream_fault || core_protocol_error || core_underflow)
      $fatal(1, "GT restart after interrupted stream raised an error");
    @(negedge axi_clk125); run_request_axi = 1'b0;

    if (skip_rx_compare)
      $display("THERMO5_QSFP_GT14_PARENT_RESET_SIM_PASS accepted=%0d output=%0d rx_frames=%0d recovery=powergood+tx_active+common_reset+midframe_restart rx_compare=SKIPPED",
               accepted, output_words, rx_checked_frames);
    else
      $display("THERMO5_QSFP_GT14_PARENT_SIM_PASS accepted=%0d output=%0d rx_frames=%0d lanes=4 words_per_frame=56 idle_run=%0d recovery=powergood+tx_active+common_reset+midframe_restart",
               accepted, output_words, rx_checked_frames, rx_idle_run);
    $finish;
  end
endmodule

`default_nettype wire
