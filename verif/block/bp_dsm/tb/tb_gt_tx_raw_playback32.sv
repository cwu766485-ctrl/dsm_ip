`timescale 1ns/1ps
`default_nettype none

module tb_gt_tx_raw_playback32;
  logic clk = 1'b0, rst_n = 1'b0, start = 1'b0, repeat_enable = 1'b0;
  logic gt_ready = 1'b0;
  wire gt_valid, active, done;
  wire [31:0] gt_data;
  integer expected [0:3];
  integer accepted, errors, cycles;
  logic done_seen;

  gt_tx_raw_playback32 #(.MEM_DEPTH(4)) dut (
    .clk(clk), .rst_n(rst_n), .start(start), .repeat_enable(repeat_enable),
    .gt_valid(gt_valid), .gt_ready(gt_ready), .gt_data(gt_data),
    .active(active), .done(done)
  );
  always #5 clk = ~clk;

  initial begin
    expected[0] = 32'h0123_4567; expected[1] = 32'h89ab_cdef;
    expected[2] = 32'h55aa_00ff; expected[3] = 32'hc001_d00d;
    dut.u_playback.mem[0] = expected[0]; dut.u_playback.mem[1] = expected[1];
    dut.u_playback.mem[2] = expected[2]; dut.u_playback.mem[3] = expected[3];
    accepted = 0; errors = 0; cycles = 0; done_seen = 1'b0;
    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    @(negedge clk); start = 1'b1;
    @(negedge clk); start = 1'b0;
    while (accepted < 4 && cycles < 40) begin
      @(negedge clk);
      cycles = cycles + 1;
      gt_ready = !((cycles == 2) || (cycles == 3) || (cycles == 6));
    end
    @(negedge clk); gt_ready = 1'b1;
    repeat (3) @(negedge clk);
    if (!done_seen) $fatal(1, "done pulse missing");
    if (errors != 0) $fatal(1, "playback errors=%0d", errors);
    if (accepted != 4) $fatal(1, "accepted %0d words", accepted);
    $display("GT_TX_RAW_PLAYBACK32_PASS words=%0d", accepted);
    $finish;
  end

  always @(posedge clk) begin
    if (gt_valid && gt_ready) begin
      if (accepted >= 4 || gt_data !== expected[accepted]) begin
        $error("playback word mismatch accepted=%0d data=%h", accepted, gt_data);
        errors = errors + 1;
      end
      accepted = accepted + 1;
    end
    #1;
    if (done) done_seen = 1'b1;
  end
endmodule

`default_nettype wire
