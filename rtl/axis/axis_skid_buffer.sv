`timescale 1ns/1ps
`default_nettype none

module axis_skid_buffer #(
  parameter int DATA_W = 32
) (
  input  wire                 clk,
  input  wire                 rst_n,
  input  wire                 clear,

  input  wire [DATA_W-1:0]    s_data,
  input  wire                 s_valid,
  output wire                 s_ready,

  output wire [DATA_W-1:0]    m_data,
  output wire                 m_valid,
  input  wire                 m_ready,

  output wire                 full
);

  logic [DATA_W-1:0] data_q;
  logic valid_q;

  assign s_ready = (!valid_q) || m_ready;
  assign m_valid = valid_q;
  assign m_data = data_q;
  assign full = valid_q;

  always_ff @(posedge clk) begin
    if (!rst_n || clear) begin
      valid_q <= 1'b0;
      data_q <= '0;
    end else if (s_ready) begin
      valid_q <= s_valid;
      if (s_valid) begin
        data_q <= s_data;
      end
    end
  end
endmodule

`default_nettype wire
