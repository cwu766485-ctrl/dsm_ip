`timescale 1ns/1ps
// Actual two-slot product FIFO; arbitrary data, enables, stalls and repeated
// synchronous observations of common reset. Unreset memory is never assumed 0.
module thermo5_rdc_fifo_epoch_harness(
 input logic clk, boot_n, request_reset_n, in_valid, out_ready,
 input logic [17:0] in_meta,
 input logic signed [127:0] in_i, in_q
);
 wire reset_n = boot_n && request_reset_n;
 wire in_ready,out_valid;
 wire [17:0] out_meta;
 wire signed [127:0] oi,oq;
 logic [1:0] initialized;
 logic past_valid=0;
 thermo5_vector_registered_ready_fifo #(.W(16),.LANES(8),.META_W(18)) dut(
 .clk(clk),.rst_n(reset_n),.in_valid(in_valid),.in_ready(in_ready),
 .in_meta(in_meta),.in_i_vec(in_i),.in_q_vec(in_q),.out_valid(out_valid),
 .out_ready(out_ready),.out_meta(out_meta),.out_i_vec(oi),.out_q_vec(oq));
 always @(posedge clk)begin
  past_valid<=1;
  if(!reset_n)initialized<=0;
  else if(in_valid&&in_ready)initialized[dut.wr_ptr_q]<=1;
 end
 a_reset_empty: assert property(@(posedge clk) past_valid && $past(!reset_n) |-> !out_valid && dut.count_q==0);
 a_initialized_only: assert property(@(posedge clk) disable iff(!reset_n) out_valid |-> initialized[dut.rd_ptr_q]);
 a_capacity: assert property(@(posedge clk) disable iff(!reset_n) dut.count_q<=2);
 a_empty_meta: assert property(@(posedge clk) !out_valid |-> out_meta==0);
 c_reset_live: cover property(@(posedge clk) out_valid ##1 !reset_n ##1 reset_n ##[1:5] out_valid);
 c_stall: cover property(@(posedge clk) reset_n && out_valid && !out_ready);
endmodule
