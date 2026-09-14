//------------------------------------------------------------------------------
// Vendor-neutral raw-bit playback source for GT RF bring-up.
//
// The memory word is serialized least-significant-bit first by the connected
// GT configuration: mem_word[0] is the earliest RF sample in that word.
// This module does not instantiate a GT primitive or add line coding.
//------------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module gt_tx_raw_playback #(
  parameter int DATA_W = 32,
  parameter int MEM_DEPTH = 1024,
  parameter string MEM_INIT_FILE = ""
) (
  input  wire logic              clk,
  input  wire logic              rst_n,
  input  wire logic              start,
  input  wire logic              repeat_enable,
  output logic                   src_valid,
  input  wire logic              src_ready,
  output wire logic [DATA_W-1:0] src_data,
  output logic                   active,
  output logic                   done
);
  localparam int ADDR_W = (MEM_DEPTH <= 1) ? 1 : $clog2(MEM_DEPTH);

  logic [DATA_W-1:0] mem [0:MEM_DEPTH-1];
  logic [ADDR_W-1:0] addr;

  initial begin
    if (MEM_DEPTH <= 0) $error("MEM_DEPTH must be positive");
    if (MEM_INIT_FILE != "") $readmemh(MEM_INIT_FILE, mem);
  end

  assign src_valid = active;
  assign src_data = mem[addr];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      addr   <= '0;
      active <= 1'b0;
      done   <= 1'b0;
    end else begin
      done <= 1'b0;
      if (!active) begin
        if (start) begin
          addr   <= '0;
          active <= 1'b1;
        end
      end else if (src_ready) begin
        if (addr == MEM_DEPTH-1) begin
          if (repeat_enable) begin
            addr <= '0;
          end else begin
            active <= 1'b0;
            done   <= 1'b1;
          end
        end else begin
          addr <= addr + 1'b1;
        end
      end
    end
  end
endmodule

`default_nettype wire
