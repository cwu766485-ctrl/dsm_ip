`timescale 1ns/1ps
`default_nettype none

// AXI-stream ingress CDC and exact 14:8 vector gearbox.
// Source: 14 complex samples at 125 MHz.  Core: 8 complex samples at
// 218.75 MHz.  Both rates are exactly 1.75 GS/s complex.  Lane 0 is earliest.
//
// A frame start is legal only when it is aligned to a 56-sample superframe
// (four source beats / seven core words).  This preserves the existing core's
// word-granular frame-gain and recursive-state contract.
module dsm_axis14_to_core8_cdc #(
  parameter int W = 16,
  parameter int GAIN_W = 16,
  parameter int FIFO_ADDR_W = 4,
  parameter int SRC_LANES = 14,
  parameter int CORE_LANES = 8,
  parameter bit USE_XPM_FIFO = 1'b0
) (
  input  wire logic                                  s_axis_aclk,
  input  wire logic                                  s_axis_aresetn,
  input  wire logic                                  s_axis_tvalid,
  output wire logic                                  s_axis_tready,
  input  wire logic signed [SRC_LANES*W-1:0]         s_axis_i_vec,
  input  wire logic signed [SRC_LANES*W-1:0]         s_axis_q_vec,
  input  wire logic                                  s_axis_tuser_frame_start,
  input  wire logic signed [GAIN_W-1:0]              s_axis_tuser_frame_gain,
  output wire logic                                  s_axis_fifo_full,

  input  wire logic                                  core_clk,
  input  wire logic                                  core_aresetn,
  input  wire logic                                  core_enable,
  // Legal end-of-run drain.  When asserted, an empty FIFO after the final
  // gearbox word is quiescence rather than a streaming underflow.
  input  wire logic                                  core_drain,
  output wire logic                                  core_valid,
  input  wire logic                                  core_ready,
  output wire logic signed [CORE_LANES*W-1:0]        core_i_vec,
  output wire logic signed [CORE_LANES*W-1:0]        core_q_vec,
  output wire logic                                  core_frame_start,
  output wire logic signed [GAIN_W-1:0]              core_frame_gain,
  output logic                                       core_underflow,
  output logic                                       core_protocol_error
);
  localparam int FIFO_W = 2*SRC_LANES*W + 1 + GAIN_W;
  localparam int COUNT_W = $clog2(SRC_LANES + 1);

  logic s_rst_n, c_rst_n;
  logic [FIFO_W-1:0] fifo_wr_data, fifo_rd_data;
  logic fifo_rd_valid, fifo_rd_ready, fifo_rd_empty;
  logic signed [SRC_LANES*W-1:0] fifo_i, fifo_q;
  logic fifo_frame_start;
  logic signed [GAIN_W-1:0] fifo_frame_gain;
  logic signed [SRC_LANES*W-1:0] rem_i_q, rem_q_q;
  logic [COUNT_W-1:0] rem_count_q;
  logic out_valid_q, out_frame_start_q;
  logic signed [CORE_LANES*W-1:0] out_i_q, out_q_q;
  logic signed [GAIN_W-1:0] out_frame_gain_q;
  logic stream_started_q;

  dsm_reset_sync u_s_reset (.clk(s_axis_aclk), .arst_n(s_axis_aresetn), .srst_n(s_rst_n));
  dsm_reset_sync u_c_reset (.clk(core_clk), .arst_n(core_aresetn), .srst_n(c_rst_n));

  assign fifo_wr_data = {s_axis_tuser_frame_gain, s_axis_tuser_frame_start,
                         s_axis_q_vec, s_axis_i_vec};
  assign {fifo_frame_gain, fifo_frame_start, fifo_q, fifo_i} = fifo_rd_data;

  generate
    if (USE_XPM_FIFO) begin : g_xpm_fifo
      // The XPM wrapper synchronizes both local reset requests into wr_clk
      // before asserting its required wr_clk-synchronous common reset. The
      // parent asserts both domains in one reset epoch; each public handshake
      // remains gated by its own local reset.
      dsm_xpm_async_fifo #(.DATA_W(FIFO_W), .ADDR_W(FIFO_ADDR_W)) u_async_fifo (
        .wr_clk(s_axis_aclk), .wr_rst_n(s_axis_aresetn), .wr_data_vec(fifo_wr_data),
        .wr_valid(s_axis_tvalid), .wr_ready(s_axis_tready), .wr_full(s_axis_fifo_full),
        .rd_clk(core_clk), .rd_rst_n(core_aresetn), .rd_data(fifo_rd_data),
        .rd_valid(fifo_rd_valid), .rd_ready(fifo_rd_ready), .rd_empty(fifo_rd_empty)
      );
    end else begin : g_generic_fifo
      dsm_async_fifo #(.DATA_W(FIFO_W), .ADDR_W(FIFO_ADDR_W)) u_async_fifo (
        .wr_clk(s_axis_aclk), .wr_rst_n(s_rst_n), .wr_data(fifo_wr_data),
        .wr_valid(s_axis_tvalid), .wr_ready(s_axis_tready), .wr_full(s_axis_fifo_full),
        .rd_clk(core_clk), .rd_rst_n(c_rst_n), .rd_data(fifo_rd_data),
        .rd_valid(fifo_rd_valid), .rd_ready(fifo_rd_ready), .rd_empty(fifo_rd_empty)
      );
    end
  endgenerate

  // A new source word is consumed exactly when the residual has fewer than
  // eight samples and the output register can advance.  For the fixed 14:8
  // contract, residual population follows the seven-word sequence
  // 0, 6, 12, 4, 10, 2, 8.  Keep the datapath as fixed slices instead of
  // variable part-selects: this preserves lane-0-first temporal order while
  // giving synthesis a bounded, regular mux network.
  wire advance = core_enable && (!out_valid_q || core_ready);
  assign fifo_rd_ready = advance && (rem_count_q < CORE_LANES);
  assign core_valid = out_valid_q && core_enable;
  assign core_i_vec = out_i_q;
  assign core_q_vec = out_q_q;
  assign core_frame_start = out_frame_start_q;
  assign core_frame_gain = out_frame_gain_q;

  always_ff @(posedge core_clk or negedge c_rst_n) begin
    if (!c_rst_n) begin
      rem_i_q <= '0;
      rem_q_q <= '0;
      rem_count_q <= '0;
      out_valid_q <= 1'b0;
      out_i_q <= '0;
      out_q_q <= '0;
      out_frame_start_q <= 1'b0;
      out_frame_gain_q <= '0;
      stream_started_q <= 1'b0;
      core_underflow <= 1'b0;
      core_protocol_error <= 1'b0;
    end else begin
      if (core_valid && core_ready && core_frame_start)
        stream_started_q <= 1'b1;

      if (advance) begin
        out_frame_start_q <= 1'b0;
        out_frame_gain_q <= '0;
        case (rem_count_q)
          8: begin
            out_i_q <= rem_i_q[CORE_LANES*W-1:0];
            out_q_q <= rem_q_q[CORE_LANES*W-1:0];
            rem_i_q <= '0;
            rem_q_q <= '0;
            rem_count_q <= '0;
            out_valid_q <= 1'b1;
          end
          10: begin
            out_i_q <= rem_i_q[CORE_LANES*W-1:0];
            out_q_q <= rem_q_q[CORE_LANES*W-1:0];
            rem_i_q <= rem_i_q >> (CORE_LANES*W);
            rem_q_q <= rem_q_q >> (CORE_LANES*W);
            rem_count_q <= 2;
            out_valid_q <= 1'b1;
          end
          12: begin
            out_i_q <= rem_i_q[CORE_LANES*W-1:0];
            out_q_q <= rem_q_q[CORE_LANES*W-1:0];
            rem_i_q <= rem_i_q >> (CORE_LANES*W);
            rem_q_q <= rem_q_q >> (CORE_LANES*W);
            rem_count_q <= 4;
            out_valid_q <= 1'b1;
          end
          0, 2, 4, 6: begin
            if (fifo_rd_valid) begin
              case (rem_count_q)
                0: begin
                  out_i_q <= fifo_i[CORE_LANES*W-1:0];
                  out_q_q <= fifo_q[CORE_LANES*W-1:0];
                  rem_i_q <= fifo_i >> (CORE_LANES*W);
                  rem_q_q <= fifo_q >> (CORE_LANES*W);
                  rem_count_q <= 6;
                end
                2: begin
                  out_i_q <= {fifo_i[6*W-1:0], rem_i_q[2*W-1:0]};
                  out_q_q <= {fifo_q[6*W-1:0], rem_q_q[2*W-1:0]};
                  rem_i_q <= fifo_i >> (6*W);
                  rem_q_q <= fifo_q >> (6*W);
                  rem_count_q <= 8;
                end
                4: begin
                  out_i_q <= {fifo_i[4*W-1:0], rem_i_q[4*W-1:0]};
                  out_q_q <= {fifo_q[4*W-1:0], rem_q_q[4*W-1:0]};
                  rem_i_q <= fifo_i >> (4*W);
                  rem_q_q <= fifo_q >> (4*W);
                  rem_count_q <= 10;
                end
                default: begin // rem_count_q == 6
                  out_i_q <= {fifo_i[2*W-1:0], rem_i_q[6*W-1:0]};
                  out_q_q <= {fifo_q[2*W-1:0], rem_q_q[6*W-1:0]};
                  rem_i_q <= fifo_i >> (2*W);
                  rem_q_q <= fifo_q >> (2*W);
                  rem_count_q <= 12;
                end
              endcase
              out_frame_start_q <= fifo_frame_start && (rem_count_q == 0);
              out_frame_gain_q <= fifo_frame_gain;
              out_valid_q <= 1'b1;
              if (fifo_frame_start && (rem_count_q != 0))
                core_protocol_error <= 1'b1;
            end else begin
              out_valid_q <= 1'b0;
              // Do not flag the same edge that consumes a legal final word.
              // A true streaming underflow is an observable following core
              // cycle with no valid replacement word.
              if (stream_started_q && !out_valid_q && !core_drain)
                core_underflow <= 1'b1;
            end
          end
          default: begin
            // The only legal 14:8 residual populations are listed above.
            // Stop forwarding data if reset/protocol corruption violates it.
            out_valid_q <= 1'b0;
            core_protocol_error <= 1'b1;
          end
        endcase
      end
    end
  end

`ifndef SYNTHESIS
  // These checks document the fixed 14:8 gearbox and frame-boundary contract
  // as executable invariants without changing the synthesized datapath.
  logic stalled_last;
  always_ff @(posedge core_clk or negedge c_rst_n) begin
    if (!c_rst_n) stalled_last <= 1'b0;
    else stalled_last <= core_valid && !core_ready;
  end
  always_ff @(posedge core_clk) begin
    if (c_rst_n) begin
      assert ((rem_count_q == 0) || (rem_count_q == 2) ||
              (rem_count_q == 4) || (rem_count_q == 6) ||
              (rem_count_q == 8) || (rem_count_q == 10) ||
              (rem_count_q == 12))
        else $error("DSM 14:8 gearbox entered an illegal residual count");
      if (fifo_rd_valid && fifo_rd_ready && fifo_frame_start)
        assert (rem_count_q == 0)
          else $error("DSM frame_start was not aligned to a 56-sample boundary");
      if (stalled_last) begin
        assert ($stable(core_i_vec) && $stable(core_q_vec) &&
                $stable(core_frame_start) && $stable(core_frame_gain))
          else $error("DSM core output changed while backpressured");
      end
    end
  end
`endif
endmodule

`default_nettype wire
