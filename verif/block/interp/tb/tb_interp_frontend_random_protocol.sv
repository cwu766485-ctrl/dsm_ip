`timescale 1ns/1ps
`default_nettype none

// Random valid/ready regression for all shipping interpolation modes. Exact
// coefficients are covered by the MATLAB bit-true dump test; this test covers
// protocol preservation under bubbles and output stalls.
module tb_interp_frontend_random_protocol;
  localparam int W = 16;
  localparam int N_IN = 97;
  localparam int MAX_CYCLES = 120000;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic enable = 1'b0;
  logic signed [W-1:0] i_in [0:4];
  logic signed [W-1:0] q_in [0:4];
  logic in_valid [0:4];
  wire in_ready [0:4];
  wire signed [W-1:0] i_out [0:4];
  wire signed [W-1:0] q_out [0:4];
  wire out_valid [0:4];
  logic out_ready;
  integer in_count [0:4];
  integer out_count [0:4];
  integer cycle_count = 0;
  integer lfsr = 32'h5eed_1234;
  integer stall_count = 0;

  function automatic integer next_lfsr(input integer value);
    begin
      next_lfsr = (value << 1) ^ (((value >> 31) ^ (value >> 21) ^
                                    (value >> 1) ^ value) & 1);
    end
  endfunction

  function automatic logic signed [W-1:0] stimulus(input integer n, input logic is_q);
    integer raw;
    begin
      case (n)
        0: stimulus = 16'sh8000;
        1: stimulus = 16'sh7fff;
        2: stimulus = 16'sd0;
        3: stimulus = -16'sd1;
        default: begin
          raw = is_q ? (n * -1597 + 831) : (n * 2011 - 593);
          stimulus = raw[W-1:0];
        end
      endcase
    end
  endfunction

  function automatic integer factor(input integer mode);
    begin
      case (mode)
        0: factor = 1;
        1: factor = 4;
        2: factor = 8;
        3: factor = 16;
        default: factor = 32;
      endcase
    end
  endfunction

  genvar gm;
  generate
    for (gm = 0; gm < 5; gm = gm + 1) begin : g_mode
      dsm_interp_frontend #(.W_IN(W), .W_OUT(W), .INTERP_MODE(gm)) dut (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .i_in(i_in[gm]), .q_in(q_in[gm]), .in_valid(in_valid[gm]),
        .in_ready(in_ready[gm]), .i_out(i_out[gm]), .q_out(q_out[gm]),
        .out_valid(out_valid[gm]), .out_ready(out_ready)
      );
    end
  endgenerate

  always #5 clk = ~clk;

  always_comb begin
    for (int m = 0; m < 5; m++) begin
      i_in[m] = stimulus(in_count[m], 1'b0);
      q_in[m] = stimulus(in_count[m], 1'b1);
      in_valid[m] = enable && (in_count[m] < N_IN) && lfsr[0];
    end
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      cycle_count <= 0;
      for (int m = 0; m < 5; m++) begin
        in_count[m] <= 0;
        out_count[m] <= 0;
      end
    end else begin
      cycle_count <= cycle_count + 1;
      if (cycle_count > MAX_CYCLES) $fatal(1, "interp random protocol timeout");
      for (int m = 0; m < 5; m++) begin
        if (in_valid[m] && in_ready[m]) in_count[m] <= in_count[m] + 1;
        if (out_valid[m] && out_ready) begin
          if ((^i_out[m] === 1'bx) || (^q_out[m] === 1'bx))
            $fatal(1, "interp mode %0d produced X data", m);
          if (out_count[m] >= N_IN * factor(m))
            $fatal(1, "interp mode %0d overproduced", m);
          out_count[m] <= out_count[m] + 1;
        end
        if (out_valid[m] && !out_ready) stall_count <= stall_count + 1;
      end
    end
  end

  initial begin
    out_ready = 1'b0;
    repeat (8) @(negedge clk);
    rst_n = 1'b1;
    enable = 1'b1;
    while ((out_count[0] != N_IN * factor(0)) ||
           (out_count[1] != N_IN * factor(1)) ||
           (out_count[2] != N_IN * factor(2)) ||
           (out_count[3] != N_IN * factor(3)) ||
           (out_count[4] != N_IN * factor(4))) begin
      @(negedge clk);
      lfsr = next_lfsr(lfsr);
      out_ready = lfsr[1] | lfsr[4];
    end
    @(negedge clk);
    enable = 1'b0;
    out_ready = 1'b1;
    repeat (4) @(posedge clk);
    for (int m = 0; m < 5; m++) begin
      if (in_count[m] != N_IN || out_count[m] != N_IN * factor(m))
        $fatal(1, "interp mode %0d count mismatch in=%0d out=%0d", m,
               in_count[m], out_count[m]);
    end
    if (stall_count == 0) $fatal(1, "interp random test did not create a stall");
    $display("INTERP_RANDOM_PROTOCOL_PASS inputs=%0d stalls=%0d", N_IN, stall_count);
    $finish;
  end
endmodule

`default_nettype wire
