// Simulation-only raw serializer/receiver contract for one 14-Gb/s PA path.
// A DATA_W=64 user word is emitted least-significant bit first at ser_clk;
// ser_clk must be DATA_W times usr_clk.  Four instances share both clocks and
// reset so their recovered words are phase aligned.  This is not a GT model.
`timescale 1ps/1fs
`default_nettype none

module raw64_serializer_loopback_model #(
  parameter int DATA_W = 64
) (
  input  wire logic              usr_clk,
  input  wire logic              ser_clk,
  input  wire logic              rst_n,
  input  wire logic              tx_valid,
  output wire logic              tx_ready,
  input  wire logic [DATA_W-1:0] tx_data,
  output logic                    serial_bit,
  output logic                    rx_valid,
  output logic [DATA_W-1:0]      rx_data
);
  logic [DATA_W-1:0] word_buf, active_word;
  integer bit_index;
  logic busy, req_toggle, req_seen;

  // The serial engine has exactly one user-word buffer.  Backpressure is part
  // of the contract: a four-plane thermometric symbol advances only when all
  // four serializer paths can accept its word.
  assign tx_ready = rst_n && !busy && (req_seen == req_toggle);

  always_ff @(posedge usr_clk or negedge rst_n) begin
    if (!rst_n) begin
      word_buf   <= '0;
      req_toggle <= 1'b0;
    end else if (tx_valid && tx_ready) begin
      word_buf   <= tx_data;
      req_toggle <= ~req_toggle;
    end
  end

  always_ff @(posedge ser_clk or negedge rst_n) begin
    if (!rst_n) begin
      busy       <= 1'b0;
      req_seen   <= 1'b0;
      bit_index  <= 0;
      serial_bit <= 1'b0;
      rx_valid   <= 1'b0;
      rx_data    <= '0;
    end else begin
      rx_valid <= 1'b0;
      if (!busy && (req_seen != req_toggle)) begin
        active_word <= word_buf;
        req_seen  <= req_toggle;
        busy      <= 1'b1;
        // Launch bit 0 on the same serial edge that consumes the user-word
        // request.  This makes one 64-bit word occupy exactly 64 serial
        // edges, matching the 64x clock-ratio contract without a bubble.
        serial_bit <= word_buf[0];
        rx_data[0] <= word_buf[0];
        bit_index  <= 1;
      end else if (busy) begin
        serial_bit          <= active_word[bit_index];
        rx_data[bit_index]  <= active_word[bit_index];
        if (bit_index == DATA_W-1) begin
          busy     <= 1'b0;
          rx_valid <= 1'b1;
        end else begin
          bit_index <= bit_index + 1;
        end
      end
    end
  end
endmodule

`default_nettype wire
