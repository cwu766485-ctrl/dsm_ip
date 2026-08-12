`timescale 1ns/1ps
`default_nettype none

module tb_interp_frontend_variants;
  localparam int W = 16;
  localparam int N_IN = 128;
  localparam int N_VARIANTS = 4;
  localparam int MAX_CYCLES = 30000;

  logic clk;
  logic rst_n;
  logic enable;
  logic signed [W-1:0] stim_i [0:N_IN-1];
  logic signed [W-1:0] stim_q [0:N_IN-1];
  logic signed [W-1:0] i_in [0:N_VARIANTS-1];
  logic signed [W-1:0] q_in [0:N_VARIANTS-1];
  logic in_valid [0:N_VARIANTS-1];
  wire in_ready [0:N_VARIANTS-1];
  wire signed [W-1:0] i_out [0:N_VARIANTS-1];
  wire signed [W-1:0] q_out [0:N_VARIANTS-1];
  wire out_valid [0:N_VARIANTS-1];
  logic out_ready;
  int unsigned in_count [0:N_VARIANTS-1];
  int unsigned out_count [0:N_VARIANTS-1];
  int unsigned cycle_count;
  integer fout [0:N_VARIANTS-1];

  initial clk = 1'b0;
  always #5 clk = ~clk;

  genvar gv;
  generate
    for (gv = 0; gv < N_VARIANTS; gv = gv + 1) begin : g_variant
      localparam int IMPL = (gv == 0) ? 0 :
                                ((gv == 1) ? 1 :
                                ((gv == 2) ? 2 : 3));
      dsm_interp_frontend #(
        .W_IN(W), .W_OUT(W), .INTERP_MODE(4), .INTERP_IMPL(IMPL)
      ) u_dut (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .i_in(i_in[gv]), .q_in(q_in[gv]), .in_valid(in_valid[gv]),
        .in_ready(in_ready[gv]), .i_out(i_out[gv]), .q_out(q_out[gv]),
        .out_valid(out_valid[gv]), .out_ready(out_ready)
      );
    end
  endgenerate

  initial begin
    integer fin;
    integer code;
    string line;
    int index_read;
    int ii;
    int qq;
    fin = $fopen("interp_input_iq.csv", "r");
    if (fin == 0) $fatal(1, "cannot open interp_input_iq.csv");
    code = $fgets(line, fin);
    for (int n = 0; n < N_IN; n = n + 1) begin
      code = $fscanf(fin, "%d,%d,%d\n", index_read, ii, qq);
      if (code != 3) $fatal(1, "bad input CSV at row %0d", n);
      stim_i[n] = signed'(ii);
      stim_q[n] = signed'(qq);
    end
    $fclose(fin);

    rst_n = 1'b0;
    enable = 1'b0;
    fout[0] = $fopen("interp_I0_rtl.csv", "w");
    fout[1] = $fopen("interp_I1_rtl.csv", "w");
    fout[2] = $fopen("interp_I2_rtl.csv", "w");
    fout[3] = $fopen("interp_I3_rtl.csv", "w");
    for (int v = 0; v < N_VARIANTS; v = v + 1) begin
      if (fout[v] == 0) $fatal(1, "cannot open variant output %0d", v);
      $fwrite(fout[v], "n,i_q1_15,q_q1_15\n");
    end
    repeat (8) @(posedge clk);
    rst_n = 1'b1;
    enable = 1'b1;
    wait ((out_count[0] == N_IN * 32) &&
          (out_count[1] == N_IN * 32) &&
          (out_count[2] == N_IN * 32) &&
          (out_count[3] == N_IN * 32));
    for (int v = 0; v < N_VARIANTS; v = v + 1) begin
      if (in_count[v] != N_IN) begin
        $fatal(1, "I%0d input count mismatch: %0d", v, in_count[v]);
      end
      $fclose(fout[v]);
    end
    $display("x32 interpolation I0/I1/I2/I3 valid-ready count/backpressure PASS");
    $finish;
  end

  always_comb begin
    out_ready = (cycle_count[2:0] != 3'b101);
    for (int v = 0; v < N_VARIANTS; v = v + 1) begin
      in_valid[v] = enable && (in_count[v] < N_IN);
      i_in[v] = (in_count[v] < N_IN) ? stim_i[in_count[v]] : '0;
      q_in[v] = (in_count[v] < N_IN) ? stim_q[in_count[v]] : '0;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      cycle_count <= 0;
      for (int v = 0; v < N_VARIANTS; v = v + 1) begin
        in_count[v] <= 0;
        out_count[v] <= 0;
      end
    end else begin
      cycle_count <= cycle_count + 1;
      if (cycle_count > MAX_CYCLES) $fatal(1, "variant test timeout");
      for (int v = 0; v < N_VARIANTS; v = v + 1) begin
        if (in_valid[v] && in_ready[v]) in_count[v] <= in_count[v] + 1;
        if (out_valid[v] && out_ready) begin
          if ((^i_out[v] === 1'bx) || (^q_out[v] === 1'bx)) begin
            $fatal(1, "I%0d produced X data", v);
          end
          if (out_count[v] >= N_IN * 32) $fatal(1, "I%0d overproduced", v);
          $fwrite(fout[v], "%0d,%0d,%0d\n", out_count[v], i_out[v], q_out[v]);
          out_count[v] <= out_count[v] + 1;
        end
      end
    end
  end
endmodule

`default_nettype wire
