`timescale 1ns/1ps
`default_nettype none

module tb_centered_cubic_pipeline_diff;
  localparam int LANES = 8;
  localparam int WORDS = 19;
  localparam int QDEPTH = 64;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic enable = 1'b1;
  logic in_valid = 1'b0;
  logic in_frame_start = 1'b0;
  logic in_frame_end = 1'b0;
  logic in_tail = 1'b0;
  logic signed [LANES*16-1:0] in_i_vec = '0;
  logic signed [LANES*16-1:0] in_q_vec = '0;
  logic ref_in_ready, dut_in_ready;
  wire ref_in_valid = in_valid && dut_in_ready;
  wire dut_in_valid = in_valid && ref_in_ready;
  logic ref_out_valid, dut_out_valid;
  logic ref_frame_start, ref_frame_end, ref_tail;
  logic dut_frame_start, dut_frame_end, dut_tail;
  logic ref_out_ready = 1'b0;
  logic dut_out_ready = 1'b0;
  logic signed [2*LANES*16-1:0] ref_i_vec, ref_q_vec;
  logic signed [2*LANES*16-1:0] dut_i_vec, dut_q_vec;

  logic signed [2*LANES*16-1:0] expected_i [0:QDEPTH-1];
  logic signed [2*LANES*16-1:0] expected_q [0:QDEPTH-1];
  logic expected_start [0:QDEPTH-1];
  logic expected_end [0:QDEPTH-1];
  logic expected_tail [0:QDEPTH-1];
  integer write_ptr = 0;
  integer read_ptr = 0;
  integer accepted = 0;
  integer received = 0;
  integer cycle = 0;
  integer first_ref_valid_cycle = -1;
  integer first_dut_valid_cycle = -1;
  integer stall_lfsr = 32'h31415927;
  logic randomized_backpressure = 1'b1;

  always #2.5 clk = ~clk;
  always @(negedge clk) begin
    if (randomized_backpressure) begin
      stall_lfsr = (stall_lfsr << 1) ^
        ((stall_lfsr[31] ^ stall_lfsr[21] ^ stall_lfsr[1] ^ stall_lfsr[0]) ? 32'h00400007 : 0);
      dut_out_ready = stall_lfsr[0] | stall_lfsr[3];
      ref_out_ready = dut_out_ready;
    end
  end

  dsm_interp_x2_centered_cubic_vector_ref #(
    .W(16), .LANES(LANES), .APPEND_TAIL_VECTOR(1'b0)
  ) reference_dut (
    .clk, .rst_n, .enable, .in_valid(ref_in_valid), .in_ready(ref_in_ready),
    .in_frame_start, .in_frame_end, .in_tail, .in_i_vec, .in_q_vec,
    .out_valid(ref_out_valid), .out_frame_start(ref_frame_start),
    .out_frame_end(ref_frame_end), .out_tail(ref_tail), .out_ready(ref_out_ready),
    .out_i_vec(ref_i_vec), .out_q_vec(ref_q_vec)
  );

  dsm_interp_x2_centered_cubic_vector #(
    .W(16), .LANES(LANES), .APPEND_TAIL_VECTOR(1'b0)
  ) candidate_dut (
    .clk, .rst_n, .enable, .in_valid(dut_in_valid), .in_ready(dut_in_ready),
    .in_frame_start, .in_frame_end, .in_tail, .in_i_vec, .in_q_vec,
    .out_valid(dut_out_valid), .out_frame_start(dut_frame_start),
    .out_frame_end(dut_frame_end), .out_tail(dut_tail), .out_ready(dut_out_ready),
    .out_i_vec(dut_i_vec), .out_q_vec(dut_q_vec)
  );

  always @(posedge clk) begin
    if (!rst_n || !enable) begin
      write_ptr = 0;
      read_ptr = 0;
      accepted = 0;
      received = 0;
      cycle = 0;
      first_ref_valid_cycle = -1;
      first_dut_valid_cycle = -1;
    end else begin
      cycle = cycle + 1;
      if (cycle > 2000) $fatal(1,
        "pipeline differential timeout accepted=%0d ref=%0d dut=%0d in_valid=%0b ready=%0b/%0b q=%0d s1=%0b s2=%0b",
        accepted, write_ptr, received, in_valid, ref_in_ready, dut_in_ready,
        candidate_dut.q_count, candidate_dut.s1_valid, candidate_dut.s2_valid);
      if (in_valid && ref_in_ready && dut_in_ready) accepted = accepted + 1;
      if (ref_out_valid && (first_ref_valid_cycle < 0))
        first_ref_valid_cycle = cycle;
      if (dut_out_valid && (first_dut_valid_cycle < 0))
        first_dut_valid_cycle = cycle;
      if (ref_out_valid && ref_out_ready) begin
        if (write_ptr >= QDEPTH) $fatal(1, "reference queue overflow");
        expected_i[write_ptr] = ref_i_vec;
        expected_q[write_ptr] = ref_q_vec;
        expected_start[write_ptr] = ref_frame_start;
        expected_end[write_ptr] = ref_frame_end;
        expected_tail[write_ptr] = ref_tail;
        write_ptr = write_ptr + 1;
      end
      if (dut_out_valid && dut_out_ready) begin
        if (read_ptr >= write_ptr) $fatal(1, "candidate produced an unexpected transaction");
        if (dut_i_vec !== expected_i[read_ptr] || dut_q_vec !== expected_q[read_ptr] ||
            dut_frame_start !== expected_start[read_ptr] ||
            dut_frame_end !== expected_end[read_ptr] || dut_tail !== expected_tail[read_ptr])
          begin
          $display("I exp=%h got=%h Q exp=%h got=%h", expected_i[read_ptr], dut_i_vec,
                   expected_q[read_ptr], dut_q_vec);
          $fatal(1,
            "bit-true or metadata mismatch at output %0d data=%0b/%0b start=%0b/%0b end=%0b/%0b tail=%0b/%0b",
            read_ptr, dut_i_vec !== expected_i[read_ptr], dut_q_vec !== expected_q[read_ptr],
            dut_frame_start, expected_start[read_ptr], dut_frame_end, expected_end[read_ptr],
            dut_tail, expected_tail[read_ptr]);
          end
        read_ptr = read_ptr + 1;
        received = received + 1;
      end
    end
  end

  task automatic send_tagged_word(
    input integer tag,
    input logic frame_start,
    input logic frame_end,
    input logic tail
  );
    begin
      @(negedge clk);
      in_valid = 1'b1;
      in_frame_start = frame_start;
      in_frame_end = frame_end;
      in_tail = tail;
      for (integer lane = 0; lane < LANES; lane = lane + 1) begin
        in_i_vec[lane*16 +: 16] = tail ? '0 : (tag*16'h013d + lane*16'h027b + 16'h0197);
        in_q_vec[lane*16 +: 16] = tail ? '0 : (~(tag*16'h01a7 + lane*16'h0119));
      end
      do @(posedge clk); while (!(ref_in_ready && dut_in_ready));
    end
  endtask

  task automatic send_complete_frame(input integer frame_tag);
    begin
      for (integer word = 0; word < 6; word = word + 1)
        send_tagged_word(frame_tag*16+word, word == 0, word == 5, 1'b0);
      send_tagged_word(frame_tag*16+6, 1'b0, 1'b0, 1'b1);
      @(negedge clk);
      in_valid = 1'b0;
      in_frame_start = 1'b0;
      in_frame_end = 1'b0;
      in_tail = 1'b0;
    end
  endtask

  task automatic reset_during_pipeline;
    begin
      randomized_backpressure = 1'b0;
      dut_out_ready = 1'b1;
      ref_out_ready = 1'b1;
      for (integer word = 0; word < 5; word = word + 1)
        send_tagged_word(100+word, word == 0, 1'b0, 1'b0);
      @(negedge clk);
      in_valid = 1'b0;
      wait (candidate_dut.s1_valid && candidate_dut.s2_valid &&
            reference_dut.can_emit_head);
      @(negedge clk);
      dut_out_ready = 1'b0;
      ref_out_ready = 1'b0;
      rst_n = 1'b0;
      repeat (2) @(posedge clk);
      @(negedge clk);
      rst_n = 1'b1;
      dut_out_ready = 1'b1;
      ref_out_ready = 1'b1;
      send_complete_frame(20);
      wait (read_ptr == 6 && write_ptr == 6 && !dut_out_valid);
      if (received != 6) $fatal(1, "reset epoch output count mismatch: %0d", received);
    end
  endtask

  task automatic stop_restart_during_pipeline;
    begin
      for (integer word = 0; word < 5; word = word + 1)
        send_tagged_word(200+word, word == 0, 1'b0, 1'b0);
      @(negedge clk);
      in_valid = 1'b0;
      wait (candidate_dut.s1_valid && candidate_dut.s2_valid);
      @(negedge clk);
      enable = 1'b0;
      @(posedge clk);
      #1;
      if (dut_out_valid || candidate_dut.s1_valid || candidate_dut.s2_valid)
        $fatal(1, "STOP did not flush valid pipeline stages");
      @(negedge clk);
      enable = 1'b1;
      send_complete_frame(30);
      wait (read_ptr == 6 && write_ptr == 6 && !dut_out_valid);
      if (received != 6) $fatal(1, "restart epoch output count mismatch: %0d", received);
    end
  endtask

  initial begin : p_stimulus
    integer lfsr;
    lfsr = 32'h5a17c3e1;
    repeat (4) @(negedge clk);
    rst_n = 1'b1;

    for (integer word = 0; word < WORDS; word = word + 1) begin
      @(negedge clk);
      in_valid = 1'b1;
      in_frame_start = (word == 0 || word == 7 || word == 14);
      in_frame_end = (word == 5 || word == 12 || word == 17);
      in_tail = (word == 6 || word == 13 || word == 18);
      for (integer lane = 0; lane < LANES; lane = lane + 1) begin
        lfsr = (lfsr << 1) ^ ((lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]) ? 32'h00400007 : 0);
        in_i_vec[lane*16 +: 16] = (word == 6 || word == 13 || word == 18) ? '0 : lfsr[15:0];
        in_q_vec[lane*16 +: 16] = (word == 6 || word == 13 || word == 18) ? '0 : lfsr[31:16];
      end
      do @(posedge clk); while (!(ref_in_ready && dut_in_ready));
    end
    @(negedge clk);
    in_valid = 1'b0;
    in_frame_start = 1'b0;
    in_frame_end = 1'b0;
    in_tail = 1'b0;

    @(negedge clk);
    dut_out_ready = 1'b1;
    wait (read_ptr == 16 && write_ptr == 16 && !dut_out_valid);
    if (accepted != WORDS)
      $fatal(1, "transaction count mismatch accepted=%0d ref=%0d dut=%0d", accepted, write_ptr, read_ptr);
    if ((first_ref_valid_cycle < 0) || (first_dut_valid_cycle - first_ref_valid_cycle != 2))
      $fatal(1, "pipeline latency delta mismatch ref=%0d dut=%0d",
        first_ref_valid_cycle, first_dut_valid_cycle);
    $display("CENTERED_CUBIC_PIPELINE_DIFF_PASS inputs=%0d outputs=%0d cycles=%0d latency_delta=%0d",
      accepted, received, cycle, first_dut_valid_cycle-first_ref_valid_cycle);
    reset_during_pipeline();
    stop_restart_during_pipeline();
    $display("CENTERED_CUBIC_PIPELINE_RESET_STOP_PASS outputs_per_epoch=6 reset_flush=1 stop_flush=1");
    $finish;
  end
endmodule

`default_nettype wire
