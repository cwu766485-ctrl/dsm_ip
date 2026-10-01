`timescale 1ns/1ps
`default_nettype none

// Frame-safe activity controller for the 14:8 streaming frontend.
// This module never gates a fabric clock.  It generates a clock-enable style
// run qualifier after a source-domain FIFO prefill and keeps that qualifier
// asserted until every accepted core word has reached the output boundary.
module dsm_frame_power_ctrl #(
  parameter int PREFILL_WORDS = 4,
  parameter int OUTSTANDING_W = 8
) (
  input  wire logic s_clk,
  input  wire logic s_rst_n,
  input  wire logic s_accept,
  input  wire logic run_request,

  input  wire logic core_clk,
  input  wire logic core_rst_n,
  input  wire logic core_accept,
  input  wire logic output_accept,
  input  wire logic core_input_valid,
  input  wire logic output_valid,

  output logic core_activity_enable,
  output logic ingress_enable,
  output logic [2:0] power_state,
  output logic [OUTSTANDING_W-1:0] outstanding_words
);
  localparam int PREFILL_W = (PREFILL_WORDS < 2) ? 1 : $clog2(PREFILL_WORDS + 1);
  localparam logic [2:0] ST_RESET   = 3'd0;
  localparam logic [2:0] ST_IDLE    = 3'd1;
  localparam logic [2:0] ST_PREFILL = 3'd2;
  localparam logic [2:0] ST_RUN     = 3'd3;
  localparam logic [2:0] ST_DRAIN   = 3'd4;
  localparam logic [2:0] ST_ERROR   = 3'd5;

  logic run_s1, run_s2;
  logic [PREFILL_W-1:0] prefill_count;
  logic prefill_ready_s, prefill_ready_c1, prefill_ready_c2;
  logic run_c1, run_c2;

  always_ff @(posedge s_clk or negedge s_rst_n) begin
    if (!s_rst_n) begin
      run_s1 <= 1'b0;
      run_s2 <= 1'b0;
      prefill_count <= '0;
      prefill_ready_s <= 1'b0;
      ingress_enable <= 1'b0;
    end else begin
      run_s1 <= run_request;
      run_s2 <= run_s1;
      if (!run_s2) begin
        prefill_count <= '0;
        prefill_ready_s <= 1'b0;
      end else if (s_accept && !prefill_ready_s) begin
        if (PREFILL_WORDS <= 1 || prefill_count == PREFILL_WORDS-1) begin
          prefill_ready_s <= 1'b1;
        end else begin
          prefill_count <= prefill_count + 1'b1;
        end
      end
      ingress_enable <= run_s2;
    end
  end

  always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      prefill_ready_c1 <= 1'b0;
      prefill_ready_c2 <= 1'b0;
      run_c1 <= 1'b0;
      run_c2 <= 1'b0;
      power_state <= ST_RESET;
      core_activity_enable <= 1'b0;
      outstanding_words <= '0;
    end else begin
      prefill_ready_c1 <= prefill_ready_s;
      prefill_ready_c2 <= prefill_ready_c1;
      run_c1 <= run_request;
      run_c2 <= run_c1;

      case ({core_accept, output_accept})
        2'b10: begin
          if (&outstanding_words) power_state <= ST_ERROR;
          else outstanding_words <= outstanding_words + 1'b1;
        end
        2'b01: begin
          if (outstanding_words == 0) power_state <= ST_ERROR;
          else outstanding_words <= outstanding_words - 1'b1;
        end
        default: ;
      endcase

      case (power_state)
        ST_RESET: begin
          core_activity_enable <= 1'b0;
          outstanding_words <= '0;
          power_state <= ST_IDLE;
        end
        ST_IDLE: begin
          core_activity_enable <= 1'b0;
          outstanding_words <= '0;
          if (run_c2) power_state <= ST_PREFILL;
        end
        ST_PREFILL: begin
          core_activity_enable <= 1'b0;
          if (!run_c2) power_state <= ST_IDLE;
          else if (prefill_ready_c2) begin
            core_activity_enable <= 1'b1;
            power_state <= ST_RUN;
          end
        end
        ST_RUN: begin
          core_activity_enable <= 1'b1;
          if (!run_c2) power_state <= ST_DRAIN;
        end
        ST_DRAIN: begin
          core_activity_enable <= 1'b1;
          if (((outstanding_words == 0) && !core_input_valid && !output_valid) ||
              (output_accept && (outstanding_words == 1) && !core_input_valid)) begin
            core_activity_enable <= 1'b0;
            power_state <= ST_IDLE;
          end
        end
        default: begin
          core_activity_enable <= 1'b0;
          power_state <= ST_ERROR;
        end
      endcase
    end
  end

`ifndef SYNTHESIS
  always_ff @(posedge core_clk) begin
    if (core_rst_n) begin
      if (power_state == ST_PREFILL)
        assert (!core_activity_enable)
          else $error("low-power core enabled before FIFO prefill");
      if (power_state == ST_DRAIN && outstanding_words != 0)
        assert (core_activity_enable)
          else $error("low-power controller stopped with words in flight");
    end
  end
`endif
endmodule

`default_nettype wire
