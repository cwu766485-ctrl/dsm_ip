`timescale 1ns/1ps
`default_nettype none
// Research-only, single-clock, two-bank frame buffer for a continuously
// clocked raw GT boundary. A complete frame must fit MAX_FRAME_WORDS. It does
// not instantiate a GT, perform CDC, or calibrate physical PA alignment.
module thermo5_frame_prefill_tx #(
  parameter int MAX_FRAME_WORDS=56,
  parameter logic [63:0] IDLE_WORD=64'haaaaaaaaaaaaaaaa
)(
  input wire logic clk,rst_n,run_request,link_ready,
  input wire logic in_valid,
  output wire logic in_ready,
  input wire logic [255:0] in_data,
  input wire logic [3:0] in_mask,
  input wire logic [1:0] in_arch,
  input wire logic in_start,in_end,in_tail,
  input wire logic [15:0] in_config_id,in_epoch,
  output logic [255:0] gt_data,
  output logic [3:0] pa_enable_mask,
  output logic out_start,out_end,out_tail,
  output logic [1:0] out_arch,
  output logic [15:0] out_config_id,out_epoch,
  output wire logic drain_done,
  output logic protocol_fault,
  output logic frame_overflow,
  output logic link_fault
);
  localparam int CW=$clog2(MAX_FRAME_WORDS+1);
  localparam logic [1:0] FREE=0,FILL=1,READY=2,PLAY=3;
  logic [1:0] state[0:1];
  logic [255:0] mem[0:1][0:MAX_FRAME_WORDS-1];
  logic tail_mem[0:1][0:MAX_FRAME_WORDS-1];
  logic [CW-1:0] count[0:1],read_idx;
  logic [3:0] bank_mask[0:1],epoch_mask;
  logic [1:0] bank_arch[0:1],epoch_arch;
  logic [15:0] bank_cfg[0:1],bank_epoch[0:1];
  logic wr_bank,rd_bank;
  wire occupied=(state[0]!=FREE)||(state[1]!=FREE);
  wire undrained=occupied || (|pa_enable_mask);
  wire fault=protocol_fault||frame_overflow||link_fault;
  wire wr_can=(state[wr_bank]==FREE && run_request)||(state[wr_bank]==FILL);
  assign in_ready=rst_n && link_ready && !fault && wr_can;
  assign drain_done=!run_request && !undrained;
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      state[0]<=FREE;state[1]<=FREE;count[0]<=0;count[1]<=0;
      bank_mask[0]<=0;bank_mask[1]<=0;bank_cfg[0]<=0;bank_cfg[1]<=0;bank_arch[0]<=0;bank_arch[1]<=0;bank_epoch[0]<=0;bank_epoch[1]<=0;
      wr_bank<=0;rd_bank<=0;read_idx<=0;epoch_mask<=0;epoch_arch<=0;
      gt_data<={4{IDLE_WORD}};pa_enable_mask<=0;out_start<=0;out_end<=0;out_tail<=0;out_config_id<=0;out_epoch<=0;out_arch<=0;
      protocol_fault<=0;frame_overflow<=0;link_fault<=0;
    end else begin
      gt_data<={4{IDLE_WORD}};pa_enable_mask<=0;out_start<=0;out_end<=0;out_tail<=0;
      if(in_valid && undrained && (in_mask!=epoch_mask || in_arch!=epoch_arch))protocol_fault<=1;
      if(!link_ready && undrained)link_fault<=1;
      if(in_valid && in_ready) begin
        if((in_arch>2 || in_mask!=(in_arch==2 ? 4'h3 : 4'hf)) ||
           (state[wr_bank]==FREE && !in_start) ||
           (state[wr_bank]==FILL && (in_start || in_config_id!=bank_cfg[wr_bank] || in_epoch!=bank_epoch[wr_bank]))) begin
          protocol_fault<=1;
        end else begin
          if(state[wr_bank]==FREE) begin
            mem[wr_bank][0]<=in_data;tail_mem[wr_bank][0]<=in_tail;bank_mask[wr_bank]<=in_mask;bank_cfg[wr_bank]<=in_config_id;bank_epoch[wr_bank]<=in_epoch;bank_arch[wr_bank]<=in_arch;
            if(!occupied)begin epoch_mask<=in_mask;epoch_arch<=in_arch;end
            count[wr_bank]<=1;
            if(in_end)begin state[wr_bank]<=READY;wr_bank<=~wr_bank;end
            else if(MAX_FRAME_WORDS==1)frame_overflow<=1;
            else state[wr_bank]<=FILL;
          end else begin
            mem[wr_bank][count[wr_bank]]<=in_data;tail_mem[wr_bank][count[wr_bank]]<=in_tail;
            count[wr_bank]<=count[wr_bank]+1'b1;
            if(in_end)begin state[wr_bank]<=READY;wr_bank<=~wr_bank;end
            else if(count[wr_bank]==CW'(MAX_FRAME_WORDS-1))frame_overflow<=1;
          end
        end
      end
      if(link_ready && !fault && (state[rd_bank]==READY || state[rd_bank]==PLAY)) begin
        gt_data<=mem[rd_bank][state[rd_bank]==READY ? 0 : read_idx];
        pa_enable_mask<=bank_mask[rd_bank];out_config_id<=bank_cfg[rd_bank];out_epoch<=bank_epoch[rd_bank];out_arch<=bank_arch[rd_bank];
        out_tail<=tail_mem[rd_bank][state[rd_bank]==READY ? 0 : read_idx];
        out_start<=(state[rd_bank]==READY);
        if(state[rd_bank]==READY && count[rd_bank]==1 ||
           state[rd_bank]==PLAY && read_idx==count[rd_bank]-1) begin
          out_end<=1;state[rd_bank]<=FREE;count[rd_bank]<=0;rd_bank<=~rd_bank;read_idx<=0;
        end else begin
          state[rd_bank]<=PLAY;
          if(state[rd_bank]==READY)read_idx<=1;
          else read_idx<=read_idx+1'b1;
        end
      end
    end
  end
  initial if(MAX_FRAME_WORDS<1)$error("MAX_FRAME_WORDS must be positive");
endmodule
`default_nettype wire
