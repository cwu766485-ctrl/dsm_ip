`timescale 1ns/1ps
`default_nettype none

module tb_thermo5_elastic_pa_tx;
  logic clk = 0;
  always #5 clk = ~clk;

  logic rst_n = 0;
  logic run_request = 0;
  logic link_ready = 1;
  logic in_valid = 0;
  wire in_ready;
  logic [255:0] in_data = '0;
  logic [3:0] in_mask = 4'h3;
  logic [1:0] in_arch = 2;
  logic in_start = 0, in_end = 0, in_tail = 0;
  logic [15:0] in_config_id = 0, in_epoch = 0;
  wire [255:0] gt_data;
  wire [3:0] pa_enable_mask;
  wire out_start, out_end, out_tail;
  wire [1:0] out_arch;
  wire [15:0] out_config_id, out_epoch;
  wire drain_done, protocol_fault, frame_overflow, link_fault, underflow;

  integer phase = 1;
  integer phase_idx = 0;
  integer phase_len = 16;
  integer gap_count = 0;
  integer expected_word;
  integer expected_cfg;
  integer expected_epoch;

  thermo5_elastic_pa_tx #(.FIFO_DEPTH(16), .PREFILL_WORDS(4)) dut (.*);

  task automatic send_word(input integer value, input logic start_tag,
                           input logic end_tag, input logic tail_tag,
                           input logic [15:0] cfg, input logic [15:0] epoch);
    begin
      @(negedge clk);
      in_data = {4{64'(value)}};
      in_start = start_tag;
      in_end = end_tag;
      in_tail = tail_tag;
      in_config_id = cfg;
      in_epoch = epoch;
      in_valid = 1;
      do @(posedge clk); while (!in_ready);
    end
  endtask

  task automatic idle_source;
    begin
      @(negedge clk);
      in_valid = 0;
      in_start = 0;
      in_end = 0;
      in_tail = 0;
    end
  endtask

  always @(posedge clk) begin
    if (!rst_n) begin
      phase_idx = 0;
      gap_count = 0;
    end else begin
      if (protocol_fault || frame_overflow || link_fault)
        $fatal(1, "unexpected elastic-buffer fault");
      if (pa_enable_mask == 4'h3) begin
        if (phase_idx >= phase_len)
          $fatal(1, "too many output words phase=%0d", phase);
        case (phase)
          1: begin expected_word = phase_idx; expected_cfg = 1; expected_epoch = 0; end
          2: begin expected_word = 100 + phase_idx; expected_cfg = 2; expected_epoch = 1; end
          3: begin expected_word = 1000 + phase_idx; expected_cfg = 9; expected_epoch = 9; end
          4: begin expected_word = 200 + phase_idx; expected_cfg = 3; expected_epoch = 2; end
          5: begin expected_word = 300 + phase_idx; expected_cfg = 4; expected_epoch = 3; end
          6: begin expected_word = 400 + phase_idx; expected_cfg = 5; expected_epoch = 4; end
          default: $fatal(1, "unexpected test phase %0d", phase);
        endcase
        if (gt_data[63:0] !== 64'(expected_word) ||
            gt_data[127:64] !== 64'(expected_word) ||
            out_arch !== 2 || out_config_id !== 16'(expected_cfg) ||
            out_epoch !== 16'(expected_epoch) ||
            out_start !== ((phase == 1) ? ((phase_idx % 8) == 0) : (phase_idx == 0)) ||
            out_end !== ((phase == 1) ? ((phase_idx % 8) == 7) :
                         (((phase == 4 || phase == 5) && phase_idx == 7))) ||
            out_tail !== ((phase == 1) && (phase_idx == 15)))
          $fatal(1, "payload/metadata mismatch phase=%0d index=%0d", phase, phase_idx);
        phase_idx = phase_idx + 1;
      end else if (run_request && phase_idx < phase_len && phase_idx != 0) begin
        gap_count = gap_count + 1;
      end
    end
  end

  task automatic assert_reset;
    begin
      @(negedge clk); rst_n = 0; run_request = 0;
      #1;
      if (pa_enable_mask !== 0)
        $fatal(1, "PA did not mute immediately during reset");
      repeat (2) @(negedge clk);
      rst_n = 1;
    end
  endtask

  initial begin
    repeat (3) @(negedge clk);
    rst_n = 1;

    // Continuous two-frame stream: no PA-valid holes across the boundary.
    run_request = 1;
    for (integer i = 0; i < 16; i++)
      send_word(i, (i % 8) == 0, (i % 8) == 7, i == 15, 1, 0);
    idle_source(); run_request = 0;
    wait (phase_idx == 16 && drain_done);
    if (gap_count != 0 || underflow)
      $fatal(1, "continuous stream failed gaps=%0d underflow=%b", gap_count, underflow);

    // STOP while below the startup prefill threshold must drain accepted data.
    phase = 2; phase_idx = 0; phase_len = 2; run_request = 1;
    send_word(100, 1, 0, 0, 2, 1);
    send_word(101, 0, 0, 0, 2, 1);
    idle_source(); run_request = 0;
    wait (phase_idx == 2 && drain_done);
    assert_reset();

    // Abort an active, incomplete frame and prove old-epoch words are flushed.
    phase = 3; phase_idx = 0; phase_len = 32; run_request = 1;
    for (integer j = 0; j < 12; j++)
      send_word(1000 + j, j == 0, 0, 0, 9, 9);
    idle_source();
    wait (phase_idx >= 2);
    assert_reset();

    // New epoch after reset: no stale words may escape; STOP drains the frame.
    phase = 4; phase_idx = 0; phase_len = 8; run_request = 1;
    for (integer k = 0; k < 8; k++)
      send_word(200 + k, k == 0, k == 7, 0, 3, 2);
    idle_source(); run_request = 0;
    wait (phase_idx == 8 && drain_done);

    // STOP/Restart with a new, legal configuration/epoch.
    phase = 5; phase_idx = 0; phase_len = 8; run_request = 1;
    for (integer m = 0; m < 8; m++)
      send_word(300 + m, m == 0, m == 7, 0, 4, 3);
    idle_source(); run_request = 0;
    wait (phase_idx == 8 && drain_done);

    // Deliberate starvation after prefill is reported as an underflow.
    assert_reset();
    phase = 6; phase_idx = 0; phase_len = 8; run_request = 1;
    for (integer n = 0; n < 4; n++)
      send_word(400 + n, n == 0, 0, 0, 5, 4);
    idle_source();
    wait (underflow);
    $display("ELASTIC_PA_BUFFER_PASS continuous=16 stop_partial=2 reset_flush=1 restart=16 underflow_detected=1");
    $finish;
  end

  initial begin
    #200000;
    $fatal(1, "elastic buffer test watchdog");
  end
endmodule

`default_nettype wire
