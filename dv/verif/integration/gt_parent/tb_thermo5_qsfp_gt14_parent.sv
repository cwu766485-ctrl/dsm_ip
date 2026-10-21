`timescale 1ps/1ps
`default_nettype none

// Four-channel GT Wizard loopback at ideal clocks. This checks the parallel
// user-data boundary; it is not a measurement of board serial phase/skew.
module tb_thermo5_qsfp_gt14_parent;
  logic axi_clk125 = 1'b0, axil_clk100 = 1'b0, freerun_clk200 = 1'b0;
  logic mgtrefclk125_p = 1'b0;
  wire logic mgtrefclk125_n = ~mgtrefclk125_p;
  always #4000 axi_clk125 = ~axi_clk125;
  always #5000 axil_clk100 = ~axil_clk100;
  always #2500 freerun_clk200 = ~freerun_clk200;
  always #4000 mgtrefclk125_p = ~mgtrefclk125_p;
  logic reset_n = 1'b0, fabric_clocks_stable = 1'b0;
  logic s_axis_tvalid = 1'b0, s_axis_tlast = 1'b0, s_axis_frame_start = 1'b0;
  logic signed [223:0] s_axis_i_vec = '0, s_axis_q_vec = '0;
  logic signed [15:0] s_axis_frame_gain = 16'sd16384;
  logic [7:0] s_axil_awaddr = '0, s_axil_araddr = '0;
  logic s_axil_awvalid = 1'b0, s_axil_wvalid = 1'b0, s_axil_bready = 1'b0;
  logic [31:0] s_axil_wdata = '0;
  logic [3:0] s_axil_wstrb = '0;
  logic s_axil_arvalid = 1'b0, s_axil_rready = 1'b0;
  wire logic s_axil_awready, s_axil_wready, s_axil_bvalid;
  wire logic [1:0] s_axil_bresp;
  wire logic s_axil_arready, s_axil_rvalid;
  wire logic [31:0] s_axil_rdata;
  wire logic [1:0] s_axil_rresp;
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
      $fatal(1, "GT parent stream fault stage=%0d expected=%b pa_valid=%b pa_enable=%b core_run_request=%b core_tx_active=%b drain=%b source_phase=%0d source_closed=%b/%b cdc_empty=%b inflight=%0d word_index=%0d streaming=%b output_words=%0d underflow=%b protocol=%b",
             sim_stage, expected_stream_fault, dut.pa_valid, pa_enable,
             dut.core_run_request, dut.core_tx_active, dut.u_frontend.core_draining,
             dut.u_frontend.source_phase_q, dut.u_frontend.ingress_closed_s,
             dut.u_frontend.ingress_closed_c3, dut.u_frontend.core_data_empty,
             dut.u_frontend.outstanding_words_q, dut.u_continuous.word_index,
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

  task automatic axil_write(input logic [7:0] addr,
                            input logic [31:0] data,
                            input logic [3:0] strb,
                            input integer aw_gap,
                            input integer w_gap,
                            output logic [1:0] resp);
    begin
      // Drive AW and W independently to model legal AXI-Lite channel skew.
      fork
        begin
          repeat (aw_gap) @(negedge axil_clk100);
          s_axil_awaddr = addr;
          s_axil_awvalid = 1'b1;
          do @(posedge axil_clk100); while (!s_axil_awready);
          @(negedge axil_clk100);
          s_axil_awvalid = 1'b0;
        end
        begin
          repeat (w_gap) @(negedge axil_clk100);
          s_axil_wdata = data;
          s_axil_wstrb = strb;
          s_axil_wvalid = 1'b1;
          do @(posedge axil_clk100); while (!s_axil_wready);
          @(negedge axil_clk100);
          s_axil_wvalid = 1'b0;
        end
      join
      @(negedge axil_clk100);
      s_axil_bready = 1'b1;
      do @(posedge axil_clk100); while (!s_axil_bvalid);
      resp = s_axil_bresp;
      @(negedge axil_clk100);
      s_axil_bready = 1'b0;
    end
  endtask

  task automatic axil_read(input logic [7:0] addr,
                           output logic [31:0] data,
                           output logic [1:0] resp);
    begin
      @(negedge axil_clk100);
      s_axil_araddr = addr;
      s_axil_arvalid = 1'b1;
      do @(posedge axil_clk100); while (!s_axil_arready);
      @(negedge axil_clk100);
      s_axil_arvalid = 1'b0;
      s_axil_rready = 1'b1;
      do @(posedge axil_clk100); while (!s_axil_rvalid);
      data = s_axil_rdata;
      resp = s_axil_rresp;
      @(negedge axil_clk100);
      s_axil_rready = 1'b0;
    end
  endtask

  task automatic check_axil_reset_defaults(input string reason);
    logic [31:0] rdata;
    logic [1:0] resp;
    begin
      axil_read(8'h00, rdata, resp);
      if (resp != 2'b00 || rdata[0] != 1'b0)
        $fatal(1, "%s: AXI-Lite CONTROL did not reset, data=%08x resp=%b", reason, rdata, resp);
      axil_read(8'h04, rdata, resp);
      if (resp != 2'b00 || rdata[2:0] != 3'b000)
        $fatal(1, "%s: AXI-Lite STATUS did not reset, data=%08x resp=%b", reason, rdata, resp);
      axil_read(8'h08, rdata, resp);
      if (resp != 2'b00 || rdata[2:0] != 3'd1)
        $fatal(1, "%s: AXI-Lite TAPS default mismatch, data=%08x resp=%b", reason, rdata, resp);
      axil_read(8'h10, rdata, resp);
      if (resp != 2'b00 || rdata != 32'h0000_4000)
        $fatal(1, "%s: AXI-Lite c1_re default mismatch, data=%08x resp=%b", reason, rdata, resp);
    end
  endtask

  task automatic check_reset_release_edges;
    begin
      // Called immediately when link_ready rises. The first edge in each
      // domain must still see reset asserted; the second edge releases it.
      fork
        begin
          @(posedge axi_clk125); #1;
          if (dut.rst125_n) $fatal(1, "AXIS reset released before two AXI clock edges");
          @(posedge axi_clk125); #1;
          if (!dut.rst125_n) $fatal(1, "AXIS reset did not release on its second local edge");
        end
        begin
          @(posedge axil_clk100); #1;
          if (dut.axil_rst_n) $fatal(1, "AXI-Lite reset released before two AXI-Lite clock edges");
          @(posedge axil_clk100); #1;
          if (!dut.axil_rst_n) $fatal(1, "AXI-Lite reset did not release on its second local edge");
        end
        begin
          @(posedge core_clk218); #1;
          if (dut.rst218_n) $fatal(1, "Core reset released before two core clock edges");
          @(posedge core_clk218); #1;
          if (!dut.rst218_n) $fatal(1, "Core reset did not release on its second local edge");
        end
      join
    end
  endtask

  task automatic send_frame(input integer frame_id, input bit graceful_stop = 1'b0);
    integer value;
    logic [1:0] resp;
    bit stop_write_started, stop_write_done;
    begin
      stop_write_started = 1'b0;
      stop_write_done = 1'b0;
      beat = 0;
      while (beat < 32) begin
        @(negedge axi_clk125);
        s_axis_tvalid = 1'b1;
        s_axis_tlast = (beat == 31);
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
        if (beat == 8) begin
          // Pause AXIS after FIFO prefill while software sets RUN in the
          // independent 100-MHz AXI-Lite domain.
          @(negedge axi_clk125);
          s_axis_tvalid = 1'b0;
          s_axis_frame_start = 1'b0;
          axil_write(8'h00, 32'h0000_0001, 4'hf, 0, 2, resp);
          if (resp != 2'b00) $fatal(1, "AXI-Lite RUN write failed: %b", resp);
        end
        if (graceful_stop && beat == 16 && !stop_write_started) begin
          // Request STOP in parallel with uninterrupted source traffic. The
          // wrapper must finish the in-progress frame and keep the serializer
          // fed continuously through its 56-word boundary.
          stop_write_started = 1'b1;
          fork
            begin
              axil_write(8'h00, 32'h0000_0000, 4'hf, 0, 1, resp);
              if (resp != 2'b00) $fatal(1, "AXI-Lite graceful STOP write failed: %b", resp);
              stop_write_done = 1'b1;
            end
          join_none
        end
      end
      if (graceful_stop) wait (stop_write_done);
      @(negedge axi_clk125);
      s_axis_tvalid = 1'b0;
      s_axis_tlast = 1'b0;
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
        s_axis_tlast = 1'b0;
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
      s_axis_tlast = 1'b0;
      s_axis_frame_start = 1'b0;
    end
  endtask

  task automatic wait_link_recovery(input bit check_two_stage_release = 1'b0);
    begin
      wait (link_ready);
      if (check_two_stage_release) check_reset_release_edges();
      wait (dut.rst125_n && dut.axil_rst_n && dut.rst218_n);
      repeat (4) @(posedge core_clk218);
      if (!link_ready || !dut.rst125_n || !dut.axil_rst_n || !dut.rst218_n || pa_enable)
        $fatal(1, "GT link recovery/reset release contract failed");
    end
  endtask

  initial begin
    logic [31:0] axil_rdata;
    logic [1:0] axil_resp;
    skip_rx_compare = $test$plusargs("SKIP_RX_COMPARE");
    if (skip_rx_compare)
      $display("GT_PARENT_DIAGNOSTIC RX word comparison disabled; reset/recovery only");
    sim_stage = 1;
    repeat (50) @(negedge freerun_clk200);
    reset_n = 1'b1;
    // The controller must keep all three local resets asserted until both
    // fabric clocks are declared stable and the GT health interval qualifies.
    repeat (30) @(posedge freerun_clk200);
    if (link_ready || dut.rst125_n || dut.axil_rst_n || dut.rst218_n)
      $fatal(1, "Application resets released before fabric clock-stable qualification");
    fabric_clocks_stable = 1'b1;
    wait_link_recovery(1'b1);
    check_axil_reset_defaults("power-on");
    axil_read(8'h0c, axil_rdata, axil_resp);
    if (axil_resp != 2'b00 || axil_rdata != 32'h5448_3501)
      $fatal(1, "AXI-Lite IP_ID read failed after reset: data=%08x resp=%b", axil_rdata, axil_resp);

    // Clock-manager loss must reassert every local reset; recovery requires
    // the stable indication to return and the same GT-health qualification.
    fabric_clocks_stable = 1'b0;
    wait (!link_ready);
    #1;
    if (dut.rst125_n || dut.axil_rst_n || dut.rst218_n || pa_enable)
      $fatal(1, "Fabric clock-stability loss did not reset all domains and blank PA");
    fabric_clocks_stable = 1'b1;
    wait_link_recovery();
    check_axil_reset_defaults("fabric clock-stability loss");

    // Prepare the legal frozen one-tap identity image, commit while no stream
    // frame boundary exists, then verify the parent can start it through RUN.
    axil_write(8'h08, 32'd1, 4'hf, 0, 1, axil_resp);
    if (axil_resp != 2'b00) $fatal(1, "AXI-Lite TAPS write failed");
    axil_write(8'h10, 32'h0000_4000, 4'hf, 2, 0, axil_resp);
    if (axil_resp != 2'b00) $fatal(1, "AXI-Lite c1_re write failed");
    axil_write(8'h14, 32'h0000_0000, 4'hf, 0, 2, axil_resp);
    if (axil_resp != 2'b00) $fatal(1, "AXI-Lite c1_re upper word write failed");
    axil_write(8'h00, 32'h0000_0002, 4'hf, 0, 1, axil_resp);
    if (axil_resp != 2'b00) $fatal(1, "AXI-Lite COMMIT write failed");
    axil_read(8'h04, axil_rdata, axil_resp);
    if (axil_resp != 2'b00 || !axil_rdata[0] || axil_rdata[2])
      $fatal(1, "AXI-Lite commit did not remain busy until a frame boundary: %08x", axil_rdata);
    $display("GT_PARENT_STAGE 1 link recovered at %0t", $time);
    repeat (10) @(negedge axi_clk125);

    // Normal four-plane, 32 AXI beat -> 56 raw-word loopback.
    sim_stage = 2;
    send_frame(0, 1'b1);
    axil_read(8'h04, axil_rdata, axil_resp);
    if (axil_resp != 2'b00 || !axil_rdata[3] || !axil_rdata[4])
      $fatal(1, "STOP did not expose RUN_ACTIVE+DRAINING while the final frame was in flight: %08x", axil_rdata);
    wait (output_words >= 56);
    if (!skip_rx_compare) wait (rx_checked_frames >= 1);
    wait (!dut.core_tx_active);
    repeat (4) @(posedge core_clk218);
    axil_read(8'h04, axil_rdata, axil_resp);
    if (axil_resp != 2'b00 || axil_rdata[4:3] != 2'b00 || core_underflow)
      $fatal(1, "Graceful STOP failed to drain cleanly: status=%08x underflow=%b", axil_rdata, core_underflow);
    if (stream_fault || pa_enable) $fatal(1, "GT parent faulted or kept PA enabled after graceful drain");
    wait (dut.u_frontend.cfg_done);
    axil_read(8'h04, axil_rdata, axil_resp);
    if (axil_resp != 2'b00 || axil_rdata[2:0] != 3'b010)
      $fatal(1, "AXI-Lite commit did not complete at the DPD frame boundary: %08x", axil_rdata);
    axil_read(8'h08, axil_rdata, axil_resp);
    if (axil_resp != 2'b00 || axil_rdata[2:0] != 3'd1)
      $fatal(1, "AXI-Lite TAPS readback mismatch after configuration");
    if (!skip_rx_compare && rx_idle_run < 8)
      $fatal(1, "GT RX did not observe repeated four-lane idle words: run=%0d", rx_idle_run);
    $display("GT_PARENT_STAGE 2 TX frame emitted%s at %0t",
             skip_rx_compare ? " (RX check intentionally skipped)" : "; RX loopback/idle checked", $time);
    // RUN was already cleared two source beats before the final boundary;
    // the controller kept the GT active until all 56 PA words were consumed.

    // Create a second commit with no upcoming frame boundary. A GT-health loss
    // must asynchronously reset the AXI-Lite, AXIS and core domains and cancel
    // that in-flight mailbox request rather than applying it after recovery.
    axil_write(8'h04, 32'h0000_0002, 4'hf, 0, 0, axil_resp);
    axil_write(8'h10, 32'h0000_2000, 4'hf, 0, 2, axil_resp);
    axil_write(8'h00, 32'h0000_0002, 4'hf, 0, 0, axil_resp);
    if (axil_resp != 2'b00) $fatal(1, "AXI-Lite pending-commit setup failed");
    axil_read(8'h04, axil_rdata, axil_resp);
    if (!axil_rdata[0]) $fatal(1, "AXI-Lite reset-cancel setup did not become BUSY");
    repeat (4) @(posedge core_clk218);

    // Simulated loss of GT power-good must reset AXI-Lite plus both FIFO/core
    // domains, blank the PA, and discard the pending configuration epoch.
    force dut.powergood = 4'b0000;
    wait (!link_ready);
    #1;
    if (pa_enable || dut.rst125_n || dut.axil_rst_n || dut.rst218_n)
      $fatal(1, "GT power-good loss did not reset and blank all three application domains");
    repeat (8) @(negedge freerun_clk200);
    release dut.powergood;
    wait_link_recovery();
    check_axil_reset_defaults("GT power-good loss");
    $display("GT_PARENT_STAGE 3 power-good recovery at %0t", $time);

    // Also exercise TX-user-clock-active loss/blanking and
    // synchronized reset response/recovery (clock itself remains running in
    // this forced status test). PA blanking is immediate; reset is qualified
    // only after the status crosses into freerun_clk200.
    force dut.tx_active = 1'b0;
    #1;
    if (!link_ready || pa_enable)
      $fatal(1, "TX-active must blank PA immediately but qualify reset synchronously");
    wait (!link_ready);
    #1;
    if (dut.rst125_n || dut.axil_rst_n || dut.rst218_n)
      $fatal(1, "synchronized TX-active loss did not reset all three application domains");
    repeat (8) @(negedge freerun_clk200);
    release dut.tx_active;
    wait_link_recovery();
    check_axil_reset_defaults("GT TX-active loss");
    $display("GT_PARENT_STAGE 4 TX-active recovery at %0t", $time);

    // Restart from a fresh epoch and check another complete 56-word RX frame.
    rx_seek_base = 56;
    sim_stage = 5;
    send_frame(1);
    wait (output_words >= 112);
    if (!skip_rx_compare) wait (rx_checked_frames >= 2);
    repeat (20) @(posedge core_clk218);
    // A finite single-frame source intentionally drains after its last word;
    // sticky FIFO underflow is therefore expected while software RUN remains
    // asserted. This reset-only diagnostic checks framing/serializer faults,
    // not an indefinitely sustained source contract.
    if (stream_fault || core_protocol_error || !core_underflow)
      $fatal(1, "GT recovery replay raised a framing/serializer error fault=%b protocol=%b underflow=%b",
             stream_fault, core_protocol_error, core_underflow);
    axil_write(8'h00, 32'h0000_0000, 4'hf, 0, 1, axil_resp);

    @(negedge freerun_clk200); reset_n = 1'b0;
    #1;
    if (link_ready || pa_enable || dut.rst125_n || dut.axil_rst_n || dut.rst218_n)
      $fatal(1, "GT parent common reset did not asynchronously assert all local resets and blank output");
    repeat (4) @(posedge freerun_clk200);
    repeat (30) @(negedge freerun_clk200);
    reset_n = 1'b1;
    wait_link_recovery();
    check_axil_reset_defaults("common reset");
    $display("GT_PARENT_STAGE 5 common-reset recovery at %0t", $time);
    if (skip_rx_compare) begin
      $display("THERMO5_QSFP_GT14_PARENT_RESET_SIM_PASS accepted=%0d output=%0d reset_domains=AXIS+AXIL+CORE recovery=clock_stable+powergood+tx_active+common_reset rx_compare=SKIPPED",
               accepted, output_words);
      $finish;
    end

    // A real mid-frame source interruption is a sticky stream fault because
    // the continuous GT serializer cannot backpressure or pause. Require an
    // explicit common reset epoch before accepting a clean replay.
    axil_write(8'h00, 32'h0000_0000, 4'hf, 0, 1, axil_resp);
    repeat (4) @(posedge core_clk218);
    rx_check_enable = 1'b0;
    expected_stream_fault = 1'b1;
    axil_write(8'h00, 32'h0000_0001, 4'hf, 0, 2, axil_resp);
    send_partial_frame(2, 16);
    wait (stream_fault);
    repeat (4) @(posedge core_clk218);
    if (pa_enable || dut.tx_word !== GT_IDLE)
      $fatal(1, "mid-frame stream interruption did not blank all GT planes");
    // Stop the source-side request before the reset epoch ends. The producer
    // must prefill the FIFO again before re-enabling the consumer.
    axil_write(8'h00, 32'h0000_0000, 4'hf, 0, 0, axil_resp);
    @(negedge freerun_clk200); reset_n = 1'b0;
    #1;
    if (pa_enable || link_ready || dut.rst125_n || dut.axil_rst_n || dut.rst218_n)
      $fatal(1, "common reset failed after stream fault");
    repeat (8) @(posedge freerun_clk200);
    repeat (30) @(negedge freerun_clk200);
    reset_n = 1'b1;
    wait_link_recovery();
    check_axil_reset_defaults("stream-fault common reset");
    expected_stream_fault = 1'b0;
    rx_seek_base = expected_count;
    rx_check_enable = 1'b1;
    sim_stage = 6;
    send_frame(3, 1'b1);
    wait (output_words >= 168);
    if (!skip_rx_compare) wait (rx_checked_frames >= 3);
    wait (!dut.core_tx_active);
    if (stream_fault || core_protocol_error || core_underflow)
      $fatal(1, "GT restart after interrupted stream raised an error");

    if (skip_rx_compare)
      $display("THERMO5_QSFP_GT14_PARENT_RESET_SIM_PASS accepted=%0d output=%0d rx_frames=%0d recovery=powergood+tx_active+common_reset+midframe_restart rx_compare=SKIPPED",
               accepted, output_words, rx_checked_frames);
    else
      $display("THERMO5_QSFP_GT14_PARENT_SIM_PASS accepted=%0d output=%0d rx_frames=%0d lanes=4 words_per_frame=56 reset_domains=AXIS+AXIL+CORE idle_run=%0d recovery=clock_stable+powergood+tx_active+common_reset+midframe_restart",
               accepted, output_words, rx_checked_frames, rx_idle_run);
    $finish;
  end
endmodule

`default_nettype wire
