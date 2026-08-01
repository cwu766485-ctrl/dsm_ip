`timescale 1ns/1ps
`default_nettype none

module tb_interp_cic_polyphase_unit;
  localparam int N_IN = 32;
  localparam int N_OUT = N_IN * 8;
  localparam int MAX_CYCLES = 10000;

  logic clk;
  logic rst_n;
  logic enable;
  logic signed [15:0] in_data;
  logic in_valid;
  wire fir_ready;
  wire poly_ready;
  wire signed [15:0] fir_data;
  wire signed [15:0] poly_data;
  wire fir_valid;
  wire poly_valid;
  int unsigned in_count;
  int unsigned fir_count;
  int unsigned poly_count;
  int unsigned cycle_count;
  integer fir_file;
  integer poly_file;

  initial clk = 1'b0;
  always #5 clk = ~clk;

  dsm_interp_fir_fixed #(
    .W_IN(16), .W_OUT(16), .NTAPS(29), .INTERP(8), .COEFF_SET(2)
  ) u_fir (
    .clk(clk), .rst_n(rst_n), .enable(enable), .in_data(in_data),
    .in_valid(in_valid), .in_ready(fir_ready), .out_data(fir_data),
    .out_valid(fir_valid), .out_ready(1'b1)
  );

  dsm_interp_fir_polyphase #(
    .W_IN(16), .W_OUT(16), .NTAPS(29), .INTERP(8)
  ) u_poly (
    .clk(clk), .rst_n(rst_n), .enable(enable), .in_data(in_data),
    .in_valid(in_valid), .in_ready(poly_ready), .out_data(poly_data),
    .out_valid(poly_valid), .out_ready(1'b1)
  );

  initial begin
    rst_n = 1'b0;
    enable = 1'b0;
    fir_file = $fopen("cic_equiv_fir.csv", "w");
    poly_file = $fopen("cic_equiv_poly.csv", "w");
    if ((fir_file == 0) || (poly_file == 0)) $fatal(1, "cannot open unit outputs");
    $fwrite(fir_file, "n,data\n");
    $fwrite(poly_file, "n,data\n");
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    enable = 1'b1;
    wait ((fir_count == N_OUT) && (poly_count == N_OUT));
    if (in_count != N_IN) $fatal(1, "input count mismatch");
    $fclose(fir_file);
    $fclose(poly_file);
    $display("CIC-equivalent FIR/polyphase unit streams written");
    $finish;
  end

  always_comb begin
    in_valid = enable && (in_count < N_IN) && fir_ready && poly_ready;
    in_data = signed'(in_count * 97 - 1400);
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      in_count <= 0;
      fir_count <= 0;
      poly_count <= 0;
      cycle_count <= 0;
    end else begin
      cycle_count <= cycle_count + 1;
      if (cycle_count > MAX_CYCLES) $fatal(1, "unit timeout");
      if (in_valid && fir_ready && poly_ready) in_count <= in_count + 1;
      if (fir_valid) begin
        $fwrite(fir_file, "%0d,%0d\n", fir_count, fir_data);
        fir_count <= fir_count + 1;
      end
      if (poly_valid) begin
        $fwrite(poly_file, "%0d,%0d\n", poly_count, poly_data);
        poly_count <= poly_count + 1;
      end
    end
  end
endmodule

`default_nettype wire
