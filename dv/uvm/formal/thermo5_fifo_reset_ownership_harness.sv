`timescale 1ns/1ps
`default_nettype none
// Clock-sampled ownership after an initialized reset. No assumptions on traffic.
// Does not claim analog reset recovery/removal or metastability immunity.
module thermo5_fifo_reset_ownership_harness (
 input logic clk,rst_n,in_valid,out_ready,
 input logic [17:0] in_meta,
 input logic [8:0] tracked_bit,
 input logic signed [511:0] in_i,in_q
);
 wire ready,valid;
 wire [17:0] meta;
 wire signed [511:0] oi,oq;
 thermo5_vector_registered_ready_fifo #(.W(16),.LANES(32),.META_W(18)) dut (
 .clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_ready(ready),
 .in_meta(in_meta),.in_i_vec(in_i),.in_q_vec(in_q),
 .out_valid(valid),.out_ready(out_ready),.out_meta(meta),.out_i_vec(oi),.out_q_vec(oq));
 logic [1:0] owned;
 logic [17:0] expected_meta[0:1];
 // A time-invariant arbitrary bit proves all 512 payload bits by symmetry.
 // Keep the complete product datapath; reduce only the reference scoreboard.
 logic expected_i[0:1],expected_q[0:1];
 as_bit_constant: assume property (@(posedge clk) $stable(tracked_bit));
 always_ff @(posedge clk or negedge rst_n)
 if(!rst_n) owned <= 0;
 else begin
  if(valid && out_ready) owned[dut.rd_ptr_q] <= 0;
  if(in_valid && ready) begin
   owned[dut.wr_ptr_q] <= 1;
   expected_i[dut.wr_ptr_q] <= in_i[tracked_bit];
   expected_q[dut.wr_ptr_q] <= in_q[tracked_bit];
   expected_meta[dut.wr_ptr_q] <= in_meta;
  end
 end
 a_capacity: assert property (@(posedge clk) disable iff(!rst_n) dut.count_q <= 2);
 a_visible_owned: assert property (@(posedge clk) disable iff(!rst_n) valid |-> owned[dut.rd_ptr_q]);
 a_write_free: assert property (@(posedge clk) disable iff(!rst_n) in_valid && ready |-> !owned[dut.wr_ptr_q]);
 a_payload: assert property (@(posedge clk) disable iff(!rst_n) valid |->
 oi[tracked_bit] == expected_i[dut.rd_ptr_q] && oq[tracked_bit] == expected_q[dut.rd_ptr_q] && meta == expected_meta[dut.rd_ptr_q]);
 a_empty_metadata: assert property (@(posedge clk) !valid |-> meta == 0);
 c_full: cover property (@(posedge clk) disable iff(!rst_n) dut.count_q == 2);
 c_replace: cover property (@(posedge clk) disable iff(!rst_n) valid && out_ready && in_valid && ready);
 c_stall: cover property (@(posedge clk) disable iff(!rst_n) valid && !out_ready);
endmodule
`default_nettype wire
