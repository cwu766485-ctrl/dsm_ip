`timescale 1ns/1ps

module tb_thermo5_ef2_pair_lookahead;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic in_valid = 1'b0;
  logic gt_ready = 1'b0;
  logic signed [511:0] in_i_poly_vec = '0;
  logic signed [511:0] in_q_poly_vec = '0;
  wire ref_in_ready, ref_gt_valid;
  wire cand_in_ready, cand_gt_valid;
  wire [63:0] ref_gt_data, cand_gt_data;
  int unsigned seed = 20261028;
  int unsigned accepted_words = 0;
  int unsigned back_to_back_accepts = 0;
  int unsigned positive_clamps = 0;
  int unsigned negative_clamps = 0;
  int unsigned output_stall_cycles = 0;
  int unsigned input_bubble_cycles = 0;
  int unsigned negative_tie_decisions = 0;
  int unsigned reset_epochs = 0;
  bit previous_accept = 1'b0;

  always #5 clk = ~clk;

  tid32_cartesian_ef2_fs4_gt_tx #(
    .W(16), .CHANNELS(32), .PAIR_LOOKAHEAD(1'b0)
  ) u_reference (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(ref_in_ready),
    .in_i_poly_vec(in_i_poly_vec), .in_q_poly_vec(in_q_poly_vec),
    .gt_valid(ref_gt_valid), .gt_ready(gt_ready), .gt_data(ref_gt_data)
  );

  tid32_cartesian_ef2_fs4_gt_tx #(
    .W(16), .CHANNELS(32), .PAIR_LOOKAHEAD(1'b1)
  ) u_candidate (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(cand_in_ready),
    .in_i_poly_vec(in_i_poly_vec), .in_q_poly_vec(in_q_poly_vec),
    .gt_valid(cand_gt_valid), .gt_ready(gt_ready), .gt_data(cand_gt_data)
  );

  task automatic set_directed(input int unsigned kind);
    for (int lane = 0; lane < 32; lane++) begin
      case (kind)
        0: begin in_i_poly_vec[lane*16 +: 16] = '0; in_q_poly_vec[lane*16 +: 16] = '0; end
        1: begin in_i_poly_vec[lane*16 +: 16] = 16'h7fff; in_q_poly_vec[lane*16 +: 16] = 16'h7fff; end
        2: begin in_i_poly_vec[lane*16 +: 16] = 16'h8000; in_q_poly_vec[lane*16 +: 16] = 16'h8000; end
        3: begin
          in_i_poly_vec[lane*16 +: 16] = lane[0] ? 16'h8000 : 16'h7fff;
          in_q_poly_vec[lane*16 +: 16] = lane[0] ? 16'h7fff : 16'h8000;
        end
        5: begin
          // With the preceding 30 zero lanes, this negative rail makes the
          // final pair's u0 exactly zero: -32768 + 2*32768 - 32768 = 0.
          in_i_poly_vec[lane*16 +: 16] = lane == 30 ? 16'h8000 : '0;
          in_q_poly_vec[lane*16 +: 16] = lane == 30 ? 16'h8000 : '0;
        end
        default: begin
          in_i_poly_vec[lane*16 +: 16] = $urandom(seed);
          in_q_poly_vec[lane*16 +: 16] = $urandom(seed);
        end
      endcase
    end
  endtask

  task automatic check_equivalence(input int cycle);
    if (ref_in_ready !== cand_in_ready || ref_gt_valid !== cand_gt_valid ||
        (ref_gt_valid && ref_gt_data !== cand_gt_data))
      $fatal(1, "pair look-ahead interface mismatch at cycle %0d", cycle);
    if ({u_reference.err1_i_q, u_reference.err2_i_q,
         u_reference.err1_q_q, u_reference.err2_q_q} !==
        {u_candidate.err1_i_q, u_candidate.err2_i_q,
         u_candidate.err1_q_q, u_candidate.err2_q_q})
      $fatal(1, "pair look-ahead state mismatch at cycle %0d", cycle);
    if (u_candidate.accept_word &&
        (!u_candidate.arithmetic_no_wrap_comb ||
         !u_candidate.arithmetic_bounds_comb))
      $fatal(1, "pair look-ahead arithmetic monitor failed at cycle %0d", cycle);
  endtask

  task automatic drain_and_reset;
    @(negedge clk);
    in_valid = 1'b0;
    gt_ready = 1'b1;
    while (ref_gt_valid || cand_gt_valid) begin
      @(posedge clk);
      #1 check_equivalence(4096);
      @(negedge clk);
    end
    rst_n = 1'b0;
    repeat (2) @(negedge clk);
    rst_n = 1'b1;
    previous_accept = 1'b0;
    reset_epochs++;
  endtask

  initial begin
    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    for (int cycle = 0; cycle < 4096; cycle++) begin
      if (cycle == 2048) drain_and_reset();
      @(negedge clk);
      gt_ready = (cycle % 4) != 0;
      if (ref_in_ready) begin
        in_valid = (cycle % 5) != 0;
        if (in_valid) begin
          // Force a directed final-pair exact tie on the first accepted word.
          if (accepted_words == 0) set_directed(5);
          else set_directed(cycle % 8);
        end
      end
      @(posedge clk);
      if (ref_gt_valid && !gt_ready) output_stall_cycles++;
      if (!in_valid && ref_in_ready) input_bubble_cycles++;
      if (u_candidate.accept_word) begin
        accepted_words++;
        // The directed final pair creates u0=0. The EF2 convention is a
        // negative quantizer decision at the exact tie, so
        // e[0]=u+Q_ONE=+32768 for this W=16 configuration.
        if (u_candidate.pair_i.u0 == 0) begin
          if (u_candidate.pair_i.q0_positive !== 1'b0 ||
              u_candidate.pair_i.e0_state !== 20'sd32768)
            $fatal(1, "exact quantizer tie did not select the negative rule");
          negative_tie_decisions++;
        end
        if (previous_accept) back_to_back_accepts++;
        if (u_candidate.clamp_positive_comb) positive_clamps++;
        if (u_candidate.clamp_negative_comb) negative_clamps++;
        previous_accept = 1'b1;
      end else begin
        previous_accept = 1'b0;
      end
      #1 check_equivalence(cycle);
    end
    @(negedge clk);
    in_valid = 1'b0;
    gt_ready = 1'b1;
    repeat (3) begin
      @(posedge clk);
      #1 check_equivalence(4096);
    end
    if (accepted_words < 100 || back_to_back_accepts == 0 ||
        positive_clamps == 0 || negative_clamps == 0 ||
        output_stall_cycles == 0 || input_bubble_cycles == 0 ||
        negative_tie_decisions == 0 || reset_epochs != 1)
      $fatal(1, "pair look-ahead coverage missing: accepted=%0d back_to_back=%0d pos=%0d neg=%0d stalls=%0d bubbles=%0d ties=%0d reset_epochs=%0d",
             accepted_words, back_to_back_accepts, positive_clamps, negative_clamps,
             output_stall_cycles, input_bubble_cycles, negative_tie_decisions,
             reset_epochs);
    $display("THERMO5_EF2_PAIR_LOOKAHEAD_PASS cycles=4096 seed=20261028 accepted=%0d back_to_back=%0d positive_clamps=%0d negative_clamps=%0d stalls=%0d bubbles=%0d negative_ties=%0d reset_epochs=%0d",
             accepted_words, back_to_back_accepts, positive_clamps, negative_clamps,
             output_stall_cycles, input_bubble_cycles, negative_tie_decisions,
             reset_epochs);
    $finish;
  end
endmodule
