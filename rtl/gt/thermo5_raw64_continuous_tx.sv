`timescale 1ns/1ps
`default_nettype none

// Four lockstep raw-64 code planes feeding a continuously clocked GT TXDATA.
// A GT has no ready/valid input: idle words continue to serialize, while
// pa_enable is a separate, word-aligned request for external PA blanking.
// A mid-run gap or plane-valid disagreement is a sticky stream fault until
// the common reset epoch. The parent must not call idle words RF payload.
module thermo5_raw64_continuous_tx #(
  parameter logic [63:0] IDLE_WORD = 64'hAAAA_AAAA_AAAA_AAAA,
  parameter int WORDS_PER_FRAME = 56
) (
  input  wire logic        clk,
  input  wire logic        rst_n,
  input  wire logic        link_ready,
  input  wire logic        run_request,
  input  wire logic [3:0]  pa_valid,
  input  wire logic [63:0] pa_data [0:3],
  output wire logic [3:0]  pa_ready,
  output logic [255:0]    gt_txdata,
  output logic            pa_enable,
  output logic            stream_fault
);
  logic streaming;
  localparam int COUNT_W = $clog2(WORDS_PER_FRAME);
  logic [COUNT_W-1:0] word_index;
  wire logic all_valid = &pa_valid;
  wire logic any_valid = |pa_valid;
  assign pa_ready = 4'hf;  // GT consumes exactly one word on every clock.

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      gt_txdata <= {4{IDLE_WORD}};
      pa_enable <= 1'b0;
      stream_fault <= 1'b0;
      streaming <= 1'b0;
      word_index <= '0;
    end else begin
      gt_txdata <= {4{IDLE_WORD}};
      pa_enable <= 1'b0;
      if (!link_ready) begin
        if (streaming) stream_fault <= 1'b1;
        streaming <= 1'b0;
        word_index <= '0;
      end else if (run_request && !stream_fault) begin
        if (any_valid && !all_valid) begin
          stream_fault <= 1'b1;
        end else if (all_valid) begin
          gt_txdata <= {pa_data[3], pa_data[2], pa_data[1], pa_data[0]};
          pa_enable <= 1'b1;
          if (word_index == WORDS_PER_FRAME-1) begin
            streaming <= 1'b0;
            word_index <= '0;
          end else begin
            streaming <= 1'b1;
            word_index <= word_index + 1'b1;
          end
        end else if (streaming) begin
          stream_fault <= 1'b1;
        end
      end else if (!run_request) begin
        if (any_valid || streaming) stream_fault <= 1'b1;
        streaming <= 1'b0;
        word_index <= '0;
      end
    end
  end
endmodule

`default_nettype wire
