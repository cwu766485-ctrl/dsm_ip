`timescale 1ns/1ps
`default_nettype none

// Exercise the reusable Memory-Poly flow-control boundary directly.  A one-tap
// unit C1 coefficient makes the arithmetic oracle exact: accepted output I/Q
// must equal the accepted input I/Q, even while the ten-stage pipeline stalls.
module tb_dpd_memory_poly_random_protocol;
  localparam int N = 173;
  localparam int MAX_CYCLES = 6000;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic [2:0] active_taps = 3'd1;
  logic signed [63:0] c1_re = 64'sd16384;
  logic signed [63:0] c1_im = '0;
  logic signed [63:0] c3_re = '0;
  logic signed [63:0] c3_im = '0;
  logic signed [63:0] c5_re = '0;
  logic signed [63:0] c5_im = '0;
  logic signed [15:0] i_in = '0;
  logic signed [15:0] q_in = '0;
  logic in_valid = 1'b0;
  logic out_ready = 1'b0;
  wire in_ready;
  wire signed [15:0] i_out;
  wire signed [15:0] q_out;
  wire out_valid;
  wire [31:0] sample_count;
  wire [31:0] saturation_count;

  logic signed [15:0] expected_i [0:N-1];
  logic signed [15:0] expected_q [0:N-1];
  logic hold_active;
  logic signed [15:0] hold_i;
  logic signed [15:0] hold_q;
  integer sent = 0;
  integer received = 0;
  integer cycle_count = 0;
  integer output_stall_count = 0;
  integer full_stall_count = 0;
  integer lfsr = 32'h1bad_f00d;

  always #5 clk = ~clk;

  function automatic integer next_lfsr(input integer value);
    begin
      next_lfsr = (value << 1) ^ (((value >> 31) ^ (value >> 21) ^
                                   (value >> 1) ^ value) & 1);
    end
  endfunction

  function automatic logic signed [15:0] stimulus(input integer n, input logic is_q);
    integer raw;
    begin
      case (n)
        0: stimulus = 16'sh8000;
        1: stimulus = 16'sh7fff;
        2: stimulus = 16'sd0;
        default: begin
          raw = is_q ? (n * -911 + 271) : (n * 1223 - 733);
          stimulus = raw[15:0];
        end
      endcase
    end
  endfunction

  dpd_memory_poly dut (
    .clk(clk), .rst_n(rst_n), .active_taps(active_taps),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .i_in(i_in), .q_in(q_in),
    .in_valid(in_valid), .in_ready(in_ready), .i_out(i_out), .q_out(q_out),
    .out_valid(out_valid), .out_ready(out_ready), .sample_count(sample_count),
    .saturation_count(saturation_count)
  );

  always @(posedge clk) begin
    if (!rst_n) begin
      sent <= 0;
      received <= 0;
      cycle_count <= 0;
      output_stall_count <= 0;
      full_stall_count <= 0;
      hold_active <= 1'b0;
    end else begin
      cycle_count <= cycle_count + 1;
      if (cycle_count > MAX_CYCLES)
        $fatal(1, "Memory-Poly random protocol timeout");

      if (in_valid && in_ready) begin
        expected_i[sent] = i_in;
        expected_q[sent] = q_in;
        sent <= sent + 1;
      end
      if (in_valid && !in_ready)
        full_stall_count <= full_stall_count + 1;

      if (hold_active && !out_valid)
        $fatal(1, "out_valid dropped while Memory-Poly output was stalled");
      if (out_valid && !out_ready) begin
        output_stall_count <= output_stall_count + 1;
        if (hold_active) begin
          if (i_out !== hold_i || q_out !== hold_q)
            $fatal(1, "Memory-Poly changed output while stalled");
        end else begin
          hold_active <= 1'b1;
          hold_i <= i_out;
          hold_q <= q_out;
        end
      end else if (out_valid && out_ready) begin
        if (i_out !== expected_i[received] || q_out !== expected_q[received])
          $fatal(1, "Memory-Poly order/data mismatch n=%0d got=(%0d,%0d) expected=(%0d,%0d)",
                 received, i_out, q_out, expected_i[received], expected_q[received]);
        received <= received + 1;
        hold_active <= 1'b0;
      end else begin
        hold_active <= 1'b0;
      end
    end
  end

  initial begin
    repeat (4) @(negedge clk);
    rst_n = 1'b1;

    // Fill the pipeline while the sink is stopped, then use randomized
    // valid/ready traffic.  This guarantees that pipe_ce is deasserted.
    while (received < N) begin
      @(negedge clk);
      if (cycle_count < 24) begin
        out_ready = 1'b0;
        in_valid = (sent < N);
      end else begin
        lfsr = next_lfsr(lfsr);
        out_ready = lfsr[1] | lfsr[5];
        in_valid = (sent < N) && (lfsr[0] | lfsr[4]);
      end
      i_in = stimulus(sent, 1'b0);
      q_in = stimulus(sent, 1'b1);
    end

    @(negedge clk);
    in_valid = 1'b0;
    out_ready = 1'b1;
    repeat (3) @(posedge clk);
    if (sent != N || received != N)
      $fatal(1, "Memory-Poly transaction count mismatch sent=%0d received=%0d", sent, received);
    if (sample_count != N)
      $fatal(1, "Memory-Poly sample_count mismatch got=%0d expected=%0d", sample_count, N);
    if (saturation_count != 0)
      $fatal(1, "Memory-Poly unit-gain test unexpectedly saturated %0d samples", saturation_count);
    if (output_stall_count == 0 || full_stall_count == 0)
      $fatal(1, "Memory-Poly test did not reach output/full pipeline stalls out=%0d full=%0d",
             output_stall_count, full_stall_count);
    $display("DPD_MEMORY_RANDOM_PROTOCOL_PASS samples=%0d output_stalls=%0d full_stalls=%0d",
             N, output_stall_count, full_stall_count);
    $finish;
  end
endmodule

`default_nettype wire
