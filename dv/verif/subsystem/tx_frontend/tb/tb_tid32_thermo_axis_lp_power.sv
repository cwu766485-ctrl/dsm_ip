`timescale 1ns/1ps
`default_nettype none

// Activity and ordering test for the two-clock AXI thermo frontend.  Compile
// once with LP_MODE=0 and once with LP_MODE=1.  Both runs use the same useful
// sample words; the baseline testbench performs the documented external FIFO
// prefill, while LP_MODE delegates prefill/drain sequencing to the controller.
module tb_tid32_thermo_axis_lp_power #(
  parameter bit LP_MODE = 1'b0,
  parameter bit THERMO5 = 1'b0
);
  localparam int W = 16;
  localparam int TOTAL_WORDS = 512;
  localparam int BURST_WORDS = 8;
  // Sparse scheduled downlink: four short legal bursts, each separated by
  // a long no-traffic interval.  This models a periodic control/telemetry
  // allocation, not a claim about a particular 5G numerology.
  localparam int TDD_SLOT_COUNT = 4;
  localparam int TDD_IDLE_CORE_CYCLES = 1024;

  logic clk125 = 1'b0;
  logic clk218 = 1'b0;
  logic rst125_n = 1'b0;
  logic rst218_n = 1'b0;
  logic run_request = 1'b0;
  logic s_valid = 1'b0;
  logic s_frame_start = 1'b0;
  logic signed [223:0] s_i_vec = '0;
  logic signed [223:0] s_q_vec = '0;
  logic signed [15:0] s_frame_gain = 16'sd16384;
  logic signed [63:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im;
  wire s_ready, s_fifo_full, core_underflow, core_protocol_error;
  wire pa_p_valid, pa_m_valid;
  wire [63:0] pa_p_data, pa_m_data;
  wire [3:0] pa_valid;
  wire [63:0] pa_data [0:3];

  integer sent_words = 0;
  integer output_words = 0;
  integer error_count = 0;
  integer measurement_cycles = 0;
  longint unsigned core_cycles = 0;
  longint unsigned measurement_start = 0;
  logic [63:0] output_digest = 64'hcbf29ce484222325;
  string workload;

  always #4.000 clk125 = ~clk125;
  always #2.285714 clk218 = ~clk218;

  // POSTROUTE_FUNCSIM selects a routed functional-netlist OOC top rather
  // than RTL.  The workload, scoreboard, clocks, and SAIF scope remain the
  // same, allowing direct activity coverage to be measured against the DCP.
  generate
`ifdef POSTROUTE_FUNCSIM
    if (!THERMO5) begin : g_thermo3
`ifdef POSTROUTE_LP
      tid32_thermo3_axis_frontend_tx_lp_ooc u_dut (
`else
      tid32_thermo3_axis_frontend_tx_ooc u_dut (
`endif
        .clk125(clk125), .rst125_n(rst125_n), .s_valid(s_valid),
        .s_frame_start(s_frame_start), .s_i_vec(s_i_vec), .s_q_vec(s_q_vec),
        .s_frame_gain(s_frame_gain), .clk218(clk218), .rst218_n(rst218_n),
        .run_request(run_request), .s_ready(s_ready), .s_fifo_full(s_fifo_full),
        .core_underflow(core_underflow), .core_protocol_error(core_protocol_error),
        .dpd_active_taps(3'd1), .c1_re(c1_re), .c1_im(c1_im),
        .c3_re(c3_re), .c3_im(c3_im), .c5_re(c5_re), .c5_im(c5_im),
        .pa_p_valid(pa_p_valid), .pa_p_data(pa_p_data), .pa_m_valid(pa_m_valid),
        .pa_m_data(pa_m_data)
      );
    end else begin : g_thermo5
`ifdef POSTROUTE_LP
      tid32_thermo5_axis_frontend_tx_lp_ooc u_dut (
`else
      tid32_thermo5_axis_frontend_tx_ooc u_dut (
`endif
        .clk125(clk125), .rst125_n(rst125_n), .s_valid(s_valid),
        .s_frame_start(s_frame_start), .s_i_vec(s_i_vec), .s_q_vec(s_q_vec),
        .s_frame_gain(s_frame_gain), .clk218(clk218), .rst218_n(rst218_n),
        .run_request(run_request), .s_ready(s_ready), .s_fifo_full(s_fifo_full),
        .core_underflow(core_underflow), .core_protocol_error(core_protocol_error),
        .dpd_active_taps(3'd1), .c1_re(c1_re), .c1_im(c1_im),
        .c3_re(c3_re), .c3_im(c3_im), .c5_re(c5_re), .c5_im(c5_im),
        .pa_valid(pa_valid), .pa0_data(pa_data[0]), .pa1_data(pa_data[1]),
        .pa2_data(pa_data[2]), .pa3_data(pa_data[3])
      );
    end
`else
    if (!THERMO5) begin : g_thermo3
      tid32_thermo3_axis_frontend_tx #(
        .ENABLE_LOW_POWER_CTRL(LP_MODE), .FPGA_USE_XPM_FIFO(1'b0)
      ) u_dut (
        .s_axis_aclk(clk125), .s_axis_aresetn(rst125_n),
        .s_axis_tvalid(s_valid), .s_axis_tready(s_ready),
        .s_axis_i_vec(s_i_vec), .s_axis_q_vec(s_q_vec),
        .s_axis_tuser_frame_start(s_frame_start),
        .s_axis_tuser_frame_gain(s_frame_gain), .s_axis_fifo_full(s_fifo_full),
        .core_clk(clk218), .core_aresetn(rst218_n),
        .core_enable(run_request), .core_underflow(core_underflow),
        .core_protocol_error(core_protocol_error), .dpd_active_taps(3'd1),
        .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
        .c5_re(c5_re), .c5_im(c5_im),
        .pa_p_valid(pa_p_valid), .pa_p_data(pa_p_data), .pa_p_ready(1'b1),
        .pa_m_valid(pa_m_valid), .pa_m_data(pa_m_data), .pa_m_ready(1'b1)
      );
    end else begin : g_thermo5
      tid32_thermo5_axis_frontend_tx #(
        .BYPASS_DPD(1'b0), .ENABLE_LOW_POWER_CTRL(LP_MODE),
        .FPGA_USE_XPM_FIFO(1'b0)
      ) u_dut (
        .s_axis_aclk(clk125), .s_axis_aresetn(rst125_n),
        .s_axis_tvalid(s_valid), .s_axis_tready(s_ready),
        .s_axis_i_vec(s_i_vec), .s_axis_q_vec(s_q_vec),
        .s_axis_tuser_frame_start(s_frame_start),
        .s_axis_tuser_frame_gain(s_frame_gain), .s_axis_fifo_full(s_fifo_full),
        .core_clk(clk218), .core_aresetn(rst218_n),
        .core_enable(run_request), .core_underflow(core_underflow),
        .core_protocol_error(core_protocol_error), .dpd_active_taps(3'd1),
        .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
        .c5_re(c5_re), .c5_im(c5_im),
        .pa_valid(pa_valid), .pa_data(pa_data), .pa_ready(4'hf)
      );
    end
`endif
  endgenerate

  function automatic signed [15:0] sample_value(input int word_index,
                                                  input int lane_index,
                                                  input int salt);
    int value;
    begin
      value = ((word_index * 977) + (lane_index * 313) + salt) & 16'h7fff;
      sample_value = (word_index[0] ^ lane_index[0]) ? -value : value;
    end
  endfunction

  task automatic drive_words(input int first_word, input int count);
    int word_index;
    int lane;
    begin
      for (word_index = first_word;
           word_index < first_word + count;
           word_index = word_index + 1) begin
        @(negedge clk125);
        for (lane = 0; lane < 14; lane = lane + 1) begin
          s_i_vec[lane*W +: W] = sample_value(word_index, lane, 17);
          s_q_vec[lane*W +: W] = sample_value(word_index, lane, 911);
        end
        s_frame_start = ((word_index % 4) == 0);
        s_valid = 1'b1;
        do @(posedge clk125); while (!s_ready);
        sent_words = sent_words + 1;
      end
      @(negedge clk125);
      s_valid = 1'b0;
      s_frame_start = 1'b0;
    end
  endtask

  task automatic wait_outputs(input int target);
    int timeout;
    begin
      timeout = 0;
      while ((output_words < target) && (timeout < 20000)) begin
        @(posedge clk218);
        timeout = timeout + 1;
      end
      if (output_words != target) begin
        $error("output timeout target=%0d got=%0d", target, output_words);
        error_count = error_count + 1;
      end
    end
  endtask

  task automatic run_segment(input int first_word, input int count);
    int index;
    int target;
    begin
      target = output_words + ((count * 7) / 4);
      if (!LP_MODE) begin
        // The baseline has no drain protocol. Prefill only its first run, then
        // leave it enabled across workload gaps; an empty-stream underflow is
        // expected in those gaps and represents the always-active reference.
        if (!run_request) begin
          drive_words(first_word, 4);
          @(negedge clk218);
          run_request = 1'b1;
          drive_words(first_word + 4, count - 4);
        end else begin
          drive_words(first_word, count);
        end
        wait_outputs(target);
      end else begin
        @(negedge clk218);
        run_request = 1'b1;
        drive_words(first_word, count);
        @(negedge clk218);
        run_request = 1'b0;
        wait_outputs(target);
      end
    end
  endtask

  task automatic finish_measurement(input int required_cycles);
    longint unsigned target_cycle;
    begin
      measurement_cycles = required_cycles;
      target_cycle = measurement_start + required_cycles;
      if (core_cycles > target_cycle) begin
        $error("workload exceeded fixed observation window required=%0d actual=%0d",
               required_cycles, core_cycles - measurement_start);
        error_count = error_count + 1;
      end else begin
        while (core_cycles < target_cycle) @(posedge clk218);
      end
    end
  endtask

  always @(posedge clk218) begin
    core_cycles <= core_cycles + 1;
    if (rst218_n) begin
      if (!THERMO5) begin
        if (pa_p_valid !== pa_m_valid) begin
          $error("thermo3 output-valid alignment failure");
          error_count <= error_count + 1;
        end
        if (pa_p_valid && pa_m_valid) begin
          output_digest <= {output_digest[62:0], output_digest[63]} ^
                           pa_p_data ^ {pa_m_data[31:0], pa_m_data[63:32]};
          output_words <= output_words + 1;
        end
      end else if (pa_valid != 4'h0) begin
        if (pa_valid !== 4'hf) begin
          $error("thermo5 output-valid alignment failure: %b", pa_valid);
          error_count <= error_count + 1;
        end else begin
          output_digest <= {output_digest[60:0], output_digest[63:61]} ^
                           pa_data[0] ^ pa_data[1] ^ pa_data[2] ^ pa_data[3];
          output_words <= output_words + 1;
        end
      end
    end
  end

  initial begin
    c1_re = {48'sd0, 16'sd16384};
    c1_im = '0;
    c3_re = '0;
    c3_im = '0;
    c5_re = '0;
    c5_im = '0;
    if ($test$plusargs("WORKLOAD_BURST"))
      workload = "burst";
    else if ($test$plusargs("WORKLOAD_IDLE"))
      workload = "idle";
    else if ($test$plusargs("WORKLOAD_TDD_SPARSE"))
      workload = "tdd_sparse";
    else
      workload = "continuous";

    repeat (8) @(posedge clk125);
    rst125_n = 1'b1;
    repeat (8) @(posedge clk218);
    rst218_n = 1'b1;
    measurement_start = core_cycles;

    if (workload == "continuous") begin
      run_segment(0, TOTAL_WORDS);
      finish_measurement(1200);
    end else if (workload == "burst") begin
`ifdef POSTROUTE_SMOKE
      // Functional-netlist smoke: preserve the identical first burst and
      // scoring logic while bounding primitive-level simulation time.  Full
      // RTL workloads remain the power-comparison source until the netlist
      // path has established functional viability.
      run_segment(0, BURST_WORDS);
      finish_measurement(320);
`else
      run_segment(0, BURST_WORDS);
      repeat (256) @(posedge clk218);
      run_segment(8, BURST_WORDS);
      repeat (256) @(posedge clk218);
      run_segment(16, BURST_WORDS);
      repeat (256) @(posedge clk218);
      run_segment(24, BURST_WORDS);
      finish_measurement(1536);
`endif
    end else if (workload == "idle") begin
      run_segment(0, BURST_WORDS);
      finish_measurement(4608);
    end else if (workload == "tdd_sparse") begin
      // A traffic scheduler may grant small, independent downlink slots
      // separated by an extended mute interval.  Each run_segment remains
      // frame-safe: LP_MODE completes PREFILL/RUN/DRAIN before the gap.
      for (int slot = 0; slot < TDD_SLOT_COUNT; slot = slot + 1) begin
        run_segment(slot * BURST_WORDS, BURST_WORDS);
        if (slot != TDD_SLOT_COUNT - 1)
          repeat (TDD_IDLE_CORE_CYCLES) @(posedge clk218);
      end
      // Fixed common observation window: baseline and LP must have equal
      // useful data, digest, and elapsed core cycles before SAIF comparison.
      finish_measurement(4608);
    end else begin
      $fatal(1, "unknown WORKLOAD=%s", workload);
    end

    if (core_protocol_error || (LP_MODE && core_underflow)) begin
      $error("frontend protocol status underflow=%0b protocol_error=%0b",
             core_underflow, core_protocol_error);
      error_count = error_count + 1;
    end
    run_request = 1'b0;
    if (error_count != 0) $fatal(1, "power workload errors=%0d", error_count);
    $display("LP_POWER_WORKLOAD_PASS flavour=%s mode=%s workload=%s sent=%0d outputs=%0d digest=%016h cycles=%0d underflow=%0b",
             THERMO5 ? "thermo5" : "thermo3", LP_MODE ? "lp" : "baseline",
             workload, sent_words, output_words, output_digest,
             measurement_cycles, core_underflow);
    $finish;
  end
endmodule

// Fixed-configuration tops avoid platform-specific command-line generic
// parsing in the Windows Xilinx launcher (which can split NAME=VALUE).
module tb_tid32_thermo3_baseline_lp_power;
  tb_tid32_thermo_axis_lp_power #(
    .LP_MODE(1'b0), .THERMO5(1'b0)
  ) u_tb ();
endmodule

module tb_tid32_thermo3_lp_lp_power;
  tb_tid32_thermo_axis_lp_power #(
    .LP_MODE(1'b1), .THERMO5(1'b0)
  ) u_tb ();
endmodule

module tb_tid32_thermo5_baseline_lp_power;
  tb_tid32_thermo_axis_lp_power #(
    .LP_MODE(1'b0), .THERMO5(1'b1)
  ) u_tb ();
endmodule

module tb_tid32_thermo5_lp_lp_power;
  tb_tid32_thermo_axis_lp_power #(
    .LP_MODE(1'b1), .THERMO5(1'b1)
  ) u_tb ();
endmodule

`default_nettype wire
