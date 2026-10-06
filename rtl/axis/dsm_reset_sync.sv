`timescale 1ns/1ps
`default_nettype none

// Asynchronous assertion, two-flop synchronous deassertion reset synchronizer.
// Instantiate one per clock domain; the input reset may be shared.
module dsm_reset_sync (
  input  wire logic clk,
  input  wire logic arst_n,
  output wire logic srst_n
);
  (* ASYNC_REG = "TRUE" *) logic [1:0] sync_q;

  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n)
      sync_q <= 2'b00;
    else
      sync_q <= {sync_q[0], 1'b1};
  end

  assign srst_n = sync_q[1];

`ifndef SYNTHESIS
  // Reset may assert at any time, but release must traverse both local-clock
  // synchronizer stages.  In particular, srst_n cannot rise on the first
  // local clock edge after asynchronous reset is released.
  always_ff @(posedge clk) begin
    if (!arst_n || !sync_q[0]) begin
      assert (!srst_n)
        else $error("DSM synchronized reset released before two local clock edges");
    end
  end
`endif
endmodule

`default_nettype wire
