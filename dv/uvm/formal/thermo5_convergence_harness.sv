`timescale 1ns/1ps
// No assumptions on DUT arithmetic state: intermediate lemmas are assertions.
module thermo5_identity_lemmas_harness(
  input logic clk, rst_n, in_valid, out_ready,
  input logic signed [15:0] i_in, q_in
);
  thermo5_identity_harness model(.*);
  default clocking cb @(posedge clk); endclocking
  // Coefficient-zero lemmas retain the actual nonlinear production RTL.
  a_c3_zero: assert property (disable iff(!rst_n)
    model.dut.tap_enable_s3[0] |-> model.dut.c3r_r2_s3[0]==0 && model.dut.c3i_r2_s3[0]==0);
  a_c5_zero: assert property (disable iff(!rst_n)
    model.dut.tap_enable_s4[0] |-> model.dut.c5r_r4_s4[0]==0 && model.dut.c5i_r4_s4[0]==0);
  a_linear_coeff: assert property (disable iff(!rst_n)
    model.dut.tap_enable_s4[0] |-> model.dut.c1_re_s4[0]==64'sd16384 && model.dut.c1_im_s4[0]==0);
  a_c3_delay: assert property (disable iff(!rst_n)
    model.dut.tap_enable_s4[0] |-> model.dut.c3r_r2_s4[0]==0 && model.dut.c3i_r2_s4[0]==0);
  a_gain_identity: assert property (disable iff(!rst_n)
    model.dut.tap_enable_s5[0] |-> model.dut.gain_re_s5[0]==64'sd16384 && model.dut.gain_im_s5[0]==0);
  a_product_i: assert property (disable iff(!rst_n)
    model.dut.tap_enable_s6[0] |-> model.dut.i_gr_s6[0] inside {[-64'sd536870912:64'sd536854528]} && model.dut.q_gi_s6[0]==0);
  a_product_q: assert property (disable iff(!rst_n)
    model.dut.tap_enable_s6[0] |-> model.dut.q_gr_s6[0] inside {[-64'sd536870912:64'sd536854528]} && model.dut.i_gi_s6[0]==0);
  a_product_delay_i: assert property (disable iff(!rst_n)
    model.dut.tap_enable_s7[0] |-> model.dut.i_gr_s7[0] inside {[-64'sd536870912:64'sd536854528]} && model.dut.q_gi_s7[0]==0);
  a_product_delay_q: assert property (disable iff(!rst_n)
    model.dut.tap_enable_s7[0] |-> model.dut.q_gr_s7[0] inside {[-64'sd536870912:64'sd536854528]} && model.dut.i_gi_s7[0]==0);
  a_term_i: assert property (disable iff(!rst_n) model.dut.term_i_s8[0] inside {[-64'sd32768:64'sd32767]});
  a_term_q: assert property (disable iff(!rst_n) model.dut.term_q_s8[0] inside {[-64'sd32768:64'sd32767]});
  a_pair_i: assert property (disable iff(!rst_n) model.dut.sum_i_pair0_s8 inside {[-64'sd32768:64'sd32767]} && model.dut.sum_i_pair1_s8==0);
  a_pair_q: assert property (disable iff(!rst_n) model.dut.sum_q_pair0_s8 inside {[-64'sd32768:64'sd32767]} && model.dut.sum_q_pair1_s8==0);
  a_sum_i: assert property (disable iff(!rst_n) model.dut.sum_i_s9 inside {[-64'sd32768:64'sd32767]});
  a_sum_q: assert property (disable iff(!rst_n) model.dut.sum_q_s9 inside {[-64'sd32768:64'sd32767]});
endmodule

module thermo5_interp_bounds_harness(input logic clk,rst_n,enable,in_valid,out_ready,
  input logic signed [127:0] in_i_vec,in_q_vec);
  wire in_ready,out_valid;
  wire signed [255:0] out_i_vec,out_q_vec;
  dsm_interp_x2_polyphase_vector #(.LANES_IN(8),.INTERP_TAPS(2)) dut(.*);
  default clocking cb @(posedge clk); endclocking
  for(genvar lane=0;lane<8;lane++) begin:g_lane
    a_acc_i: assert property (disable iff(!rst_n) dut.s2_valid |-> dut.s2_acc_i[lane] inside {[-33'sd536870912:33'sd536854528]});
    a_acc_q: assert property (disable iff(!rst_n) dut.s2_valid |-> dut.s2_acc_q[lane] inside {[-33'sd536870912:33'sd536854528]});
  end
  c_accept: cover property (in_valid && in_ready);
  c_output: cover property (out_valid && out_ready);
  c_stall: cover property (out_valid && !out_ready);
  c_min: cover property (out_valid && out_i_vec[31:16]==16'h8000);
  c_max: cover property (out_valid && out_i_vec[31:16]==16'h7fff);
endmodule

// Real full-width wrapper. Reset requests are generated on the inactive
// write edge, held for >=8 write periods, and started only when busy is low.
module thermo5_xpm_fwft_harness(input logic wr_clk,rd_clk,boot_n,request,
  input logic valid_request,rd_ready,input logic [464:0] payload);
  logic rst_n;
  logic [3:0] held;
  logic wr_valid;
  logic [464:0] wr_data_vec;
  wire wr_ready,wr_full,rd_valid,rd_empty;
  wire [464:0] rd_data;
  logic seen_busy=0;
  logic [7:0] accepted=0;
  always @(posedge wr_clk) begin
    if(dut.wr_rst_busy) seen_busy<=1;
    if(!rst_n) accepted<=0;
    else if(wr_valid && wr_ready) accepted<=accepted+1;
  end
  dsm_xpm_async_fifo #(.DATA_W(465),.ADDR_W(4)) dut(
    .wr_clk,.rd_clk,.wr_rst_n(rst_n),.rd_rst_n(rst_n),.*);
  always @(negedge wr_clk or negedge boot_n)
    if(!boot_n) begin rst_n<=0;held<=0;end
    else if(!rst_n && held<8) held<=held+1;
    else if(!rst_n) rst_n<=1;
    else if(request && !dut.wr_rst_busy && !dut.rd_rst_busy) begin rst_n<=0;held<=0;end
  always @(posedge wr_clk or negedge rst_n)
    if(!rst_n) begin wr_valid<=0;wr_data_vec<=0;end
    else if(!wr_valid || wr_ready) begin wr_valid<=valid_request;wr_data_vec<=payload;end
  default clocking cb @(posedge rd_clk); endclocking
  a_fwft_legal: assert property (dut.u_xpm_fifo_async.gnuram_async_fifo.xpm_fifo_base_inst.curr_fwft_state inside {0,1,2,3});
  c_stage1: cover property (seen_busy && accepted>0 && dut.u_xpm_fifo_async.gnuram_async_fifo.xpm_fifo_base_inst.curr_fwft_state==2);
  c_reset_transition: cover property (seen_busy && accepted>0 && dut.u_xpm_fifo_async.gnuram_async_fifo.xpm_fifo_base_inst.curr_fwft_state==2 ##1 dut.u_xpm_fifo_async.gnuram_async_fifo.xpm_fifo_base_inst.curr_fwft_state==0);
  c_read: cover property (rd_valid && rd_ready);
endmodule

// Actual vendor reset RTL, exact independent-clock parameters. The legal
// environment permits a new request only after the previous sequence ends.
module thermo5_xpm_reset_contract_harness(input logic wr_clk,rd_clk,boot_n,request);
  logic rst;
  wire wr_rst,rd_rst,wr_rst_busy,rd_rst_busy;
  always @(negedge wr_clk or negedge boot_n)
    if(!boot_n) rst<=1;
    else if(!rst && wr_rst_busy) rst<=0;
    else rst<=request;
  xpm_fifo_rst #(.COMMON_CLOCK(0),.CDC_DEST_SYNC_FF(2)) dut(.*);
  default clocking cb @(posedge wr_clk); endclocking
  a_no_out_reentry: assert property (dut.gen_rst_ic.curr_wrst_state==3'b111 |=> dut.gen_rst_ic.curr_wrst_state!=3'b010);
  a_no_exit_reentry: assert property (dut.gen_rst_ic.curr_wrst_state==3'b110 |=> dut.gen_rst_ic.curr_wrst_state!=3'b010);
  c_request: cover property ($rose(rst));
  c_out: cover property (dut.gen_rst_ic.curr_wrst_state==3'b111);
  c_exit: cover property (dut.gen_rst_ic.curr_wrst_state==3'b110);
  c_recovery: cover property (wr_rst_busy ##1 !wr_rst_busy);
  c_out_reentry: cover property (dut.gen_rst_ic.curr_wrst_state==3'b111 ##1 dut.gen_rst_ic.curr_wrst_state==3'b010);
  c_exit_reentry: cover property (dut.gen_rst_ic.curr_wrst_state==3'b110 ##1 dut.gen_rst_ic.curr_wrst_state==3'b010);
endmodule

// Same residual properties with the actual XPM implementation.
module thermo5_xpm_cdc_residual_harness(
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
  dsm_axis14_to_core8_cdc #(.USE_XPM_FIFO(1'b1)) dut(
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
