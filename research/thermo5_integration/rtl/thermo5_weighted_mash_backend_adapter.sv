`timescale 1ns/1ps
`default_nettype none

// Bounded, transaction-atomic adapter for the historical MASH backend.
// The legacy core has no output ready input, so arbitrary backpressure is not
// claimed. Credits reserve FIFO space for the fixed core latency and stop new
// input transactions before the bounded output store can overflow.
module thermo5_weighted_mash_backend_adapter #(
  parameter int W = 16,
  parameter int CHANNELS = 32,
  parameter int CORE_LATENCY = 6,
  parameter int FIFO_DEPTH = 64,
  parameter bit USE_ACCUMULATOR_RESIDUE = 1'b0
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic stop_req,
  output wire logic drain_done,
  input  wire logic in_valid,
  output wire logic in_ready,
  input  wire logic signed [CHANNELS*W-1:0] in_i_poly_vec,
  input  wire logic signed [CHANNELS*W-1:0] in_q_poly_vec,
  input  wire logic [15:0] in_config_id,
  input  wire logic [15:0] in_epoch,
  input  wire logic in_frame_start,
  input  wire logic in_frame_end,
  input  wire logic in_tail,
  output wire logic out_valid,
  input  wire logic out_ready,
  output wire logic [2*CHANNELS-1:0] out_stage1_data,
  output wire logic [2*CHANNELS-1:0] out_stage2_data,
  output wire logic [2*CHANNELS-1:0] out_pa0_data,
  output wire logic [2*CHANNELS-1:0] out_pa1_data,
  output wire logic [15:0] out_config_id,
  output wire logic [15:0] out_epoch,
  output wire logic out_frame_start,
  output wire logic out_frame_end,
  output wire logic out_tail,
  output wire logic overflow_error,
  output wire logic [15:0] inflight_count
);
  localparam int STORAGE_CAPACITY = FIFO_DEPTH + 1;
  localparam int COUNT_W = $clog2(STORAGE_CAPACITY + 1);
  logic core_in_valid, core_valid;
  logic raw_valid, raw_pop, encoder_in_ready, encoder_valid;
  logic [2*CHANNELS-1:0] encoder_pa0, encoder_pa1;
  logic [2*CHANNELS-1:0] out_s1_q, out_s2_q;
  logic [15:0] out_cfg_q, out_epoch_q;
  logic out_fs_q, out_fe_q, out_tail_q;
  logic [2*CHANNELS-1:0] core_s1, core_s2;
  logic [CORE_LATENCY-1:0] meta_valid_pipe;
  logic [15:0] cfg_pipe[0:CORE_LATENCY-1], epoch_pipe[0:CORE_LATENCY-1];
  logic frame_start_pipe[0:CORE_LATENCY-1], frame_end_pipe[0:CORE_LATENCY-1], tail_pipe[0:CORE_LATENCY-1];
  logic [2*CHANNELS-1:0] s1_mem[0:FIFO_DEPTH-1], s2_mem[0:FIFO_DEPTH-1];
  logic [15:0] cfg_mem[0:FIFO_DEPTH-1], epoch_mem[0:FIFO_DEPTH-1];
  logic fs_mem[0:FIFO_DEPTH-1], fe_mem[0:FIFO_DEPTH-1], tail_mem[0:FIFO_DEPTH-1];
  logic [$clog2(FIFO_DEPTH)-1:0] rd_ptr, wr_ptr;
  logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_count;
  logic [COUNT_W-1:0] credit_count;
  logic [COUNT_W-1:0] core_pending_count;
  logic overflow_q;

  // Reserve one eventual output slot for every accepted transaction. The
  // reservation moves from core pending to the raw FIFO and then encoder.
  assign in_ready = !stop_req &&
                    (fifo_count + core_pending_count + encoder_valid < STORAGE_CAPACITY);
  assign core_in_valid = in_valid && in_ready;
  assign raw_valid = (fifo_count != 0);
  assign raw_pop = raw_valid && encoder_in_ready;
  assign out_valid = encoder_valid;
  assign out_stage1_data = out_s1_q;
  assign out_stage2_data = out_s2_q;
  assign out_pa0_data = encoder_pa0;
  assign out_pa1_data = encoder_pa1;
  assign out_config_id = out_cfg_q;
  assign out_epoch = out_epoch_q;
  assign out_frame_start = out_fs_q;
  assign out_frame_end = out_fe_q;
  assign out_tail = out_tail_q;
  assign overflow_error = overflow_q;
  assign inflight_count = credit_count;
  assign drain_done = stop_req && (credit_count == 0) &&
                      (core_pending_count == 0) && (fifo_count == 0) &&
                      !encoder_valid;

  tid32_mash11_fs4_multipa_tx #(.W(W), .CHANNELS(CHANNELS),
    .USE_ACCUMULATOR_RESIDUE(USE_ACCUMULATOR_RESIDUE)) u_core (
    .clk(clk), .rst_n(rst_n), .in_valid(core_in_valid), .in_ready(),
    .in_i_poly_vec(in_i_poly_vec), .in_q_poly_vec(in_q_poly_vec),
    .pa_valid(core_valid), .pa_stage1_data(core_s1), .pa_stage2_data(core_s2)
  );

  thermo5_weighted_mash_encoder #(.CHANNELS(CHANNELS)) u_weighted_encoder (
    .clk(clk), .rst_n(rst_n), .in_valid(raw_valid), .in_ready(encoder_in_ready),
    .in_stage1_data(s1_mem[rd_ptr]), .in_stage2_data(s2_mem[rd_ptr]),
    .out_valid(encoder_valid), .out_ready(out_ready),
    .out_pa0_data(encoder_pa0), .out_pa1_data(encoder_pa1)
  );

  always_ff @(posedge clk or negedge rst_n) begin : p_adapter
    integer k;
    logic push_fifo, pop_fifo;
    if (!rst_n) begin
      meta_valid_pipe <= '0;
      rd_ptr <= '0; wr_ptr <= '0; fifo_count <= '0; credit_count <= '0;
      core_pending_count <= '0;
      overflow_q <= 1'b0;
      out_s1_q <= '0; out_s2_q <= '0;
      out_cfg_q <= '0; out_epoch_q <= '0;
      out_fs_q <= 1'b0; out_fe_q <= 1'b0; out_tail_q <= 1'b0;
      for (k=0; k<CORE_LATENCY; k=k+1) begin
        cfg_pipe[k] <= '0; epoch_pipe[k] <= '0;
        frame_start_pipe[k] <= 1'b0; frame_end_pipe[k] <= 1'b0; tail_pipe[k] <= 1'b0;
      end
    end else begin
      meta_valid_pipe[0] <= core_in_valid;
      if (core_in_valid) begin
        cfg_pipe[0] <= in_config_id; epoch_pipe[0] <= in_epoch;
        frame_start_pipe[0] <= in_frame_start; frame_end_pipe[0] <= in_frame_end; tail_pipe[0] <= in_tail;
      end
      for (k=1; k<CORE_LATENCY; k=k+1) begin
        meta_valid_pipe[k] <= meta_valid_pipe[k-1];
        if (meta_valid_pipe[k-1]) begin
          cfg_pipe[k] <= cfg_pipe[k-1]; epoch_pipe[k] <= epoch_pipe[k-1];
          frame_start_pipe[k] <= frame_start_pipe[k-1]; frame_end_pipe[k] <= frame_end_pipe[k-1]; tail_pipe[k] <= tail_pipe[k-1];
        end
      end

      push_fifo = core_valid;
      pop_fifo = raw_pop;
      if (push_fifo) begin
        if (fifo_count == FIFO_DEPTH && !pop_fifo) overflow_q <= 1'b1;
        else begin
          s1_mem[wr_ptr] <= core_s1; s2_mem[wr_ptr] <= core_s2;
          cfg_mem[wr_ptr] <= cfg_pipe[CORE_LATENCY-1]; epoch_mem[wr_ptr] <= epoch_pipe[CORE_LATENCY-1];
          fs_mem[wr_ptr] <= frame_start_pipe[CORE_LATENCY-1]; fe_mem[wr_ptr] <= frame_end_pipe[CORE_LATENCY-1]; tail_mem[wr_ptr] <= tail_pipe[CORE_LATENCY-1];
          wr_ptr <= wr_ptr + 1'b1;
        end
      end
      if (raw_pop) begin
        out_s1_q <= s1_mem[rd_ptr]; out_s2_q <= s2_mem[rd_ptr];
        out_cfg_q <= cfg_mem[rd_ptr]; out_epoch_q <= epoch_mem[rd_ptr];
        out_fs_q <= fs_mem[rd_ptr]; out_fe_q <= fe_mem[rd_ptr]; out_tail_q <= tail_mem[rd_ptr];
      end
      if (pop_fifo) rd_ptr <= rd_ptr + 1'b1;
      case ({push_fifo && !(fifo_count == FIFO_DEPTH && !pop_fifo), pop_fifo})
        2'b10: fifo_count <= fifo_count + 1'b1;
        2'b01: fifo_count <= fifo_count - 1'b1;
        default: fifo_count <= fifo_count;
      endcase
      case ({core_in_valid, out_valid && out_ready})
        2'b10: credit_count <= credit_count + 1'b1;
        2'b01: credit_count <= credit_count - 1'b1;
        default: credit_count <= credit_count;
      endcase
      case ({core_in_valid, core_valid})
        2'b10: core_pending_count <= core_pending_count + 1'b1;
        2'b01: core_pending_count <= core_pending_count - 1'b1;
        default: core_pending_count <= core_pending_count;
      endcase
      if (core_valid && core_pending_count == 0)
        overflow_q <= 1'b1;
    end
  end
endmodule

`default_nettype wire
