`timescale 1ns/1ps
`default_nettype none

// Block-only verification of the diagnostic 32-bit counters. The overflow
// case seeds the real register immediately before wrap; this is arithmetic
// contract testing and is never merged into product-level coverage.
module tb_dpd_memory_poly_counter_contract;
  localparam int N_STREAM = 16;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic [2:0] active_taps = 3'd1;
  logic signed [15:0] c1_re = 16'sd32767;
  logic signed [15:0] c1_im = '0;
  logic signed [15:0] c3_re = '0;
  logic signed [15:0] c3_im = '0;
  logic signed [15:0] c5_re = '0;
  logic signed [15:0] c5_im = '0;
  logic signed [15:0] i_in = '0;
  logic signed [15:0] q_in = '0;
  logic in_valid = 1'b0;
  logic out_ready = 1'b1;
  wire in_ready;
  wire signed [15:0] i_out, q_out;
  wire out_valid;
  wire [31:0] sample_count, saturation_count;

  logic signed [15:0] expected_i [0:31];
  logic signed [15:0] expected_q [0:31];
  logic expected_saturated [0:31];
  integer sent = 0;
  integer received = 0;
  integer checker_errors = 0;

  always #5 clk = ~clk;

  dpd_memory_poly #(.MAX_TAPS(1)) dut (
    .clk(clk), .rst_n(rst_n), .active_taps(active_taps),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .i_in(i_in), .q_in(q_in),
    .i_tap_vec(16'd0), .q_tap_vec(16'd0),
    .in_valid(in_valid), .in_ready(in_ready), .i_out(i_out), .q_out(q_out),
    .out_valid(out_valid), .out_ready(out_ready),
    .sample_count(sample_count), .saturation_count(saturation_count)
  );

  function automatic logic signed [15:0] ref_i(input logic signed [15:0] sample);
    longint signed product, shifted;
    begin
      product = sample * 32767;
      shifted = product >>> 14;
      if (shifted > 32767) ref_i = 16'sh7fff;
      else if (shifted < -32768) ref_i = 16'sh8000;
      else ref_i = shifted[15:0];
    end
  endfunction

  function automatic logic ref_sat(input logic signed [15:0] sample);
    longint signed product, shifted;
    begin
      product = sample * 32767;
      shifted = product >>> 14;
      ref_sat = (shifted > 32767) || (shifted < -32768);
    end
  endfunction

  always @(posedge clk) begin
    if (!rst_n) begin
      sent <= 0;
      received <= 0;
    end else begin
      if (in_valid && in_ready) begin
        expected_i[sent] <= ref_i(i_in);
        expected_q[sent] <= 16'sd0;
        expected_saturated[sent] <= ref_sat(i_in);
        sent <= sent + 1;
      end
      if (out_valid && out_ready) begin
        if (received >= sent) begin
          checker_errors <= checker_errors + 1;
          $fatal(1, "counter-contract oracle saw output without accepted input");
        end
        if (i_out !== expected_i[received] || q_out !== expected_q[received]) begin
          checker_errors <= checker_errors + 1;
          $fatal(1, "counter-contract bit-true mismatch index=%0d got=(%0d,%0d) expected=(%0d,%0d)",
                 received, i_out, q_out, expected_i[received], expected_q[received]);
        end
        received <= received + 1;
      end
    end
  end

  task automatic send(input logic signed [15:0] iv);
    begin
      @(negedge clk);
      i_in = iv;
      q_in = 16'sd0;
      in_valid = 1'b1;
      do @(posedge clk); while (!in_ready);
    end
  endtask

  task automatic reset_dut;
    begin
      @(negedge clk);
      rst_n = 1'b0;
      in_valid = 1'b0;
      out_ready = 1'b1;
      #1;
      if (sample_count !== 0 || saturation_count !== 0)
        $fatal(1,"asynchronous counter reset did not act before the next clock");
      repeat (3) @(posedge clk);
      #1;
      if (sample_count !== 32'd0 || saturation_count !== 32'd0)
        $fatal(1, "asynchronous reset did not clear counters");
      @(negedge clk);
      rst_n = 1'b1;
    end
  endtask

  initial begin : run_contract
    int before_stall;
    int sat_expected;
    logic [31:0] held_saturation;
    logic signed [15:0] value;
    rst_n = 1'b0;
    repeat (4) @(negedge clk);
    rst_n = 1'b1;

    // Fill the eleven-stage pipeline with its sink blocked. The twelfth
    // stable input must not advance either the input counter or the pipeline.
    out_ready = 1'b0;
    for (int n = 0; n < 11; n++) begin
      case (n % 4)
        0: value = 16'sh7fff;
        1: value = 16'sh8000;
        2: value = 16'sd0;
        default: value = 16'sd12000;
      endcase
      send(value);
    end
    @(negedge clk);
    i_in = 16'sd16000;
    q_in = '0;
    in_valid = 1'b1;
    held_saturation = saturation_count;
    repeat (2) begin
      @(posedge clk);
      #1;
      if (in_ready !== 1'b0 || sample_count !== 32'd11 ||
          saturation_count !== held_saturation || out_valid !== 1'b1)
        $fatal(1, "full-pipeline enable/hold contract failed ready=%b count=%0d valid=%b",
               in_ready, sample_count, out_valid);
    end
    before_stall = sample_count;
    @(negedge clk);
    out_ready = 1'b1;
    do @(posedge clk); while (!in_ready);
    @(negedge clk);
    in_valid = 1'b0;
    for (int n = 12; n < N_STREAM; n++) begin
      case (n % 4)
        0: value = 16'sh7fff;
        1: value = 16'sh8000;
        2: value = 16'sd0;
        default: value = -16'sd12000;
      endcase
      send(value);
    end
    @(negedge clk);
    in_valid = 1'b0;
    wait (received == N_STREAM);
    #1;
    sat_expected = 0;
    for (int n = 0; n < N_STREAM; n++)
      if (expected_saturated[n]) sat_expected++;
    if (sample_count !== N_STREAM || saturation_count !== sat_expected ||
        before_stall != 11 || checker_errors != 0)
      $fatal(1, "counter contract mismatch samples=%0d/%0d saturation=%0d/%0d",
             sample_count, N_STREAM, saturation_count, sat_expected);

    // Reset and exercise actual 32-bit carry/wrap at the isolated block.
    // These deposits are not product-level toggle coverage evidence.
    reset_dut();
    $deposit(dut.sample_count, 32'hffff_fffe);
    $deposit(dut.saturation_count, 32'hffff_fffe);
    send(16'sh7fff);
    #1;
    if (sample_count !== 32'hffff_ffff)
      $fatal(1, "sample_count carry-to-bit31 mismatch after first seeded increment: %h", sample_count);
    send(16'sh8000);
    #1;
    if (sample_count !== 32'd0)
      $fatal(1, "sample_count modulo-2^32 wrap mismatch: %h", sample_count);
    @(negedge clk);
    in_valid = 1'b0;
    wait (received == 1);
    #1;
    if (saturation_count !== 32'hffff_ffff)
      $fatal(1, "saturation_count carry-to-bit31 mismatch: %h", saturation_count);
    wait (received == 2);
    #1;
    if (sample_count !== 32'd0 || saturation_count !== 32'd0)
      $fatal(1, "counter modulo-2^32 wrap mismatch sample=%h saturation=%h",
             sample_count, saturation_count);

    // Check carry across every bit boundary, including the MSB. Each case
    // drains before reset; register deposits remain block-only evidence.
    for (int bit_index=1; bit_index<32; bit_index++) begin
      reset_dut();
      $deposit(dut.sample_count, (32'h1 << bit_index)-1);
      $deposit(dut.saturation_count, (32'h1 << bit_index)-1);
      send(16'sh7fff);
      #1;
      if (sample_count !== (32'h1 << bit_index))
        $fatal(1,"sample carry failed at bit %0d",bit_index);
      @(negedge clk); in_valid=0;
      wait (received==1);
      #1;
      if (saturation_count !== (32'h1 << bit_index))
        $fatal(1,"saturation carry failed at bit %0d",bit_index);
    end

    reset_dut();
    if (sample_count !== 32'd0 || saturation_count !== 32'd0)
      $fatal(1, "final counter reset check failed");
    $display("DPD_MEMORY_COUNTER_CONTRACT_PASS samples=%0d saturation=%0d carry_boundaries=31 stall_hold=PASS async_reset=PASS wrap=PASS", N_STREAM, sat_expected);
    $finish;
  end

  initial begin
    #2000000;
    $fatal(1, "counter-contract test timeout sent=%0d received=%0d", sent, received);
  end
endmodule

`default_nettype wire
