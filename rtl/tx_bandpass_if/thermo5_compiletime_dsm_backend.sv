`timescale 1ns/1ps
`default_nettype none

// Compile-time DSM backend. Generate elaborates exactly one architecture.
// EF1/EF2 metadata is queued alongside accepted inputs; the MASH backend
// carries its frame metadata through its own transaction pipeline.
module thermo5_compiletime_dsm_backend #(
  parameter int W = 16,
  parameter int DSM_ARCH = 0,
  parameter int STEP_EF1 = 7168,
  parameter int STEP_EF2 = 5120,
  parameter int META_DEPTH = 8
) (
  input wire logic clk,
  input wire logic rst_n,
  input wire logic in_valid,
  output wire logic in_ready,
  input wire logic signed [32*W-1:0] in_i_vec,
  input wire logic signed [32*W-1:0] in_q_vec,
  input wire logic in_frame_start,
  input wire logic in_frame_end,
  input wire logic in_tail,
  input wire logic [15:0] in_config_id,
  input wire logic [15:0] in_epoch,
  output wire logic [3:0] pa_valid,
  input wire logic [3:0] pa_ready,
  output wire logic [63:0] pa_data [0:3],
  output wire logic out_frame_start,
  output wire logic out_frame_end,
  output wire logic out_tail,
  output wire logic [15:0] out_config_id,
  output wire logic [15:0] out_epoch,
  output wire logic weighted_contract,
  output wire logic [3:0] channel_mask,
  output wire logic overflow_error
);
  generate
    if (DSM_ARCH == 0) begin : g_ef1
      localparam int PTR_W = $clog2(META_DEPTH);
      logic [34:0] meta [0:META_DEPTH-1];
      logic [PTR_W-1:0] rd,wr;
      logic [$clog2(META_DEPTH+1)-1:0] count;
      logic [3:0] core_valid;
      logic core_ready;
      logic [63:0] core_data [0:3];
      wire push_meta = rst_n && in_valid && in_ready;
      wire pop_meta = rst_n && (&pa_valid) && (&pa_ready);
      wire [34:0] current_meta = (count != 0) ? meta[rd] : 35'd0;

      assign channel_mask = 4'hf;
      assign weighted_contract = 1'b0;
      assign overflow_error = 1'b0;
      assign in_ready = rst_n && core_ready && (count < META_DEPTH);
      assign pa_valid = (rst_n && count != 0) ? core_valid : 4'b0;
      for (genvar p=0;p<4;p=p+1) assign pa_data[p] = core_data[p];
      assign {out_epoch,out_config_id,out_tail,out_frame_end,out_frame_start} = current_meta;

      tid32_thermo5_fs4_multipa_tx #(.W(W),.STEP(STEP_EF1),.TIDSM_ORDER(1)) u_core(
        .clk(clk),.rst_n(rst_n),.in_valid(in_valid && in_ready),.in_ready(core_ready),
        .in_i_poly_vec(in_i_vec),.in_q_poly_vec(in_q_vec),
        .pa_valid(core_valid),.pa_ready(pa_ready),.pa_data(core_data));

      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin rd <= '0; wr <= '0; count <= '0; end
        else begin
          if (push_meta) begin
            meta[wr] <= {in_epoch,in_config_id,in_tail,in_frame_end,in_frame_start};
            wr <= wr + 1'b1;
          end
          if (pop_meta) rd <= rd + 1'b1;
          case ({push_meta,pop_meta})
            2'b10: count <= count + 1'b1;
            2'b01: count <= count - 1'b1;
            default: count <= count;
          endcase
        end
      end
    end else if (DSM_ARCH == 1) begin : g_ef2
      localparam int PTR_W = $clog2(META_DEPTH);
      logic [34:0] meta [0:META_DEPTH-1];
      logic [PTR_W-1:0] rd,wr;
      logic [$clog2(META_DEPTH+1)-1:0] count;
      logic [3:0] core_valid;
      logic core_ready;
      logic [63:0] core_data [0:3];
      wire push_meta = rst_n && in_valid && in_ready;
      wire pop_meta = rst_n && (&pa_valid) && (&pa_ready);
      wire [34:0] current_meta = (count != 0) ? meta[rd] : 35'd0;

      assign channel_mask = 4'hf;
      assign weighted_contract = 1'b0;
      assign overflow_error = 1'b0;
      assign in_ready = rst_n && core_ready && (count < META_DEPTH);
      assign pa_valid = (rst_n && count != 0) ? core_valid : 4'b0;
      for (genvar p=0;p<4;p=p+1) assign pa_data[p] = core_data[p];
      assign {out_epoch,out_config_id,out_tail,out_frame_end,out_frame_start} = current_meta;

      tid32_thermo5_fs4_multipa_tx #(.W(W),.STEP(STEP_EF2),.TIDSM_ORDER(2)) u_core(
        .clk(clk),.rst_n(rst_n),.in_valid(in_valid && in_ready),.in_ready(core_ready),
        .in_i_poly_vec(in_i_vec),.in_q_poly_vec(in_q_vec),
        .pa_valid(core_valid),.pa_ready(pa_ready),.pa_data(core_data));

      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin rd <= '0; wr <= '0; count <= '0; end
        else begin
          if (push_meta) begin
            meta[wr] <= {in_epoch,in_config_id,in_tail,in_frame_end,in_frame_start};
            wr <= wr + 1'b1;
          end
          if (pop_meta) rd <= rd + 1'b1;
          case ({push_meta,pop_meta})
            2'b10: count <= count + 1'b1;
            2'b01: count <= count - 1'b1;
            default: count <= count;
          endcase
        end
      end
    end else if (DSM_ARCH == 2) begin : g_mash11
      logic core_valid,core_ready;
      logic [63:0] pa0,pa1;
      logic frame_start,frame_end,tail;
      logic [15:0] config_id,epoch;

      assign channel_mask = 4'b0011;
      assign weighted_contract = 1'b1;
      assign pa_valid = rst_n && core_valid ? 4'b0011 : 4'b0000;
      assign pa_data[0] = pa0;
      assign pa_data[1] = pa1;
      assign pa_data[2] = 64'd0;
      assign pa_data[3] = 64'd0;
      assign {out_epoch,out_config_id,out_tail,out_frame_end,out_frame_start} =
             {epoch,config_id,tail,frame_end,frame_start};

      thermo5_mash_backend #(.W(W),.USE_ACCUMULATOR_RESIDUE(1'b1)) u_core(
        .clk(clk),.rst_n(rst_n),.stop_req(1'b0),.drain_done(),
        .in_valid(in_valid && in_ready),.in_ready(core_ready),
        .in_i_poly_vec(in_i_vec),.in_q_poly_vec(in_q_vec),
        .in_config_id(in_config_id),.in_epoch(in_epoch),
        .in_frame_start(in_frame_start),.in_frame_end(in_frame_end),.in_tail(in_tail),
        .out_valid(core_valid),.out_ready(&pa_ready[1:0]),
        .out_stage1_data(),.out_stage2_data(),.out_pa0_data(pa0),.out_pa1_data(pa1),
        .out_config_id(config_id),.out_epoch(epoch),
        .out_frame_start(frame_start),.out_frame_end(frame_end),.out_tail(tail),
        .overflow_error(overflow_error),.inflight_count());
      assign in_ready = rst_n && core_ready;
    end else begin : g_bad_arch
      initial $error("DSM_ARCH must be 0 (EF1), 1 (EF2), or 2 (MASH 1-1)");
      assign in_ready = 1'b0;
      assign pa_valid = '0;
      for (genvar p=0;p<4;p=p+1) assign pa_data[p] = '0;
      assign {out_frame_start,out_frame_end,out_tail,out_config_id,out_epoch} = '0;
      assign weighted_contract = 1'b0;
      assign channel_mask = '0;
      assign overflow_error = 1'b0;
    end
  endgenerate

  initial begin
    if (DSM_ARCH < 0 || DSM_ARCH > 2)
      $error("DSM_ARCH must be 0, 1, or 2; got %0d", DSM_ARCH);
    if (META_DEPTH < 2 || (META_DEPTH & (META_DEPTH-1)) != 0)
      $error("META_DEPTH must be a power of two >= 2");
  end
endmodule

`default_nettype wire
