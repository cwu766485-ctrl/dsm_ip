`timescale 1ns/1ps
`default_nettype none

module tb_bp_fs4_iq_mixer_random;
  localparam W = 16;
  localparam N = 257;
  reg clk;
  reg rst_n;
  reg in_valid;
  reg signed [W-1:0] i_in;
  reg signed [W-1:0] q_in;
  wire out_valid;
  wire signed [W-1:0] if_out;
  wire [1:0] phase;
  reg expected_valid;
  reg signed [W-1:0] expected_if;
  reg [1:0] expected_phase;
  reg [1:0] model_phase;
  reg [1:0] held_phase;
  integer sent;
  integer received;
  integer lfsr;
  integer next_i;
  integer next_q;
  integer next_if;

  bp_fs4_iq_mixer #(.W(W)) dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_in(i_in), .q_in(q_in),
    .out_valid(out_valid), .if_out(if_out), .phase(phase)
  );

  always #5 clk = ~clk;

  initial begin
    clk = 0;
    rst_n = 0;
    in_valid = 0;
    i_in = 0;
    q_in = 0;
    expected_valid = 0;
    expected_if = 0;
    expected_phase = 0;
    model_phase = 0;
    sent = 0;
    received = 0;
    lfsr = 32'h1ace_b00c;
    repeat (4) @(negedge clk);
    rst_n = 1;

    while (received < N) begin
      @(negedge clk);
      if (expected_valid) begin
        if (!out_valid || $signed(if_out) !== expected_if || phase !== expected_phase)
          $fatal(1, "Fs/4 random mismatch n=%0d", received);
        received = received + 1;
      end else if (out_valid) begin
        $fatal(1, "Fs/4 random unexpected output n=%0d", received);
      end

      lfsr = (lfsr << 1) ^ (((lfsr >> 31) ^ (lfsr >> 21) ^
                              (lfsr >> 1) ^ lfsr) & 1);
      if ((sent < N) && lfsr[0]) begin
        if (sent == 0) begin
          next_i = -32768;
          next_q = 32767;
        end else if (sent == 1) begin
          next_i = 32767;
          next_q = -32768;
        end else begin
          next_i = sent * 2311 - 777;
          next_q = sent * -1879 + 309;
        end
        i_in = next_i;
        q_in = next_q;
        case (model_phase)
          2'd0: next_if = next_i;
          2'd1: next_if = next_q;
          2'd2: next_if = -next_i;
          default: next_if = -next_q;
        endcase
        expected_if = next_if;
        expected_phase = model_phase;
        expected_valid = 1;
        model_phase = model_phase + 1'b1;
        in_valid = 1;
        sent = sent + 1;
      end else begin
        expected_valid = 0;
        in_valid = 0;
        i_in = 0;
        q_in = 0;
      end
    end
    @(negedge clk);
    in_valid = 0;
    expected_valid = 0;
    held_phase = phase;
    repeat (6) @(negedge clk);
    if (phase !== held_phase) $fatal(1, "phase advanced during random idle interval");
    $display("FS4_MIXER_RANDOM_PASS samples=%0d", N);
    $finish;
  end
endmodule

`default_nettype wire
