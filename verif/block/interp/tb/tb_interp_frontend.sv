`timescale 1ns/1ps
`default_nettype none

module tb_interp_frontend;
  localparam int W = 16;
  localparam int N_IN = 128;
  localparam int MAX_OUT = N_IN * 32;
  localparam int MAX_CYCLES = 50000;

  logic clk;
  logic rst_n;
  logic enable;

  logic signed [W-1:0] stim_i [0:N_IN-1];
  logic signed [W-1:0] stim_q [0:N_IN-1];

  logic signed [W-1:0] i_in [0:4];
  logic signed [W-1:0] q_in [0:4];
  logic in_valid [0:4];
  wire  in_ready [0:4];
  wire signed [W-1:0] i_out [0:4];
  wire signed [W-1:0] q_out [0:4];
  wire out_valid [0:4];

  int unsigned in_count [0:4];
  int unsigned out_count [0:4];
  int first_in_cycle [0:4];
  int first_out_cycle [0:4];
  int unsigned cycle_count;
  integer fout [0:4];

  function automatic int expected_latency(input int mode);
    begin
      case (mode)
        0: expected_latency = 0;
        1: expected_latency = 8;
        2: expected_latency = 12;
        3: expected_latency = 16;
        4: expected_latency = 16;
        default: expected_latency = -1;
      endcase
    end
  endfunction

  initial clk = 1'b0;
  always #5 clk = ~clk;

  genvar gm;
  generate
    for (gm = 0; gm < 5; gm = gm + 1) begin : g_mode
      dsm_interp_frontend #(
        .W_IN(W),
        .W_OUT(W),
        .INTERP_MODE(gm)
      ) u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .i_in(i_in[gm]),
        .q_in(q_in[gm]),
        .in_valid(in_valid[gm]),
        .in_ready(in_ready[gm]),
        .i_out(i_out[gm]),
        .q_out(q_out[gm]),
        .out_valid(out_valid[gm]),
        .out_ready(1'b1)
      );
    end
  endgenerate

  initial begin
    integer fin;
    integer code;
    string line;
    int n;
    int idx_read;
    int ii;
    int qq;
    int fgets_code;

    fin = $fopen("interp_input_iq.csv", "r");
    if (fin == 0) $fatal(1, "cannot open interp_input_iq.csv");
    fgets_code = $fgets(line, fin);
    for (n = 0; n < N_IN; n = n + 1) begin
      code = $fscanf(fin, "%d,%d,%d\n", idx_read, ii, qq);
      if (code != 3) $fatal(1, "bad input csv at row %0d", n);
      stim_i[n] = signed'(ii);
      stim_q[n] = signed'(qq);
    end
    $fclose(fin);

    fout[0] = $fopen("interp_mode0_rtl.csv", "w");
    fout[1] = $fopen("interp_mode1_rtl.csv", "w");
    fout[2] = $fopen("interp_mode2_rtl.csv", "w");
    fout[3] = $fopen("interp_mode3_rtl.csv", "w");
    fout[4] = $fopen("interp_mode4_rtl.csv", "w");
    for (int m = 0; m < 5; m = m + 1) begin
      if (fout[m] == 0) $fatal(1, "cannot open interp output %0d", m);
      $fwrite(fout[m], "n,i_q1_15,q_q1_15\n");
    end

    rst_n = 1'b0;
    enable = 1'b0;
    repeat (8) @(posedge clk);
    rst_n = 1'b1;
    enable = 1'b1;

    wait ((out_count[0] == N_IN) &&
          (out_count[1] == N_IN * 4) &&
          (out_count[2] == N_IN * 8) &&
          (out_count[3] == N_IN * 16) &&
          (out_count[4] == N_IN * 32));

    repeat (4) @(posedge clk);
    for (int m = 0; m < 5; m = m + 1) begin
      if ((first_out_cycle[m] - first_in_cycle[m]) != expected_latency(m)) begin
        $fatal(1, "mode %0d first-output latency mismatch: got %0d expected %0d",
               m, first_out_cycle[m] - first_in_cycle[m], expected_latency(m));
      end
      $display("interp mode %0d latency PASS: %0d cycles", m, expected_latency(m));
    end
    for (int m = 0; m < 5; m = m + 1) begin
      $fclose(fout[m]);
    end
    $display("TB interp frontend done");
    $finish;
  end

  always_comb begin
    for (int m = 0; m < 5; m = m + 1) begin
      in_valid[m] = enable && (in_count[m] < N_IN) && in_ready[m];
      i_in[m] = (in_count[m] < N_IN) ? stim_i[in_count[m]] : '0;
      q_in[m] = (in_count[m] < N_IN) ? stim_q[in_count[m]] : '0;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      cycle_count <= 0;
      for (int m = 0; m < 5; m = m + 1) begin
        in_count[m] <= 0;
        out_count[m] <= 0;
        first_in_cycle[m] <= -1;
        first_out_cycle[m] <= -1;
      end
    end else begin
      cycle_count <= cycle_count + 1;
      if (cycle_count > MAX_CYCLES) begin
        $fatal(1, "interp frontend timeout");
      end

      for (int m = 0; m < 5; m = m + 1) begin
        if (in_valid[m] && in_ready[m]) begin
          if (first_in_cycle[m] < 0) begin
            first_in_cycle[m] <= int'(cycle_count);
          end
          in_count[m] <= in_count[m] + 1;
        end
        if (out_valid[m]) begin
          if (out_count[m] >= MAX_OUT) $fatal(1, "too many outputs for mode %0d", m);
          if (first_out_cycle[m] < 0) begin
            first_out_cycle[m] <= int'(cycle_count);
          end
          $fwrite(fout[m], "%0d,%0d,%0d\n", out_count[m], i_out[m], q_out[m]);
          out_count[m] <= out_count[m] + 1;
        end
      end
    end
  end
endmodule

`default_nettype wire
