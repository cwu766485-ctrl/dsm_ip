`timescale 1ns/1ps
// Vendor-XPM FIFO FWFT, reset-contract, and 14:8 residual proofs.
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
