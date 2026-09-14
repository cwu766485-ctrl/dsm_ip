`timescale 1ns/1ps
`default_nettype none

module tb_ti64_lp1_fs4_gt_tx;
  localparam int W_IN = 16;
  localparam int LANES = 64;
  localparam int VECTORS = 128;
  logic clk = 1'b0, rst_n = 1'b0, in_valid = 1'b0, gt_ready = 1'b0;
  logic signed [LANES*W_IN-1:0] in_x_vec = '0;
  wire in_ready, gt_valid;
  wire [LANES-1:0] gt_data;
  integer x_mem [0:LANES*VECTORS-1];
  integer y_mem [0:LANES*VECTORS-1];
  integer fd, status, count, n, lane, errors, accepted;
  integer x_value, y_value;
  string header;

  ti64_lp1_fs4_gt_tx #(.W_IN(W_IN), .ACC_W(28)) dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
    .in_x_vec(in_x_vec), .gt_valid(gt_valid), .gt_ready(gt_ready),
    .gt_data(gt_data)
  );
  always #5 clk = ~clk;

  initial begin
    count = 0; errors = 0; accepted = 0;
    fd = $fopen("ti64_lp1_fs4_vectors.csv", "r");
    if (fd == 0) $fatal(1, "cannot open TI64 vectors");
    status = $fgets(header, fd);
    while (!$feof(fd) && count < LANES*VECTORS) begin
      status = $fscanf(fd, "%d,%d\n", x_value, y_value);
      if (status == 2) begin
        x_mem[count] = x_value;
        y_mem[count] = y_value;
        count = count + 1;
      end
    end
    $fclose(fd);
    if (count != LANES*VECTORS) $fatal(1, "vector count %0d", count);

    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    gt_ready = 1'b1;
    for (n = 0; n < VECTORS; n = n + 1) begin
      @(negedge clk);
      if (!in_ready) $fatal(1, "GT boundary backpressured continuous word %0d", n);
      for (lane = 0; lane < LANES; lane = lane + 1)
        in_x_vec[lane*W_IN +: W_IN] = x_mem[n*LANES+lane];
      in_valid = 1'b1;
    end
    @(negedge clk);
    in_valid = 1'b0;
    repeat (4) @(negedge clk);
    if (accepted != VECTORS) $fatal(1, "accepted %0d words", accepted);
    if (errors != 0) $fatal(1, "TI64 GT errors=%0d", errors);
    $display("TI64_LP1_FS4_GT_TX_PASS vectors=%0d samples=%0d", VECTORS, VECTORS*LANES);
    $finish;
  end

  always @(posedge clk) begin
    if (rst_n && gt_valid && gt_ready) begin
      for (lane = 0; lane < LANES; lane = lane + 1) begin
        if (gt_data[lane] !== (y_mem[accepted*LANES+lane] != 0)) begin
          $error("TI64 GT mismatch word=%0d lane=%0d", accepted, lane);
          errors = errors + 1;
        end
      end
      accepted = accepted + 1;
    end
  end
endmodule

`default_nettype wire
