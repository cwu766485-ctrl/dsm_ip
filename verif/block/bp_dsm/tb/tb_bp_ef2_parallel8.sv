`timescale 1ns/1ps
`default_nettype none

module tb_bp_ef2_parallel8;
  localparam int W = 16;
  localparam int ACC_W = 28;
  localparam int VECTORS = 32;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic enable = 1'b0;
  logic [8*W-1:0] x_vec = '0;
  wire [7:0] y_vec;
  wire signed [8*W-1:0] y_signed_vec;
  wire out_valid;
  wire signed [ACC_W-1:0] v_state;

  integer x_mem [0:8*VECTORS-1];
  integer y_mem [0:8*VECTORS-1];
  integer ys_mem [0:8*VECTORS-1];
  integer state_mem [0:8*VECTORS-1];
  integer sample_count;
  integer checked_count;
  integer mismatch_count;
  integer fd;
  integer status;
  integer n;
  integer lane;
  integer x_value;
  integer y_value;
  integer ys_value;
  integer state_value;
  string header;

  bp_ef2_parallel8 #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b1)) dut (
    .clk(clk), .rst_n(rst_n), .enable(enable), .x_vec(x_vec),
    .y_vec(y_vec), .y_signed_vec(y_signed_vec), .out_valid(out_valid),
    .v_state(v_state)
  );

  always #5 clk = ~clk;

  initial begin
    sample_count = 0;
    checked_count = 0;
    mismatch_count = 0;
    fd = $fopen("bp_ef2_parallel8_vectors.csv", "r");
    if (fd == 0) $fatal(1, "cannot open bp_ef2_parallel8_vectors.csv");
    status = $fgets(header, fd);
    while (!$feof(fd) && sample_count < 8*VECTORS) begin
      status = $fscanf(fd, "%d,%d,%d,%d\n", x_value, y_value, ys_value, state_value);
      if (status == 4) begin
        x_mem[sample_count] = x_value;
        y_mem[sample_count] = y_value;
        ys_mem[sample_count] = ys_value;
        state_mem[sample_count] = state_value;
        sample_count = sample_count + 1;
      end else if (!$feof(fd)) begin
        $fatal(1, "malformed vector row %0d", sample_count);
      end
    end
    $fclose(fd);
    if (sample_count != 8*VECTORS)
      $fatal(1, "expected %0d samples, got %0d", 8*VECTORS, sample_count);
  end

  initial begin
    wait (sample_count == 8*VECTORS);
    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    for (n = 0; n < VECTORS; n = n + 1) begin
      @(negedge clk);
      for (lane = 0; lane < 8; lane = lane + 1)
        x_vec[lane*W +: W] = x_mem[n*8 + lane];
      #1 enable = 1'b1;
    end
    @(negedge clk);
    #1 enable = 1'b0;
    repeat (2) @(negedge clk);
    if (checked_count != VECTORS)
      $fatal(1, "checked vectors mismatch: got=%0d expected=%0d", checked_count, VECTORS);
    if (mismatch_count != 0)
      $fatal(1, "parallel8 mismatches=%0d", mismatch_count);
    $display("BP_EF2_PARALLEL8_BITTRUE_PASS vectors=%0d samples=%0d", VECTORS, sample_count);
    $finish;
  end

  always @(negedge clk) begin
    if (rst_n && enable && out_valid && checked_count < VECTORS) begin
      for (lane = 0; lane < 8; lane = lane + 1) begin
        if (y_vec[lane] !== (y_mem[checked_count*8 + lane] != 0)) begin
          $error("bit mismatch vector=%0d lane=%0d actual=%0d expected=%0d",
            checked_count, lane, y_vec[lane], y_mem[checked_count*8 + lane]);
          mismatch_count = mismatch_count + 1;
        end
        if ($signed(y_signed_vec[lane*W +: W]) !== ys_mem[checked_count*8 + lane]) begin
          $error("signed mismatch vector=%0d lane=%0d actual=%0d expected=%0d",
            checked_count, lane, $signed(y_signed_vec[lane*W +: W]),
            ys_mem[checked_count*8 + lane]);
          mismatch_count = mismatch_count + 1;
        end
      end
      if ($signed(v_state) !== state_mem[checked_count*8 + 7]) begin
        $error("state mismatch vector=%0d actual=%0d expected=%0d",
          checked_count, $signed(v_state), state_mem[checked_count*8 + 7]);
        mismatch_count = mismatch_count + 1;
      end
      checked_count = checked_count + 1;
    end
  end
endmodule

`default_nettype wire
