`timescale 1ns/1ps
`default_nettype none

module tb_tid32_thermo5_fs4_multipa_tx_bittrue;
  localparam int W = 16;
  localparam int LANES = 32;
  localparam int VECTORS = 128;
  logic clk = 1'b0, rst_n = 1'b0, in_valid = 1'b0;
  logic [3:0] pa_ready = '0;
  logic signed [LANES*W-1:0] in_i_poly_vec = '0, in_q_poly_vec = '0;
  wire in_ready;
  wire [3:0] pa_valid;
  wire [2*LANES-1:0] pa_data [0:3];
  logic [W-1:0] i_mem [0:LANES*VECTORS-1];
  logic [W-1:0] q_mem [0:LANES*VECTORS-1];
  // Keep each file target as a one-dimensional memory.  XSim's $readmemh
  // does not reliably populate a selected row of a two-dimensional unpacked
  // array, which otherwise leaves the final expected words at zero.
  logic [2*LANES-1:0] pa0_mem [0:VECTORS-1];
  logic [2*LANES-1:0] pa1_mem [0:VECTORS-1];
  logic [2*LANES-1:0] pa2_mem [0:VECTORS-1];
  logic [2*LANES-1:0] pa3_mem [0:VECTORS-1];
  integer n, lane, branch, accepted, errors, timeout;

  tid32_thermo5_fs4_multipa_tx #(.W(W), .CHANNELS(LANES), .STEP(6144)) dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
    .in_i_poly_vec(in_i_poly_vec), .in_q_poly_vec(in_q_poly_vec),
    .pa_valid(pa_valid), .pa_data(pa_data), .pa_ready(pa_ready)
  );
  always #5 clk = ~clk;

  initial begin
    $readmemh("tid32_thermo5_i.mem", i_mem);
    $readmemh("tid32_thermo5_q.mem", q_mem);
    $readmemh("tid32_thermo5_pa0.mem", pa0_mem);
    $readmemh("tid32_thermo5_pa1.mem", pa1_mem);
    $readmemh("tid32_thermo5_pa2.mem", pa2_mem);
    $readmemh("tid32_thermo5_pa3.mem", pa3_mem);
    accepted = 0; errors = 0;
    repeat (3) @(negedge clk);
    rst_n = 1'b1; pa_ready = 4'b1111;
    for (n = 0; n < VECTORS; n = n + 1) begin
      @(negedge clk);
      if (!in_ready) $fatal(1, "Unexpected input backpressure at word %0d", n);
      for (lane = 0; lane < LANES; lane = lane + 1) begin
        in_i_poly_vec[lane*W +: W] = i_mem[n*LANES+lane];
        in_q_poly_vec[lane*W +: W] = q_mem[n*LANES+lane];
      end
      in_valid = 1'b1;
    end
    @(negedge clk);
    in_valid = 1'b0;
    timeout = 0;
    while (accepted < VECTORS && timeout < 16) begin @(negedge clk); timeout = timeout + 1; end
    if (accepted != VECTORS) $fatal(1, "Accepted %0d PA word quartets", accepted);
    if (errors != 0) $fatal(1, "TID32 thermo5 mismatches=%0d", errors);
    $display("TID32_THERMO5_FS4_MULTIPA_BITTRUE_PASS vectors=%0d samples=%0d", VECTORS, VECTORS*LANES);
    $finish;
  end

  always @(posedge clk) begin
    if (rst_n && pa_valid != {4{pa_valid[0]}})
      $fatal(1, "PA valid streams lost thermometric alignment: %b", pa_valid);
    if (rst_n && (&pa_valid) && (&pa_ready)) begin
      if (pa_data[0] !== pa0_mem[accepted]) begin $error("PA0 mismatch word=%0d", accepted); errors = errors + 1; end
      if (pa_data[1] !== pa1_mem[accepted]) begin $error("PA1 mismatch word=%0d", accepted); errors = errors + 1; end
      if (pa_data[2] !== pa2_mem[accepted]) begin $error("PA2 mismatch word=%0d", accepted); errors = errors + 1; end
      if (pa_data[3] !== pa3_mem[accepted]) begin $error("PA3 mismatch word=%0d", accepted); errors = errors + 1; end
      accepted = accepted + 1;
    end
  end
endmodule

`default_nettype wire
