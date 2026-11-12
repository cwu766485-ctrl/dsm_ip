`timescale 1ns/1ps
module thermo5_rdc_dpd_epoch_harness(
 input logic clk,boot_n,epoch_n,in_valid,out_ready,
 input logic signed[15:0] i,q,c1,c3,c5
);
 wire reset_n=boot_n&&epoch_n;
 wire ir,ov;wire signed[15:0] oi,oq;
 logic[10:0] initialized;
 dpd_memory_poly #(.MAX_TAPS(1),.USE_EXTERNAL_TAPS(1)) dut(
 .clk(clk),.rst_n(reset_n),.active_taps(3'd1),
 .c1_re(c1),.c1_im(16'sd0),.c3_re(c3),.c3_im(16'sd0),.c5_re(c5),.c5_im(16'sd0),
 .i_in(i),.q_in(q),.i_tap_vec(i),.q_tap_vec(q),
 .in_valid(in_valid&&reset_n),.in_ready(ir),.out_valid(ov),.out_ready(out_ready),
 .i_out(oi),.q_out(oq),.sample_count(),.saturation_count());
 always @(posedge clk or negedge reset_n)
 if(!reset_n)initialized<=0;
 else if(ir)initialized<={initialized[9:0],in_valid};
 a_epoch_valid: assert property(@(posedge clk) ov==initialized[10]);
 a_reset_valid: assert property(@(posedge clk) !reset_n |=> reset_n || !ov);
 a_hold: assert property(@(posedge clk) disable iff(!reset_n) ov&&!out_ready |=> !reset_n || ov&&$stable(oi)&&$stable(oq));
 c_output: cover property(@(posedge clk) reset_n&&ov&&out_ready);
 c_reset_output: cover property(@(posedge clk) ov ##1 !epoch_n ##1 epoch_n ##[1:20] ov);
endmodule
