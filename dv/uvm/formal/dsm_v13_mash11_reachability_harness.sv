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

  default clocking cb @(posedge clk); endclocking

  // Standard ready/valid source contract; reset may assert again at any time.
  asm_source_payload_stable: assume property (disable iff (!rst_n)
    in_valid && !in_ready |=> in_valid && $stable({in_i_vec,in_q_vec}));

  a_atomic_four_plane_valid: assert property (
    pa_valid==4'h0 || pa_valid==4'hf);
  a_no_unreachable_weighted_level: assert property (
    (pa_valid==4'hf) |-> all_output_symbols_legal());
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
