`timescale 1ns/1ps
// DPD accepted-sample counter proofs. The bounded instance assumes at most
// 2072 acceptances per reset epoch; the unbounded instance has no such budget.
module thermo5_counter_gap_harness #(
  parameter bit BOUNDED = 1'b1
)(
  input logic clk, rst_n, in_valid, out_ready,
  input logic signed [15:0] i_in, q_in
);
  localparam logic [31:0] BUDGET=32'd2072;
  wire in_ready, out_valid;
  wire signed [15:0] i_out,q_out;
  wire [31:0] sample_count,saturation_count;
  logic [31:0] accepted;
  always @(posedge clk or negedge rst_n)
    if(!rst_n) accepted<=0;
    else if(in_valid && in_ready) accepted<=accepted+32'd1;
  dpd_memory_poly #(.MAX_TAPS(1), .USE_EXTERNAL_TAPS(1)) dut(
    .clk(clk),.rst_n(rst_n),.active_taps(3'd1),
    .c1_re(16'sd16384),.c1_im(16'sd0),.c3_re(16'sd0),
    .c3_im(16'sd0),.c5_re(16'sd0),.c5_im(16'sd0),
    .i_in(i_in),.q_in(q_in),.in_valid(in_valid),.in_ready(in_ready),
    .i_out(i_out),.q_out(q_out),.out_valid(out_valid),.out_ready(out_ready),
    .i_tap_vec(i_in),.q_tap_vec(q_in),
    .sample_count(sample_count),.saturation_count(saturation_count));
  default clocking cb @(posedge clk); endclocking
  asm_payload_stable: assume property (disable iff(!rst_n)
    in_valid && !in_ready |=> in_valid && $stable({i_in,q_in}));
  a_count_matches_acceptances: assert property (disable iff(!rst_n)
    sample_count==accepted);
  if (BOUNDED) begin : g_budget
    asm_budget: assume property (disable iff(!rst_n)
      in_valid && in_ready |-> accepted<BUDGET);
    a_budget_bound: assert property (disable iff(!rst_n) accepted<=BUDGET);
    a_high_bits_zero_in_budget: assert property (disable iff(!rst_n)
      sample_count[31:12]==0);
  end else begin : g_unbounded
    // These prove the full-width transition relation, not deep reachability
    // or URG toggle hits on high bits.
    a_increment: assert property (disable iff(!rst_n)
      in_valid && in_ready |=> sample_count==$past(sample_count)+32'd1);
    a_hold: assert property (disable iff(!rst_n)
      !(in_valid && in_ready) |=> sample_count==$past(sample_count));
    for (genvar b=0; b<32; b++) begin : g_bit
      localparam logic [31:0] LOWER_MASK = (32'h1 << b)-32'd1;
      a_bit_transition: assert property (disable iff(!rst_n)
        in_valid && in_ready |=>
        sample_count[b]==($past(sample_count[b]) ^
          (($past(sample_count)&LOWER_MASK)==LOWER_MASK)));
    end
  end
  c_accept: cover property (disable iff(!rst_n) in_valid && in_ready);
  c_count_changes: cover property (disable iff(!rst_n) sample_count==3);
  c_stall: cover property (disable iff(!rst_n) out_valid && !out_ready);
  c_stall_recovery: cover property (disable iff(!rst_n)
    out_valid && !out_ready ##1 out_valid && out_ready);
endmodule

module thermo5_counter_unbounded_harness(
  input logic clk, rst_n, in_valid, out_ready,
  input logic signed [15:0] i_in, q_in
);
  thermo5_counter_gap_harness #(.BOUNDED(1'b0)) model(.*);
endmodule
