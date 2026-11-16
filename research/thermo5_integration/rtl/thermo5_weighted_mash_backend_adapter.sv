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
  parameter int FIFO_DEPTH = 64
) (
  input  wire logic clk,
  input  wire logic rst_n,
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
  output wire logic [15:0] out_config_id,
  output wire logic [15:0] out_epoch,
  output wire logic out_frame_start,
  output wire logic out_frame_end,
  output wire logic out_tail,
  output wire logic overflow_error,
  output wire logic [15:0] inflight_count
);
  localparam int CAPACITY = FIFO_DEPTH + CORE_LATENCY + 2;
  localparam int COUNT_W = $clog2(CAPACITY + 1);
  logic core_in_valid, core_in_ready, core_valid;
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
  logic overflow_q;

  assign core_in_ready = 1'b1;
  assign in_ready = (credit_count < CAPACITY);
  assign core_in_valid = in_valid && in_ready;
  assign out_valid = (fifo_count != 0);
  assign out_stage1_data = s1_mem[rd_ptr];
  assign out_stage2_data = s2_mem[rd_ptr];
  assign out_config_id = cfg_mem[rd_ptr];
  assign out_epoch = epoch_mem[rd_ptr];
  assign out_frame_start = fs_mem[rd_ptr];
  assign out_frame_end = fe_mem[rd_ptr];
  assign out_tail = tail_mem[rd_ptr];
  assign overflow_error = overflow_q;
  assign inflight_count = credit_count;

  tid32_mash11_fs4_multipa_tx #(.W(W), .CHANNELS(CHANNELS)) u_core (
    .clk(clk), .rst_n(rst_n), .in_valid(core_in_valid), .in_ready(),
    .in_i_poly_vec(in_i_poly_vec), .in_q_poly_vec(in_q_poly_vec),
    .pa_valid(core_valid), .pa_stage1_data(core_s1), .pa_stage2_data(core_s2)
  );

  always_ff @(posedge clk or negedge rst_n) begin : p_adapter
    integer k;
    logic push_fifo, pop_fifo;
    if (!rst_n) begin
      meta_valid_pipe <= '0;
      rd_ptr <= '0; wr_ptr <= '0; fifo_count <= '0; credit_count <= '0;
      overflow_q <= 1'b0;
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
      pop_fifo = out_valid && out_ready;
      if (push_fifo) begin
        if (fifo_count == FIFO_DEPTH && !pop_fifo) overflow_q <= 1'b1;
        else begin
          s1_mem[wr_ptr] <= core_s1; s2_mem[wr_ptr] <= core_s2;
          cfg_mem[wr_ptr] <= cfg_pipe[CORE_LATENCY-1]; epoch_mem[wr_ptr] <= epoch_pipe[CORE_LATENCY-1];
          fs_mem[wr_ptr] <= frame_start_pipe[CORE_LATENCY-1]; fe_mem[wr_ptr] <= frame_end_pipe[CORE_LATENCY-1]; tail_mem[wr_ptr] <= tail_pipe[CORE_LATENCY-1];
          wr_ptr <= wr_ptr + 1'b1;
        end
      end
      if (pop_fifo) rd_ptr <= rd_ptr + 1'b1;
      case ({push_fifo && !(fifo_count == FIFO_DEPTH && !pop_fifo), pop_fifo})
        2'b10: fifo_count <= fifo_count + 1'b1;
        2'b01: fifo_count <= fifo_count - 1'b1;
        default: fifo_count <= fifo_count;
      endcase
      case ({core_in_valid, pop_fifo})
        2'b10: credit_count <= credit_count + 1'b1;
        2'b01: credit_count <= credit_count - 1'b1;
        default: credit_count <= credit_count;
      endcase
    end
  end
endmodule

`default_nettype wire
