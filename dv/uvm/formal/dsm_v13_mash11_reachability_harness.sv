`timescale 1ns/1ps
`default_nettype none

module dsm_v13_mash11_reachability_harness (
  input logic clk,
  input logic formal_reset_n,
  input logic reset_again,
  input logic in_valid,
  input logic [3:0] pa_ready,
  input logic signed [31:0] in_i_vec,
  input logic signed [31:0] in_q_vec
);
  typedef struct packed {
    logic signed [17:0] e1;
    logic signed [17:0] e2;
    logic signed [17:0] e1_to_stage2;
    logic signed [2:0] stage1_pm_prev;
    logic signed [2:0] stage2_pm_prev;
  } mash_state_t;

  typedef struct packed {
    mash_state_t state_next;
    logic signed [2:0] combined_level;
    logic signed [2:0] stage1_pm;
    logic signed [2:0] stage2_pm;
  } mash_step_t;

  wire in_ready;
  wire rst_n = formal_reset_n && !reset_again;
  wire [3:0] pa_valid;
  wire [3:0] pa_data [0:3];

  tid32_mash11_weighted_pa_tx #(.W(16), .CHANNELS(2), .ACC_W(18),
    .IN_SHIFT(0), .SATURATE(1'b1)) dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
    .in_i_vec(in_i_vec), .in_q_vec(in_q_vec), .pa_valid(pa_valid),
    .pa_data(pa_data), .pa_ready(pa_ready)
  );

  function automatic int signed decode_level(input int unsigned lane,
                                               input bit q_component);
    logic [3:0] encoded;
    bit invert_polarity;
    begin
      invert_polarity=((lane%2)==0 && q_component) ||
                      ((lane%2)==1 && !q_component);
      for (int plane=0; plane<4; plane++)
        encoded[plane]=pa_data[plane][2*lane+(q_component ? 1 : 0)] ^ invert_polarity;
      decode_level=(encoded[0] ? -3 : 0) + (encoded[1] ? -1 : 0) +
                   (encoded[2] ? 1 : 0) + (encoded[3] ? 3 : 0);
    end
  endfunction

  function automatic bit legal_level(input int signed level);
    legal_level=(level==-3 || level==-1 || level==1 || level==2 || level==3);
  endfunction

  function automatic bit all_output_symbols_legal();
    bit legal;
    begin
      legal=1'b1;
      for (int lane=0; lane<2; lane++) begin
        legal &= legal_level(decode_level(lane,1'b0));
        legal &= legal_level(decode_level(lane,1'b1));
      end
      all_output_symbols_legal=legal;
    end
  endfunction

  // Check the exact minimum-rail condition used by quantizer_input_range_cg.
  // Maximum rail with negative Stage 1 is deliberately excluded here: the
  // unconstrained-state trace reaches it after a long negative-rail history,
  // so Round 4 must hit it with a directed Product witness.
  function automatic bit minimum_rail_stage1_stays_negative(
    input logic [31:0] vector_i,
    input logic [31:0] vector_q,
    input mash_state_t initial_i_state,
    input mash_state_t initial_q_state
  );
    mash_state_t state_i, state_q;
    mash_step_t step_i, step_q;
    logic signed [15:0] sample_i, sample_q;
    bit legal;
    begin
      state_i=initial_i_state;
      state_q=initial_q_state;
      legal=1'b1;
      for (int lane=0; lane<2; lane++) begin
        sample_i=$signed(vector_i[lane*16 +: 16]);
        sample_q=$signed(vector_q[lane*16 +: 16]);
        step_i=dut.mash_advance(state_i,sample_i);
        step_q=dut.mash_advance(state_q,sample_q);
        if ((sample_i==16'sh8000 && step_i.stage1_pm>0) ||
            (sample_q==16'sh8000 && step_q.stage1_pm>0))
          legal=1'b0;
        state_i=step_i.state_next;
        state_q=step_q.state_next;
      end
      minimum_rail_stage1_stays_negative=legal;
    end
  endfunction

  default clocking cb @(posedge clk); endclocking

  // Standard ready/valid source contract; reset may assert again at any time.
  asm_source_payload_stable: assume property (disable iff (!rst_n)
    in_valid && !in_ready |=> in_valid && $stable({in_i_vec,in_q_vec}));

  a_atomic_four_plane_valid: assert property (
    pa_valid==4'h0 || pa_valid==4'hf);
  a_no_unreachable_weighted_level: assert property (
    (pa_valid==4'hf) |-> all_output_symbols_legal());
  a_minimum_rail_never_stage1_positive: assert property (disable iff (!rst_n)
    (in_valid && in_ready) |-> minimum_rail_stage1_stays_negative(
      in_i_vec,in_q_vec,dut.state_i_q,dut.state_q_q));
  a_held_word_stable: assert property (disable iff (!rst_n)
    (pa_valid==4'hf && pa_ready!=4'hf) |=>
    (pa_valid==4'hf && $stable({pa_data[0],pa_data[1],pa_data[2],pa_data[3]})));

  c_accepted_sample: cover property (disable iff (!rst_n)
    in_valid && in_ready);
  c_output_stall: cover property (disable iff (!rst_n)
    pa_valid==4'hf && pa_ready!=4'hf ##1 pa_valid==4'hf && pa_ready!=4'hf);
  c_reset_restart: cover property (
    pa_valid==4'hf ##1 reset_again ##1 !reset_again ##[1:16]
    in_valid && in_ready ##1 pa_valid==4'hf);
  c_startup_plus_two: cover property (disable iff (!rst_n)
    pa_valid==4'hf && decode_level(0,1'b0)==2);
endmodule

`default_nettype wire
