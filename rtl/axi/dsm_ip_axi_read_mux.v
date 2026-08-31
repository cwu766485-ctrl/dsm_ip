`default_nettype none

// Pure combinational readback selector for the DSM IP AXI-Lite register map.
//
// The integration wrapper owns the register state and packs each readable
// register into read_words[word_index].  Keeping the selector stateless makes
// it safe to reuse while the AXI-Lite response channel continues to capture
// read_data at AR handshake time in dsm_ip_axi_top.
module dsm_ip_axi_read_mux #(
  parameter integer WORD_COUNT = 72
) (
  input  wire [6:0]                  read_addr,
  input  wire [(WORD_COUNT*32)-1:0]  read_words,
  output reg  [31:0]                 read_data
);

  always @* begin
    read_data = 32'h0000_0000;
    if (read_addr < WORD_COUNT) begin
      // Address zero occupies bits [31:0]; each subsequent word advances by
      // 32 bits. The zero extension prevents a narrow-address shift overflow.
      read_data = read_words[({5'd0, read_addr} << 5) +: 32];
    end
  end

endmodule

`default_nettype wire
