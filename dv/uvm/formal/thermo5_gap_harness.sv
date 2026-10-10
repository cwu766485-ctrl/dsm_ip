`timescale 1ns/1ps
// Scoped proofs of production RTL. Runtime reset changes on the inactive
// clock edge, so reset/active-edge simulator collisions are outside this model.
module thermo5_reset_gap_harness(input logic clk, boot_n, reset_request);
  logic arst_n;
  wire srst_n;
  always @(negedge clk or negedge boot_n)
    if (!boot_n) arst_n <= 1'b0;
    else arst_n <= !reset_request;
  dsm_reset_sync dut(.clk(clk),.arst_n(arst_n),.srst_n(srst_n));
  default clocking cb @(posedge clk); endclocking
  a_reset_low_clears_stage0: assert property (!arst_n |-> !dut.sync_q[0]);
  a_reset_low_clears_output: assert property (!arst_n |-> !srst_n);
  a_stage0_required_for_output: assert property (srst_n |-> dut.sync_q[0]);
  c_reset_held: cover property (!arst_n && !dut.sync_q[0]);
  c_first_release_sample: cover property (arst_n && !dut.sync_q[0]);
  c_released: cover property (arst_n && srst_n);
  c_runtime_reassert: cover property (srst_n ##1 !arst_n ##1 arst_n ##2 srst_n);
  // Expected unreachable: the red URG 1/0 operand combination.
  c_collision_bin: cover property (!arst_n && dut.sync_q[0]);
endmodule

// Counter range is scoped to <=2072 accepted inputs since reset. No counter
// width or state is reduced. Ghost count tracks interface acceptances, not
// DUT counter values. Datapath values and legal output stalls are arbitrary.
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
    // All 32 bits remain production width. These are transition proofs,
    // not deep reachability claims or replacement URG toggle hits.
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

// Full production CDC with independent clocks and legal public AXIS input.
// No assumption constrains the DUT residual state or internal FIFO contents.
module thermo5_cdc_residual_harness(
  input logic s_axis_aclk, core_clk, rst_n,
  input logic in_valid, core_enable, core_ready,
  input logic signed [223:0] in_i, in_q,
  input logic frame_start,
  input logic signed [15:0] frame_gain
);
  wire in_ready, fifo_full, core_valid, core_frame_start;
  wire signed [127:0] core_i,core_q;
  wire signed [15:0] core_frame_gain;
  wire underflow,protocol_error;
  logic axis_valid,axis_frame_start;
  logic signed [223:0] axis_i,axis_q;
  logic signed [15:0] axis_frame_gain;
  // Construct a legal source instead of solving a 465-bit stability
  // assumption. Free payload/valid requests enter only when this slot is free.
  always @(posedge s_axis_aclk or negedge rst_n) begin
    if(!rst_n) begin
      axis_valid<=0; axis_i<=0; axis_q<=0;
      axis_frame_start<=0; axis_frame_gain<=0;
    end else if(!axis_valid || in_ready) begin
      axis_valid<=in_valid; axis_i<=in_i; axis_q<=in_q;
      axis_frame_start<=frame_start; axis_frame_gain<=frame_gain;
    end
  end
  dsm_axis14_to_core8_cdc #(.USE_XPM_FIFO(1'b0)) dut(
    .s_axis_aclk(s_axis_aclk),.s_axis_aresetn(rst_n),
    .s_axis_tvalid(axis_valid),.s_axis_tready(in_ready),
    .s_axis_i_vec(axis_i),.s_axis_q_vec(axis_q),
    .s_axis_tuser_frame_start(axis_frame_start),.s_axis_tuser_frame_gain(axis_frame_gain),
    .s_axis_fifo_full(fifo_full),.core_clk(core_clk),.core_aresetn(rst_n),
    .core_enable(core_enable),.core_drain(1'b0),.core_ready(core_ready),
    .core_valid(core_valid),.core_i_vec(core_i),.core_q_vec(core_q),
    .core_frame_start(core_frame_start),.core_frame_gain(core_frame_gain),
    .core_underflow(underflow),.core_protocol_error(protocol_error));
  a_axis_stable: assert property (@(posedge s_axis_aclk) disable iff(!rst_n)
    axis_valid && !in_ready |=> axis_valid && $stable({axis_i,axis_q,axis_frame_start,axis_frame_gain}));
  default clocking cb @(posedge core_clk); endclocking
  a_residual_legal: assert property (disable iff(!dut.c_rst_n)
    dut.rem_count_q inside {0,2,4,6,8,10,12});
  a_residual_even: assert property (disable iff(!dut.c_rst_n) !dut.rem_count_q[0]);
  a_residual_bound: assert property (disable iff(!dut.c_rst_n) dut.rem_count_q<=12);
  a_frame_marker_has_valid: assert property (disable iff(!dut.c_rst_n)
    dut.out_frame_start_q |-> dut.out_valid_q);
  a_unused_residual_i_zero: assert property (disable iff(!dut.c_rst_n)
    dut.rem_i_q[223:192]==0);
  a_unused_residual_q_zero: assert property (disable iff(!dut.c_rst_n)
    dut.rem_q_q[223:192]==0);
  for(genvar r=0;r<7;r++) begin : g_residual
    c_residual: cover property (disable iff(!dut.c_rst_n) dut.rem_count_q==2*r);
  end
  c_core_stall: cover property (disable iff(!dut.c_rst_n) core_valid && !core_ready);
  c_core_accept: cover property (disable iff(!dut.c_rst_n) core_valid && core_ready);
endmodule

// Arithmetic and latency checker uses a separate payload/valid shift register.
// Pipeline advances only when its public output can accept a new slot.
module thermo5_identity_harness(
  input logic clk,rst_n,in_valid,out_ready,
  input logic signed [15:0] i_in,q_in
);
  wire in_ready,out_valid;
  wire signed [15:0] i_out,q_out;
  wire [31:0] sample_count,saturation_count;
  logic signed [15:0] expected_i[0:10],expected_q[0:10];
  logic [10:0] expected_valid;
  wire advance=out_ready || !out_valid;
  dpd_memory_poly #(.MAX_TAPS(1),.USE_EXTERNAL_TAPS(1)) dut(
    .clk(clk),.rst_n(rst_n),.active_taps(3'd1),
    .c1_re(16'sd16384),.c1_im(16'sd0),.c3_re(16'sd0),.c3_im(16'sd0),
    .c5_re(16'sd0),.c5_im(16'sd0),.i_in(i_in),.q_in(q_in),
    .in_valid(in_valid),.in_ready(in_ready),.i_out(i_out),.q_out(q_out),
    .out_valid(out_valid),.out_ready(out_ready),.i_tap_vec(i_in),.q_tap_vec(q_in),
    .sample_count(sample_count),.saturation_count(saturation_count));
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      expected_valid<=0;
      for(int p=0;p<11;p++) begin expected_i[p]<=0; expected_q[p]<=0; end
    end else if(advance) begin
      expected_valid<={expected_valid[9:0],in_valid};
      expected_i[0]<=i_in; expected_q[0]<=q_in;
      for(int p=1;p<11;p++) begin expected_i[p]<=expected_i[p-1]; expected_q[p]<=expected_q[p-1]; end
    end
  end
  default clocking cb @(posedge clk); endclocking
  asm_payload_stable: assume property (disable iff(!rst_n)
    in_valid && !in_ready |=> in_valid && $stable({i_in,q_in}));
  a_no_saturation_i: assert property (disable iff(!rst_n) !dut.sat_i);
  a_no_saturation_q: assert property (disable iff(!rst_n) !dut.sat_q);
  a_saturation_count_zero: assert property (disable iff(!rst_n) saturation_count==0);
  a_valid_latency: assert property (disable iff(!rst_n) out_valid==expected_valid[10]);
  a_identity_payload: assert property (disable iff(!rst_n)
    out_valid |-> {i_out,q_out}=={expected_i[10],expected_q[10]});
  c_min_endpoint: cover property (disable iff(!rst_n) out_valid && i_out==16'sh8000);
  c_max_endpoint: cover property (disable iff(!rst_n) out_valid && i_out==16'sh7fff);
  c_stall: cover property (disable iff(!rst_n) out_valid && !out_ready);
  c_recovery: cover property (disable iff(!rst_n) out_valid && !out_ready ##1 out_valid && out_ready);
endmodule
