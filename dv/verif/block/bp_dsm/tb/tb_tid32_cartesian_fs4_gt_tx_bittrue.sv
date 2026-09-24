`timescale 1ns/1ps
`default_nettype none

module tb_tid32_cartesian_fs4_gt_tx_bittrue;
  localparam int W = 16;
  localparam int LANES = 32;
  localparam int VECTORS = 128;
  logic clk = 1'b0, rst_n = 1'b0, in_valid = 1'b0, gt_ready = 1'b0;
  logic signed [LANES*W-1:0] in_i_poly_vec = '0, in_q_poly_vec = '0;
  wire in_ready, gt_valid;
  wire [2*LANES-1:0] gt_data;
  logic [W-1:0] i_mem [0:LANES*VECTORS-1];
  logic [W-1:0] q_mem [0:LANES*VECTORS-1];
  logic [2*LANES-1:0] gt_mem [0:VECTORS-1];
  integer n, lane, accepted, errors, timeout;

  tid32_cartesian_fs4_gt_tx #(.W(W), .CHANNELS(LANES)) dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
    .in_i_poly_vec(in_i_poly_vec), .in_q_poly_vec(in_q_poly_vec),
    .gt_valid(gt_valid), .gt_ready(gt_ready), .gt_data(gt_data)
  );
  always #5 clk = ~clk;

  initial begin
    $readmemh("tid32_i.mem", i_mem);
    $readmemh("tid32_q.mem", q_mem);
    $readmemh("tid32_gt.mem", gt_mem);
    accepted = 0; errors = 0;
    repeat (3) @(negedge clk);
    rst_n = 1'b1; gt_ready = 1'b1;
    for (n = 0; n < VECTORS; n = n + 1) begin
      @(negedge clk);
      if (!in_ready) $fatal(1, "Unexpected backpressure at word %0d", n);
      for (lane = 0; lane < LANES; lane = lane + 1) begin
        in_i_poly_vec[lane*W +: W] = i_mem[n*LANES+lane];
        in_q_poly_vec[lane*W +: W] = q_mem[n*LANES+lane];
      end
      in_valid = 1'b1;
    end
    @(negedge clk);
    in_valid = 1'b0;
    timeout = 0;
    while (accepted < VECTORS && timeout < 16) begin
      @(negedge clk);
      timeout = timeout + 1;
    end
    if (accepted != VECTORS) $fatal(1, "Accepted %0d GT words", accepted);
    if (errors != 0) $fatal(1, "TID32 bit-true mismatches=%0d", errors);
    $display("TID32_CARTESIAN_FS4_GT_TX_BITTRUE_PASS vectors=%0d samples=%0d", VECTORS, VECTORS*LANES);
    $finish;
  end

  always @(posedge clk) begin
    if (rst_n && gt_valid && gt_ready) begin
      if (gt_data !== gt_mem[accepted]) begin
        $error("TID32 mismatch word=%0d actual=%h expected=%h", accepted, gt_data, gt_mem[accepted]);
        errors = errors + 1;
      end
      accepted = accepted + 1;
    end
  end
endmodule

`default_nettype wire
