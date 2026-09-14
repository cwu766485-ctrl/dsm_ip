`timescale 1ns/1ps
`default_nettype none

module tb_ti32_lp1_fs4_dsm;
  localparam int W_IN = 16;
  localparam int LANES = 32;
  localparam int VECTORS = 128;
  logic clk = 1'b0, rst_n = 1'b0, enable = 1'b0;
  logic signed [LANES*W_IN-1:0] x_vec = '0;
  wire [LANES-1:0] y_vec;
  wire out_valid;
  integer x_mem [0:LANES*VECTORS-1];
  integer y_mem [0:LANES*VECTORS-1];
  integer fd, status, count, n, lane, errors, checked;
  integer x_value, y_value;
  string header;

  ti32_lp1_fs4_dsm #(.LANES(LANES), .W_IN(W_IN), .ACC_W(28)) dut (
    .clk(clk), .rst_n(rst_n), .enable(enable), .x_vec(x_vec),
    .y_vec(y_vec), .out_valid(out_valid)
  );
  always #5 clk = ~clk;

  initial begin
    count = 0; errors = 0; checked = 0;
    fd = $fopen("ti32_lp1_fs4_vectors.csv", "r");
    if (fd == 0) $fatal(1, "cannot open TI32 vectors");
    status = $fgets(header, fd);
    while (!$feof(fd) && count < LANES*VECTORS) begin
      status = $fscanf(fd, "%d,%d\n", x_value, y_value);
      if (status == 2) begin x_mem[count] = x_value; y_mem[count] = y_value; count = count + 1; end
    end
    $fclose(fd);
    if (count != LANES*VECTORS) $fatal(1, "vector count %0d", count);
    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    for (n = 0; n < VECTORS; n = n + 1) begin
      @(negedge clk);
      for (lane = 0; lane < LANES; lane = lane + 1) x_vec[lane*W_IN +: W_IN] = x_mem[n*LANES+lane];
      enable = 1'b1;
    end
    @(negedge clk); enable = 1'b0;
    repeat (2) @(negedge clk);
    if (checked != VECTORS) $fatal(1, "checked %0d vectors", checked);
    if (errors != 0) $fatal(1, "TI32 errors=%0d", errors);
    $display("TI32_LP1_FS4_DSM_PASS vectors=%0d samples=%0d", VECTORS, VECTORS*LANES);
    $finish;
  end

  always @(posedge clk) begin
    #1;
    if (rst_n && out_valid) begin
      for (lane = 0; lane < LANES; lane = lane + 1) begin
        if (y_vec[lane] !== (y_mem[checked*LANES+lane] != 0)) begin
          $error("TI32 mismatch vector=%0d lane=%0d", checked, lane); errors = errors + 1;
        end
      end
      checked = checked + 1;
    end
  end
endmodule

`default_nettype wire
