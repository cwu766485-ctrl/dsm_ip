`timescale 1ns/1ps
`default_nettype none

// Elaboration-time DSM and PA-contract selection after the shared Pre-DSM
// boundary. DSM_ARCH: 0=EF1, 1=EF2, 2=Weighted MASH 1-1.
module thermo5_unified_dsm_backend #(
  parameter int W = 16,
  parameter int CHANNELS = 32,
  parameter int STEP = 5120,
  parameter int DSM_ARCH = 0,
  parameter int MASH_FIFO_DEPTH = 64,
  parameter int META_DEPTH = 16
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic stop_req,
  output wire logic drain_done,
  input  wire logic in_valid,
  output wire logic in_ready,
  input  wire logic signed [CHANNELS*W-1:0] in_i_vec,
  input  wire logic signed [CHANNELS*W-1:0] in_q_vec,
  input  wire logic [15:0] in_config_id,
  input  wire logic [15:0] in_reset_epoch,
  input  wire logic in_frame_start,
  input  wire logic in_frame_end,
  input  wire logic in_tail,
  output wire logic [3:0] pa_valid,
  input  wire logic [3:0] pa_ready,
  output wire logic [63:0] pa_data [0:3],
  output wire logic [63:0] pa_weighted0,
  output wire logic [63:0] pa_weighted1,
  output wire logic pa_contract_weighted,
  output wire logic out_frame_start,
  output wire logic out_frame_end,
  output wire logic out_tail,
  output wire logic [15:0] out_config_id,
  output wire logic [15:0] out_reset_epoch,
  output wire logic overflow_error
);
  localparam int META_W = 35;

  generate
    if (DSM_ARCH == 2) begin : g_weighted_mash
      logic mash_valid, mash_in_ready, mash_drain_done, mash_overflow;
      logic [2*CHANNELS-1:0] mash_pa0, mash_pa1;
      logic [15:0] mash_config_id, mash_epoch;
      logic mash_frame_start, mash_frame_end, mash_tail;

      thermo5_weighted_mash_backend_adapter #(
        .W(W), .CHANNELS(CHANNELS), .FIFO_DEPTH(MASH_FIFO_DEPTH)
      ) u_mash_adapter (
        .clk(clk), .rst_n(rst_n), .stop_req(stop_req), .drain_done(mash_drain_done),
        .in_valid(in_valid), .in_ready(mash_in_ready),
        .in_i_poly_vec(in_i_vec), .in_q_poly_vec(in_q_vec),
        .in_config_id(in_config_id), .in_epoch(in_reset_epoch),
        .in_frame_start(in_frame_start), .in_frame_end(in_frame_end), .in_tail(in_tail),
        .out_valid(mash_valid), .out_ready(&pa_ready[1:0]),
        .out_stage1_data(), .out_stage2_data(),
        .out_pa0_data(mash_pa0), .out_pa1_data(mash_pa1),
        .out_config_id(mash_config_id), .out_epoch(mash_epoch),
        .out_frame_start(mash_frame_start), .out_frame_end(mash_frame_end),
        .out_tail(mash_tail), .overflow_error(mash_overflow), .inflight_count()
      );

      assign in_ready = mash_in_ready;
      assign drain_done = mash_drain_done;
      assign pa_contract_weighted = 1'b1;
      assign pa_valid = {2'b00, {2{mash_valid}}};
      assign pa_data[0] = mash_pa0;
      assign pa_data[1] = mash_pa1;
      assign pa_data[2] = '0;
      assign pa_data[3] = '0;
      assign pa_weighted0 = mash_pa0;
      assign pa_weighted1 = mash_pa1;
      assign out_frame_start = mash_frame_start;
      assign out_frame_end = mash_frame_end;
      assign out_tail = mash_tail;
      assign out_config_id = mash_config_id;
      assign out_reset_epoch = mash_epoch;
      assign overflow_error = mash_overflow;
    end else if ((DSM_ARCH == 0) || (DSM_ARCH == 1)) begin : g_equal_weight
      localparam int DSM_ORDER = (DSM_ARCH == 0) ? 1 : 2;
      localparam int PTR_W = $clog2(META_DEPTH);
      localparam int COUNT_W = $clog2(META_DEPTH + 1);
      logic core_in_ready, core_valid;
      logic [3:0] core_pa_valid;
      logic [META_W-1:0] meta_mem [0:META_DEPTH-1];
      logic [PTR_W-1:0] rd_ptr, wr_ptr;
      logic [COUNT_W-1:0] meta_count;
      logic meta_push, meta_pop;

      assign in_ready = !stop_req && core_in_ready && (meta_count < META_DEPTH);
      assign meta_push = in_valid && in_ready;
      assign meta_pop = (&pa_valid) && (&pa_ready);
      assign pa_valid = (meta_count != 0) ? core_pa_valid : 4'b0000;
      assign pa_contract_weighted = 1'b0;
      assign pa_weighted0 = '0;
      assign pa_weighted1 = '0;
      assign overflow_error = 1'b0;
      assign drain_done = stop_req && (meta_count == 0) && !(|core_pa_valid);
      assign {out_reset_epoch, out_config_id, out_tail, out_frame_end,
              out_frame_start} = (meta_count != 0) ? meta_mem[rd_ptr] : '0;

      tid32_thermo5_fs4_multipa_tx #(
        .W(W), .CHANNELS(CHANNELS), .STEP(STEP), .TIDSM_ORDER(DSM_ORDER)
      ) u_equal_pa_backend (
        .clk(clk), .rst_n(rst_n), .in_valid(meta_push), .in_ready(core_in_ready),
        .in_i_poly_vec(in_i_vec), .in_q_poly_vec(in_q_vec),
        .pa_valid(core_pa_valid), .pa_data(pa_data), .pa_ready(pa_ready)
      );

      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          rd_ptr <= '0;
          wr_ptr <= '0;
          meta_count <= '0;
        end else begin
          if (meta_push) begin
            meta_mem[wr_ptr] <= {in_reset_epoch, in_config_id, in_tail,
                                 in_frame_end, in_frame_start};
            wr_ptr <= wr_ptr + 1'b1;
          end
          if (meta_pop) rd_ptr <= rd_ptr + 1'b1;
          case ({meta_push, meta_pop})
            2'b10: meta_count <= meta_count + 1'b1;
            2'b01: meta_count <= meta_count - 1'b1;
            default: meta_count <= meta_count;
          endcase
        end
      end
    end else begin : g_invalid_arch
      initial $error("DSM_ARCH must be 0 (EF1), 1 (EF2), or 2 (MASH11)");
      assign in_ready = 1'b0;
      assign drain_done = 1'b0;
      assign pa_valid = '0;
      assign pa_contract_weighted = 1'b0;
      assign pa_weighted0 = '0;
      assign pa_weighted1 = '0;
      assign out_frame_start = 1'b0;
      assign out_frame_end = 1'b0;
      assign out_tail = 1'b0;
      assign out_config_id = '0;
      assign out_reset_epoch = '0;
      assign overflow_error = 1'b0;
      for (genvar p = 0; p < 4; p = p + 1) begin : g_invalid_pa
        assign pa_data[p] = '0;
      end
    end
  endgenerate
endmodule

`default_nettype wire
