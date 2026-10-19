`timescale 1ns/1ps
// Identity DPD latency/payload proof under arbitrary signed samples and stalls.
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
