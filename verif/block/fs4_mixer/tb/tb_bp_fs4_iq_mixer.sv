`timescale 1ns/1ps
`default_nettype none

module tb_bp_fs4_iq_mixer;
  localparam int W = 16;
  localparam int N = 8;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic in_valid = 1'b0;
  logic signed [W-1:0] i_in = '0;
  logic signed [W-1:0] q_in = '0;
  wire out_valid;
  wire signed [W-1:0] if_out;
  wire [1:0] phase;

  logic signed [W-1:0] i_vector [0:N-1];
  logic signed [W-1:0] q_vector [0:N-1];
  logic signed [W-1:0] if_expected [0:N-1];
  logic [1:0] phase_expected [0:N-1];
  integer out_count = 0;
  integer mismatch_count = 0;
  logic [1:0] idle_phase;

  bp_fs4_iq_mixer #(.W(W)) dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_in(i_in), .q_in(q_in),
    .out_valid(out_valid), .if_out(if_out), .phase(phase)
  );

  always #5 clk = ~clk;

  function automatic logic signed [W-1:0] fs4_select(
    input logic [1:0] phase_in,
    input logic signed [W-1:0] i_value,
    input logic signed [W-1:0] q_value
  );
    begin
      case (phase_in)
        2'd0: fs4_select = i_value;
        2'd1: fs4_select = q_value;
        2'd2: fs4_select = -i_value;
        default: fs4_select = -q_value;
      endcase
    end
  endfunction

  initial begin : initialize_vectors
    i_vector[0] = 16'sd101;    q_vector[0] = -16'sd301;
    i_vector[1] = -16'sd102;   q_vector[1] = 16'sd302;
    i_vector[2] = 16'sd103;    q_vector[2] = -16'sd303;
    i_vector[3] = -16'sd104;   q_vector[3] = 16'sd304;
    i_vector[4] = 16'sh8000;   q_vector[4] = 16'sd305;
    i_vector[5] = 16'sd106;    q_vector[5] = 16'sh8000;
    i_vector[6] = -16'sd107;   q_vector[6] = 16'sd307;
    i_vector[7] = 16'sd108;    q_vector[7] = -16'sd308;
    for (int n = 0; n < N; n++) begin
      phase_expected[n] = n[1:0];
      if_expected[n] = fs4_select(n[1:0], i_vector[n], q_vector[n]);
    end
  end

  initial begin : drive_and_check
    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    for (int n = 0; n < N; n++) begin
      @(negedge clk);
      #1;
      in_valid = 1'b1;
      i_in = i_vector[n];
      q_in = q_vector[n];
    end
    @(negedge clk);
    #1;
    in_valid = 1'b0;
    i_in = '0;
    q_in = '0;
    idle_phase = phase;
    repeat (2) @(negedge clk);
    if (phase !== idle_phase)
      $fatal(1, "phase advanced while in_valid was low: got=%0d expected=%0d",
        phase, idle_phase);
    if (out_count != N) $fatal(1, "output count mismatch: got=%0d expected=%0d", out_count, N);
    if (mismatch_count != 0) $fatal(1, "Fs/4 mixer mismatches=%0d", mismatch_count);
    $display("FS4_MIXER_BLOCK_PASS samples=%0d", N);
    $finish;
  end

  always @(negedge clk) begin
    if (rst_n && out_valid) begin
      if ($signed(if_out) !== if_expected[out_count]) begin
        $error("IF mismatch n=%0d actual=%0d expected=%0d", out_count,
          $signed(if_out), if_expected[out_count]);
        mismatch_count = mismatch_count + 1;
      end
      if (phase !== phase_expected[out_count]) begin
        $error("phase mismatch n=%0d actual=%0d expected=%0d", out_count,
          phase, phase_expected[out_count]);
        mismatch_count = mismatch_count + 1;
      end
      out_count = out_count + 1;
    end
  end
endmodule

`default_nettype wire
