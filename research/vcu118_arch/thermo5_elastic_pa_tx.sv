`timescale 1ns/1ps
`default_nettype none

// Research-only continuous PA-to-serializer elastic buffer.
// It prefills once, then streams words across frame boundaries. Frame and
// configuration metadata travel in the same FIFO entry as the PA payload.
module thermo5_elastic_pa_tx #(
  parameter int FIFO_DEPTH = 8192,
  parameter int PREFILL_WORDS = 256,
  parameter logic [63:0] IDLE_WORD = 64'haaaaaaaaaaaaaaaa
) (
  input  wire logic         clk,
  input  wire logic         rst_n,
  input  wire logic         run_request,
  input  wire logic         link_ready,
  input  wire logic         in_valid,
  output wire logic         in_ready,
  input  wire logic [255:0] in_data,
  input  wire logic [3:0]   in_mask,
  input  wire logic [1:0]   in_arch,
  input  wire logic         in_start,
  input  wire logic         in_end,
  input  wire logic         in_tail,
  input  wire logic [15:0]  in_config_id,
  input  wire logic [15:0]  in_epoch,
  output logic [255:0]      gt_data,
  output logic [3:0]        pa_enable_mask,
  output logic              out_start,
  output logic              out_end,
  output logic              out_tail,
  output logic [1:0]        out_arch,
  output logic [15:0]       out_config_id,
  output logic [15:0]       out_epoch,
  output wire logic         drain_done,
  output logic              protocol_fault,
  output logic              frame_overflow,
  output logic              link_fault,
  output logic              underflow
);
  localparam int PW = $clog2(FIFO_DEPTH);
  localparam int CW = $clog2(FIFO_DEPTH + 1);

  logic [255:0] data_mem [0:FIFO_DEPTH-1];
  logic [3:0]   mask_mem [0:FIFO_DEPTH-1];
  logic [1:0]   arch_mem [0:FIFO_DEPTH-1];
  logic         start_mem[0:FIFO_DEPTH-1];
  logic         end_mem  [0:FIFO_DEPTH-1];
  logic         tail_mem [0:FIFO_DEPTH-1];
  logic [15:0]  cfg_mem  [0:FIFO_DEPTH-1];
  logic [15:0]  epoch_mem[0:FIFO_DEPTH-1];

  logic [PW-1:0] wr_ptr, rd_ptr;
  logic [CW-1:0] count;
  logic playing;
  logic frame_open;
  logic [3:0] frame_mask;
  logic [1:0] frame_arch;
  logic [15:0] frame_cfg, frame_epoch;
  logic contract_valid;
  logic [3:0] contract_mask;
  logic [1:0] contract_arch;
  logic [15:0] contract_cfg, contract_epoch;

  wire push = in_valid && in_ready;
  wire prefill_met = count >= CW'(PREFILL_WORDS);
  wire start_ready = prefill_met || (!run_request && count != 0);
  wire pop = link_ready && count != 0 && (playing || start_ready);
  wire occupied = count != 0 || (|pa_enable_mask);

  assign in_ready = rst_n && link_ready && count < CW'(FIFO_DEPTH) &&
                    !protocol_fault && !frame_overflow && !link_fault;
  assign drain_done = !run_request && count == 0 && !(|pa_enable_mask);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
      count <= '0;
      playing <= 1'b0;
      frame_open <= 1'b0;
      frame_mask <= '0;
      frame_arch <= '0;
      frame_cfg <= '0;
      frame_epoch <= '0;
      contract_valid <= 1'b0;
      contract_mask <= '0;
      contract_arch <= '0;
      contract_cfg <= '0;
      contract_epoch <= '0;
      gt_data <= {4{IDLE_WORD}};
      pa_enable_mask <= '0;
      out_start <= 1'b0;
      out_end <= 1'b0;
      out_tail <= 1'b0;
      out_arch <= '0;
      out_config_id <= '0;
      out_epoch <= '0;
      protocol_fault <= 1'b0;
      frame_overflow <= 1'b0;
      link_fault <= 1'b0;
      underflow <= 1'b0;
    end else begin
      gt_data <= {4{IDLE_WORD}};
      pa_enable_mask <= '0;
      out_start <= 1'b0;
      out_end <= 1'b0;
      out_tail <= 1'b0;

      if (!link_ready && occupied)
        link_fault <= 1'b1;

      if (!playing && start_ready)
        playing <= 1'b1;
      if (playing && count == 0 && !push)
        playing <= 1'b0;
      if (run_request && playing && count == 0 && !push)
        underflow <= 1'b1;

      if (push) begin
        data_mem[wr_ptr]  <= in_data;
        mask_mem[wr_ptr]  <= in_mask;
        arch_mem[wr_ptr]  <= in_arch;
        start_mem[wr_ptr] <= in_start;
        end_mem[wr_ptr]   <= in_end;
        tail_mem[wr_ptr]  <= in_tail;
        cfg_mem[wr_ptr]   <= in_config_id;
        epoch_mem[wr_ptr] <= in_epoch;
        wr_ptr <= wr_ptr + 1'b1;

        if (in_arch > 2 || in_mask != (in_arch == 2 ? 4'h3 : 4'hf))
          protocol_fault <= 1'b1;

        if (!frame_open) begin
          if (!in_start)
            protocol_fault <= 1'b1;
          frame_open <= !in_end;
          frame_mask <= in_mask;
          frame_arch <= in_arch;
          frame_cfg <= in_config_id;
          frame_epoch <= in_epoch;
        end else begin
          if (in_start || in_mask != frame_mask || in_arch != frame_arch ||
              in_config_id != frame_cfg || in_epoch != frame_epoch)
            protocol_fault <= 1'b1;
          if (in_end)
            frame_open <= 1'b0;
        end

        if (!contract_valid || !occupied) begin
          contract_valid <= 1'b1;
          contract_mask <= in_mask;
          contract_arch <= in_arch;
          contract_cfg <= in_config_id;
          contract_epoch <= in_epoch;
        end else if (in_mask != contract_mask || in_arch != contract_arch ||
                     in_config_id != contract_cfg || in_epoch != contract_epoch) begin
          protocol_fault <= 1'b1;
        end
      end

      if (pop) begin
        gt_data <= data_mem[rd_ptr];
        pa_enable_mask <= mask_mem[rd_ptr];
        out_arch <= arch_mem[rd_ptr];
        out_start <= start_mem[rd_ptr];
        out_end <= end_mem[rd_ptr];
        out_tail <= tail_mem[rd_ptr];
        out_config_id <= cfg_mem[rd_ptr];
        out_epoch <= epoch_mem[rd_ptr];
        rd_ptr <= rd_ptr + 1'b1;
      end

      case ({push, pop})
        2'b10: count <= count + 1'b1;
        2'b01: count <= count - 1'b1;
        default: count <= count;
      endcase
    end
  end

  initial begin
    if (FIFO_DEPTH < 2 || (FIFO_DEPTH & (FIFO_DEPTH - 1)) != 0)
      $error("FIFO_DEPTH must be a power of two >= 2");
    if (PREFILL_WORDS < 1 || PREFILL_WORDS >= FIFO_DEPTH)
      $error("PREFILL_WORDS must be in [1,FIFO_DEPTH-1]");
  end
endmodule

`default_nettype wire
