//------------------------------------------------------------------------------
// File: rom_reader.sv
// Description:
//   ROM read wrapper for I/Q BRAMs (blk_mem_gen) with 1-cycle registered output
//   latency. Generates data-aligned valid and address, and wraps at DEPTH.
//
// Notes:
//   - enable issues a read request (addr_req -> BRAM addra).
//   - valid asserts when i_data/q_data are aligned to addr.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module rom_reader #(
  parameter int W = 16,
  parameter int ADDR_W = 16,
  parameter int DEPTH = 65536,
  parameter bit USE_FILE_ROM = 1'b0,
  parameter string MEM_I_FILE = "rom_i.mem",
  parameter string MEM_Q_FILE = "rom_q.mem"
) (
  input  wire  clk,
  input  wire rst_n,
  input  wire enable,
  output logic [ADDR_W-1:0] addr,
  output logic signed [W-1:0] i_data,
  output logic signed [W-1:0] q_data,
  output logic valid
);

  // ROM read pipeline:
  //   addr_req    -> BRAM addra (request)
  //   addr_req_d1 -> data-aligned address (registered douta)
  //   valid       -> asserts when i_data/q_data are aligned to addr
  logic [ADDR_W-1:0] addr_req;
  logic [ADDR_W-1:0] addr_req_d1;
  logic enable_d1;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      addr_req    <= '0;
      addr_req_d1 <= '0;
      addr        <= '0;
      enable_d1   <= 1'b0;
      valid       <= 1'b0;
    end else begin
      enable_d1   <= enable;
      valid       <= enable_d1;
      addr_req_d1 <= addr_req;
      if (enable_d1) begin
        addr <= addr_req_d1;
      end
      if (enable) begin
        if (addr_req == DEPTH-1) begin
          addr_req <= '0;
        end else begin
          addr_req <= addr_req + 1'b1;
        end
      end
    end
  end

  generate
    if (USE_FILE_ROM) begin : g_file_rom
      logic signed [W-1:0] mem_i [0:DEPTH-1];
      logic signed [W-1:0] mem_q [0:DEPTH-1];
      initial begin
        $display("rom_reader: USE_FILE_ROM=1, loading I/Q from %s / %s", MEM_I_FILE, MEM_Q_FILE);
        $readmemh(MEM_I_FILE, mem_i);
        $readmemh(MEM_Q_FILE, mem_q);
      end
      always_ff @(posedge clk) begin
        if (enable_d1) begin
          i_data <= mem_i[addr_req_d1];
          q_data <= mem_q[addr_req_d1];
        end
      end
    end else begin : g_bram_rom
      // ROM instances (I/Q)
      // NOTE: blk_mem_gen_* IPs must exist in the project.
      blk_mem_gen_I u_rom_i (
        .clka (clk),
        .addra(addr_req),
        .douta(i_data)
      );

      blk_mem_gen_Q u_rom_q (
        .clka (clk),
        .addra(addr_req),
        .douta(q_data)
      );
    end
  endgenerate

endmodule

`default_nettype wire
