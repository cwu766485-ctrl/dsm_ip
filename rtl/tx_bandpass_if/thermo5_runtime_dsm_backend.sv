`timescale 1ns/1ps
`default_nettype none

// Runtime selection is committed only by the idle/locked AXI-Lite controller.
// Inactive cores stay in reset. PA masks are physical contracts: four equal
// planes for EF1/EF2; two 1:2 weighted planes for MASH, never four equal planes.
module thermo5_runtime_dsm_backend #(
  parameter int W=16,
  parameter int STEP_EF1=7168,
  parameter int STEP_EF2=5120,
  parameter int META_DEPTH=8
)(
  input wire logic clk,rst_n,reset_arch,
  input wire logic [1:0] arch,
  input wire logic in_valid,
  output wire logic in_ready,
  input wire logic signed [32*W-1:0] in_i_vec,in_q_vec,
  input wire logic in_frame_start,in_frame_end,in_tail,
  input wire logic [15:0] in_config_id,in_epoch,
  output wire logic [3:0] pa_valid,
  input wire logic [3:0] pa_ready,
  output wire logic [63:0] pa_data[0:3],
  output wire logic out_frame_start,out_frame_end,out_tail,
  output wire logic [15:0] out_config_id,out_epoch,
  output wire logic weighted_contract,
  output wire logic [3:0] channel_mask,
  output wire logic overflow_error
);
  wire live = rst_n && !reset_arch;
  logic [3:0] ef1_valid,ef2_valid;
  logic ef1_ready,ef2_ready,mash_ready,mash_valid;
  logic [63:0] ef1_data[0:3],ef2_data[0:3];
  logic [63:0] mash0,mash1;
  logic mash_fs,mash_fe,mash_tail;
  logic [15:0] mash_config,mash_epoch;
  localparam int PTR_W=$clog2(META_DEPTH);
  logic [34:0] meta[0:META_DEPTH-1];
  logic [PTR_W-1:0] rd,wr;
  logic [$clog2(META_DEPTH+1)-1:0] count;
  wire equal_arch = arch<2;
  wire equal_space = count<META_DEPTH;
  wire push_meta = live && equal_arch && in_valid && in_ready;
  wire pop_meta = live && equal_arch && (&pa_valid) && (&pa_ready);
  wire [34:0] equal_meta = count!=0 ? meta[rd] : 35'd0;
  assign channel_mask = arch==2 ? 4'b0011 : 4'b1111;
  assign weighted_contract = arch==2;
  assign in_ready = live && ((arch==0) ? ef1_ready && equal_space :
                            (arch==1) ? ef2_ready && equal_space :
                            (arch==2) ? mash_ready : 1'b0);
  assign pa_valid = !live ? 4'd0 : arch==2 ? {2'b00,{2{mash_valid}}} :
                    count==0 ? 4'd0 : arch==0 ? ef1_valid : ef2_valid;
  for(genvar p=0;p<4;p=p+1) begin : g_output
    assign pa_data[p] = arch==0 ? ef1_data[p] : arch==1 ? ef2_data[p] :
                       p==0 ? mash0 : p==1 ? mash1 : 64'd0;
  end
  assign {out_epoch,out_config_id,out_tail,out_frame_end,out_frame_start} =
      arch==2 ? {mash_epoch,mash_config,mash_tail,mash_fe,mash_fs} : equal_meta;
  tid32_thermo5_fs4_multipa_tx #(.W(W),.STEP(STEP_EF1),.TIDSM_ORDER(1)) u_ef1(
    .clk(clk),.rst_n(live && arch==0),.in_valid(in_valid && in_ready && arch==0),
    .in_ready(ef1_ready),.in_i_poly_vec(in_i_vec),.in_q_poly_vec(in_q_vec),
    .pa_valid(ef1_valid),.pa_ready(pa_ready),.pa_data(ef1_data));
  tid32_thermo5_fs4_multipa_tx #(.W(W),.STEP(STEP_EF2),.TIDSM_ORDER(2)) u_ef2(
    .clk(clk),.rst_n(live && arch==1),.in_valid(in_valid && in_ready && arch==1),
    .in_ready(ef2_ready),.in_i_poly_vec(in_i_vec),.in_q_poly_vec(in_q_vec),
    .pa_valid(ef2_valid),.pa_ready(pa_ready),.pa_data(ef2_data));
  thermo5_mash_backend #(.W(W),.USE_ACCUMULATOR_RESIDUE(1'b1)) u_mash(
    .clk(clk),.rst_n(live && arch==2),.stop_req(1'b0),.drain_done(),
    .in_valid(in_valid && in_ready && arch==2),.in_ready(mash_ready),
    .in_i_poly_vec(in_i_vec),.in_q_poly_vec(in_q_vec),
    .in_config_id(in_config_id),.in_epoch(in_epoch),
    .in_frame_start(in_frame_start),.in_frame_end(in_frame_end),.in_tail(in_tail),
    .out_valid(mash_valid),.out_ready(&pa_ready[1:0]),
    .out_stage1_data(),.out_stage2_data(),.out_pa0_data(mash0),.out_pa1_data(mash1),
    .out_config_id(mash_config),.out_epoch(mash_epoch),
    .out_frame_start(mash_fs),.out_frame_end(mash_fe),.out_tail(mash_tail),
    .overflow_error(overflow_error),.inflight_count());
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin rd<=0;wr<=0;count<=0;end
    else if(reset_arch) begin rd<=0;wr<=0;count<=0;end
    else begin
      if(push_meta) begin
        meta[wr]<={in_epoch,in_config_id,in_tail,in_frame_end,in_frame_start};wr<=wr+1'b1;
      end
      if(pop_meta) rd<=rd+1'b1;
      case({push_meta,pop_meta})
        2'b10:count<=count+1'b1;
        2'b01:count<=count-1'b1;
        default:;
      endcase
    end
  end
endmodule
`default_nettype wire
