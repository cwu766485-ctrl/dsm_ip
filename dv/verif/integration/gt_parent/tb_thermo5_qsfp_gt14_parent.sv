`timescale 1ps/1fs
`default_nettype none

// End-to-end AXIS-to-GTHE4 behavioral-model TX simulation. The test compares
// sampled serial TXP payloads with GT user words; it does not measure physical
// board serial phase, skew, eye, jitter, or BER.
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
  bit run_stress_mode = 1'b0, run_bad_frames_mode = 1'b0;
  integer stress_pattern = 2;
  int stress_bubble_cycles = 0;
  logic [3:0] gt_serial_samples [0:131071];
  integer gt_serial_sample_count = 0;

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

  task automatic send_frame(input integer frame_id,
                            input bit graceful_stop = 1'b0,
                            input integer pattern = 0,
                            input bit bubble_prefill = 1'b0,
                            input integer early_tlast_beat = -1);
    integer value;
    integer sample_index;
    integer random_word;
    integer gap_len;
    integer unsigned bubble_rng;
    logic [1:0] resp;
    bit stop_write_started, stop_write_done;
    begin
      stop_write_started = 1'b0;
      stop_write_done = 1'b0;
      bubble_rng = 32'h5eed_0000 + frame_id;
      case (pattern)
        1: s_axis_frame_gain = 16'sd8192;  // 0.5 in Q2.14
        3: s_axis_frame_gain = 16'sd4096;  // 0.25 in Q2.14
        default: s_axis_frame_gain = 16'sd16384;
      endcase
      beat = 0;
      while (beat < 32) begin
        if (bubble_prefill && beat < 8) begin
          random_word = $urandom(bubble_rng);
          if ((random_word & 32'h3) == 0) begin
            gap_len = 1 + ((random_word >> 2) & 32'h3);
            repeat (gap_len) begin
              @(negedge axi_clk125);
              s_axis_tvalid = 1'b0;
              s_axis_tlast = 1'b0;
              s_axis_frame_start = 1'b0;
              stress_bubble_cycles = stress_bubble_cycles + 1;
            end
          end
        end
        @(negedge axi_clk125);
        s_axis_tvalid = 1'b1;
        s_axis_tlast = (beat == 31) || (beat == early_tlast_beat);
        s_axis_frame_start = (beat == 0);
        for (tx_lane = 0; tx_lane < 14; tx_lane = tx_lane + 1) begin
          sample_index = beat*14 + tx_lane;
          case (pattern)
            1: begin // zero-amplitude frame
              s_axis_i_vec[tx_lane*16 +: 16] = 16'h0000;
              s_axis_q_vec[tx_lane*16 +: 16] = 16'h0000;
            end
            2: begin // alternating signed full-scale endpoints
              if (((beat + tx_lane) & 1) == 0) begin
                s_axis_i_vec[tx_lane*16 +: 16] = 16'h7fff;
                s_axis_q_vec[tx_lane*16 +: 16] = 16'h8000;
              end else begin
                s_axis_i_vec[tx_lane*16 +: 16] = 16'h8000;
                s_axis_q_vec[tx_lane*16 +: 16] = 16'h7fff;
              end
            end
            3: begin // one complex impulse at the start of the frame
              s_axis_i_vec[tx_lane*16 +: 16] = (sample_index == 0) ? 16'h4000 : 16'h0000;
              s_axis_q_vec[tx_lane*16 +: 16] = (sample_index == 1) ? 16'h4000 : 16'h0000;
            end
            default: begin // deterministic signed ramp
              value = frame_id*1000 + beat*14 + tx_lane + 1;
              s_axis_i_vec[tx_lane*16 +: 16] = 16'(value);
              s_axis_q_vec[tx_lane*16 +: 16] = -16'(value);
            end
          endcase
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

  // Observe the actual GT Wizard serial pins while the raw-64 idle word is
  // present. 0xAAAA... is alternating when serialized LSB-first, so sampling
  // one configured unit interval at a time must see every lane toggle. This
  // checks the generated GT model's 14-Gb/s digital TX cadence, not its
  // electrical eye or board-level link quality.
  task automatic check_gt_serial_idle_rate;
    realtime ui_ps;
    logic [3:0] previous_txp;
    integer lane;
    integer sample_index;
    integer lane_toggles [0:3];
    begin
      ui_ps = 1000.0 / 14.0;
      for (lane = 0; lane < 4; lane = lane + 1) lane_toggles[lane] = 0;
      wait (link_ready && (&dut.tx_pma_done) && dut.tx_done[0]);
      wait (dut.tx_word === GT_IDLE);
      repeat (4) @(posedge core_clk218);
      @(qsfp_tx_p[0]);
      #(ui_ps / 2.0 + 3.0);
      previous_txp = qsfp_tx_p;
      for (sample_index = 0; sample_index < 128; sample_index = sample_index + 1) begin
        #(ui_ps);
        for (lane = 0; lane < 4; lane = lane + 1) begin
          if ((qsfp_tx_p[lane] !== 1'b0 && qsfp_tx_p[lane] !== 1'b1) ||
              (qsfp_tx_n[lane] !== 1'b0 && qsfp_tx_n[lane] !== 1'b1))
            $fatal(1, "GT TX serial lane %0d is unknown at UI sample %0d", lane, sample_index);
          if (qsfp_tx_n[lane] !== ~qsfp_tx_p[lane])
            $fatal(1, "GT TX differential pins disagree on lane %0d", lane);
          if (qsfp_tx_p[lane] === previous_txp[lane])
            $fatal(1, "GT TX lane %0d did not serialize alternating idle data at 14 Gb/s, sample=%0d",
                   lane, sample_index);
          lane_toggles[lane] = lane_toggles[lane] + 1;
        end
        previous_txp = qsfp_tx_p;
      end
      for (lane = 0; lane < 4; lane = lane + 1)
        if (lane_toggles[lane] != 128)
          $fatal(1, "GT TX lane %0d serial sample count mismatch: %0d", lane, lane_toggles[lane]);
      $display("THERMO5_GT_SERIAL_IDLE_RATE_PASS line_rate_gbps=14.0 ui_ps=%0.6f lanes=4 sampled_bits_per_lane=128",
               ui_ps);
    end
  endtask

  // The serial sampler is phase-aligned to a real TXP transition, then
  // samples one 14-Gb/s UI later on each iteration. Captured pin bits are
  // matched against the four parallel GT user-data words recorded by the
  // existing scoreboard. Per-lane search allows the simulation to expose
  // channel phase offsets instead of assuming a common serial phase.
  initial begin : capture_gt_serial_pins
    realtime ui_ps;
    ui_ps = 1000.0 / 14.0;
    wait (link_ready && (&dut.tx_pma_done) && dut.tx_done[0]);
    wait (dut.tx_word === GT_IDLE);
    repeat (4) @(posedge core_clk218);
    @(qsfp_tx_p[0]);
    #(ui_ps / 2.0 + 3.0);
    forever begin
      if (gt_serial_sample_count >= 131072)
        $fatal(1, "GT serial sampler exceeded its bounded capture buffer");
      gt_serial_samples[gt_serial_sample_count] = qsfp_tx_p;
      gt_serial_sample_count = gt_serial_sample_count + 1;
      #(ui_ps);
    end
  end

  task automatic check_serial_payload_frame(input integer expected_start,
                                            input integer frame_number);
    realtime ui_ps;
    integer lane;
    integer sample_start;
    integer word_index;
    integer bit_index;
    logic [63:0] serial_word;
    logic found;
    logic match_ok;
    integer best_prefix;
    integer best_sample;
    integer prefix_words;
    bit prefix_active;
    integer diag_sample;
    bit diag_found;
    integer lane_frame_start [0:3];
    begin
      ui_ps = 1000.0 / 14.0;
      // `pa_enable` counts user words at the GT input; the generated GT model
      // has internal TX pipeline/buffer latency before those bits reach TXP.
      // Let the serializer flush one bounded 128-user-clock window before
      // inspecting the pin capture, especially in short directed scenarios.
      repeat (128) @(posedge core_clk218);
      if (gt_serial_sample_count < 56 * 64)
        $fatal(1, "GT serial capture too short before frame %0d compare", frame_number);
      for (lane = 0; lane < 4; lane = lane + 1) begin
        found = 1'b0;
        best_prefix = 0;
        best_sample = -1;
        for (sample_start = 0;
             sample_start <= gt_serial_sample_count - 56 * 64 && !found;
             sample_start = sample_start + 1) begin
          serial_word = '0;
          for (bit_index = 0; bit_index < 64; bit_index = bit_index + 1)
            serial_word[bit_index] = gt_serial_samples[sample_start + bit_index][lane];
          if (serial_word === expected_words[expected_start][lane*64 +: 64]) begin
            match_ok = 1'b1;
            prefix_words = 0;
            prefix_active = 1'b1;
            for (word_index = 0; word_index < 56; word_index = word_index + 1) begin
              serial_word = '0;
              for (bit_index = 0; bit_index < 64; bit_index = bit_index + 1)
                serial_word[bit_index] = gt_serial_samples[
                  sample_start + word_index * 64 + bit_index][lane];
              if (prefix_active &&
                  serial_word === expected_words[expected_start + word_index][lane*64 +: 64])
                prefix_words = prefix_words + 1;
              else begin
                prefix_active = 1'b0;
                match_ok = 1'b0;
              end
            end
            if (prefix_words > best_prefix) begin
              best_prefix = prefix_words;
              best_sample = sample_start;
            end
            if (match_ok) begin
              found = 1'b1;
              lane_frame_start[lane] = sample_start;
            end
          end
        end
        if (!found) begin
          if (lane == 0) begin
            diag_found = 1'b0;
            for (diag_sample = 0;
                 diag_sample <= gt_serial_sample_count - 64 && !diag_found;
                 diag_sample = diag_sample + 1) begin
              serial_word = '0;
              for (bit_index = 0; bit_index < 64; bit_index = bit_index + 1)
                serial_word[bit_index] = gt_serial_samples[diag_sample + bit_index][lane];
              if (serial_word !== 64'hAAAA_AAAA_AAAA_AAAA) begin
                $display("GT_SERIAL_FIRST_NONIDLE lane=%0d sample=%0d word=%016x",
                         lane, diag_sample, serial_word);
                diag_found = 1'b1;
              end
            end
          end
          $fatal(1, "GT serial frame %0d was not found on TX lane %0d expected_first_word=%016x best_prefix_words=%0d best_sample=%0d captured=%0d expected_count=%0d output_words=%0d",
                 frame_number, lane, expected_words[expected_start][lane*64 +: 64],
                 best_prefix, best_sample, gt_serial_sample_count, expected_count, output_words);
        end
      end
      $display("GT_SERIAL_FRAME_BITTRUE_PASS frame=%0d words_per_lane=56 bits_per_lane=3584 line_rate_gbps=14.0 ui_ps=%0.6f lane_start_samples=%0d,%0d,%0d,%0d",
               frame_number, ui_ps, lane_frame_start[0], lane_frame_start[1],
               lane_frame_start[2], lane_frame_start[3]);
    end
  endtask

  initial begin
    logic [31:0] axil_rdata;
    logic [1:0] axil_resp;
    skip_rx_compare = $test$plusargs("SKIP_RX_COMPARE");
    run_stress_mode = $test$plusargs("RUN_GT_STRESS");
    run_bad_frames_mode = $test$plusargs("RUN_GT_BAD_FRAMES");
    void'($value$plusargs("GT_PATTERN=%d", stress_pattern));
    if (run_stress_mode && run_bad_frames_mode)
      $fatal(1, "Select only one GT-parent scenario per simulation");
    if (run_stress_mode && (stress_pattern < 0 || stress_pattern > 3))
      $fatal(1, "GT_PATTERN must be 0=ramp, 1=zero, 2=signed-extremes, or 3=impulse");
    if (skip_rx_compare)
      $display("GT_PARENT_DIAGNOSTIC RX word comparison disabled; TX serial-pin sampling enabled");
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
    check_gt_serial_idle_rate();

    if (run_stress_mode) begin : run_gt_stress
      sim_stage = 20;
      // A full-scale alternating signed-endpoint packet stresses the sample
      // datapath while a fixed-seed valid-gap pattern perturbs source timing.
      // Random gaps are confined to the first eight prefill beats; after the
      // AXI-Lite RUN write completes, the rest of the packet has no injected
      // bubbles so the line-rate consumer is not intentionally underfed.
      send_frame(0, 1'b1, stress_pattern, 1'b1);
      wait (output_words >= 56);
      wait (!dut.core_tx_active);
      repeat (4) @(posedge core_clk218);
      if (stream_fault || core_protocol_error || core_underflow || pa_enable)
        $fatal(1, "GT stress frame did not drain cleanly fault=%b protocol=%b underflow=%b pa=%b",
               stream_fault, core_protocol_error, core_underflow, pa_enable);
      check_serial_payload_frame(0, 0);
      if (accepted != 32 || expected_count != 56 || output_words != 56)
        $fatal(1, "GT stress count mismatch accepted=%0d expected_words=%0d output_words=%0d",
               accepted, expected_count, output_words);
      $display("THERMO5_QSFP_GT14_STRESS_PASS frames=1 accepted_beats=%0d output_words=%0d pattern_id=%0d pattern_map=0:ramp,1:zero,2:signed_extremes,3:impulse bubble_seed=0x5eed0000 seeded_prefill_bubble_cycles=%0d line_rate_gbps=14.0 lanes=4 words_per_frame=56 rx_compare=SKIPPED",
               accepted, output_words, stress_pattern, stress_bubble_cycles);
      $finish;
    end

    if (run_bad_frames_mode) begin : run_gt_bad_frames
      integer replay_start;
      integer target_words;
      sim_stage = 30;
      rx_check_enable = 1'b0;

      // The wrapper requires TLAST on a 32-beat (56-word) quantum. Inject an
      // early marker at beat 15 but continue through the legal beat-31 TLAST.
      send_frame(10, 1'b1, 0, 1'b0, 15);
      wait (core_protocol_error);
      wait (output_words >= 56);
      wait (!dut.core_tx_active);
      repeat (4) @(posedge core_clk218);
      if (!core_protocol_error || stream_fault || core_underflow)
        $fatal(1, "Early-TLAST frame diagnostics unexpected protocol=%b stream_fault=%b underflow=%b",
               core_protocol_error, stream_fault, core_underflow);
      $display("THERMO5_GT_EARLY_TLAST_OBSERVED beat=15 legal_packet_end_beat=31 protocol_error=1");

      // A common reset is the documented epoch boundary that clears sticky
      // protocol and serializer diagnostics before replay.
      @(negedge freerun_clk200); reset_n = 1'b0;
      #1;
      if (pa_enable || dut.rst125_n || dut.axil_rst_n || dut.rst218_n)
        $fatal(1, "Reset did not assert during early-TLAST recovery");
      repeat (8) @(posedge freerun_clk200);
      repeat (30) @(negedge freerun_clk200);
      reset_n = 1'b1;
      wait_link_recovery();
      check_axil_reset_defaults("early-TLAST recovery");
      if (core_protocol_error || stream_fault || core_underflow)
        $fatal(1, "Early-TLAST diagnostics did not clear after common reset");

      replay_start = expected_count;
      target_words = output_words + 56;
      sim_stage = 31;
      send_frame(11, 1'b1);
      wait (output_words >= target_words);
      wait (!dut.core_tx_active);
      if (stream_fault || core_protocol_error || core_underflow)
        $fatal(1, "Legal replay after early-TLAST error failed");
      check_serial_payload_frame(replay_start, 0);

      // Start a second run, then stop the AXIS source after half a quantum.
      // The GT user interface cannot backpressure: it must flag the missing
      // remainder, blank PA, and present idle words until reset.
      expected_stream_fault = 1'b1;
      axil_write(8'h00, 32'h0000_0001, 4'hf, 0, 2, axil_resp);
      if (axil_resp != 2'b00) $fatal(1, "RUN write failed before partial-frame test");
      send_partial_frame(12, 16);
      wait (stream_fault);
      repeat (4) @(posedge core_clk218);
      if (!stream_fault || pa_enable || dut.tx_word !== GT_IDLE)
        $fatal(1, "Partial-frame interruption did not latch fault and blank GT payload");
      $display("THERMO5_GT_PARTIAL_FRAME_FAULT_OBSERVED accepted_beats=16 pa_enable=0 tx_word=IDLE sticky=1");

      @(negedge freerun_clk200); reset_n = 1'b0;
      #1;
      if (pa_enable || dut.rst125_n || dut.axil_rst_n || dut.rst218_n)
        $fatal(1, "Reset did not assert during partial-frame recovery");
      repeat (8) @(posedge freerun_clk200);
      repeat (30) @(negedge freerun_clk200);
      reset_n = 1'b1;
      wait_link_recovery();
      check_axil_reset_defaults("partial-frame recovery");
      expected_stream_fault = 1'b0;
      if (core_protocol_error || stream_fault || core_underflow)
        $fatal(1, "Partial-frame diagnostics did not clear after common reset");

      replay_start = expected_count;
      target_words = output_words + 56;
      sim_stage = 32;
      send_frame(13, 1'b1);
      wait (output_words >= target_words);
      wait (!dut.core_tx_active);
      if (stream_fault || core_protocol_error || core_underflow)
        $fatal(1, "Legal replay after partial-frame reset failed");
      check_serial_payload_frame(replay_start, 1);
      $display("THERMO5_QSFP_GT14_BAD_FRAMES_PASS early_tlast_protocol_error=1 partial_frame_fault=1 reset_recovery=2 legal_replay_frames=2 rx_compare=SKIPPED");
      $finish;
    end

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
      check_serial_payload_frame(0, 0);
      check_serial_payload_frame(56, 1);
      $display("THERMO5_QSFP_GT14_PARENT_TX_SERIAL_SIM_PASS accepted=%0d output=%0d serial_frames=2 words_per_lane=56 bits_per_lane=3584 lanes=4 line_rate_gbps=14.0 reset_domains=AXIS+AXIL+CORE rx_compare=SKIPPED",
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
