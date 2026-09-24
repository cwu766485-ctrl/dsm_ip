`timescale 1ns/1ps
`default_nettype none

module tb_dsm_core_bp_ef4_bittrue;
  localparam int W = 16;
  localparam int ACC_W = 28;
  localparam int MAX_SAMPLES = 4096;
  logic clk = 1'b0, rst_n = 1'b0, enable = 1'b0;
  logic signed [W-1:0] x_in = '0;
  wire y_bit;
  wire signed [W-1:0] y_signed;
  wire signed [ACC_W-1:0] v_state;
  integer x_vector [0:MAX_SAMPLES-1];
  integer bit_vector [0:MAX_SAMPLES-1];
  integer signed_vector [0:MAX_SAMPLES-1];
  integer state_vector [0:MAX_SAMPLES-1];
  integer sample_count = 0, checked_count = 0, mismatch_count = 0;

  dsm_core_bp_ef4 #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b1)) dut (
    .clk(clk), .rst_n(rst_n), .enable(enable), .x_in(x_in), .y_bit(y_bit),
    .y_signed(y_signed), .v_state(v_state)
  );
  always #5 clk = ~clk;

  initial begin : load_vectors
    integer fd, status, index;
    string header;
    fd = $fopen("bp_ef4_equivalence.csv", "r");
    if (fd == 0) $fatal(1, "cannot open bp_ef4_equivalence.csv");
    status = $fgets(header, fd);
    while (!$feof(fd) && sample_count < MAX_SAMPLES) begin
      status = $fscanf(fd, "%d,%d,%d,%d,%d\n", index, x_vector[sample_count],
                       bit_vector[sample_count], signed_vector[sample_count], state_vector[sample_count]);
      if (status == 5) sample_count = sample_count + 1;
      else if (!$feof(fd)) $fatal(1, "malformed vector row %0d", sample_count);
    end
    $fclose(fd);
    if (sample_count == 0) $fatal(1, "no BP EFDSM4 vectors loaded");
  end

  initial begin
    wait (sample_count > 0);
    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    for (int n = 0; n < sample_count; n++) begin
      @(negedge clk); enable = 1'b1; x_in = x_vector[n];
      @(posedge clk); #1;
      if (y_bit !== bit_vector[n][0] || $signed(y_signed) !== signed_vector[n] ||
          $signed(v_state) !== state_vector[n]) begin
        $error("BP EFDSM4 mismatch n=%0d", n); mismatch_count = mismatch_count + 1;
      end
      checked_count = checked_count + 1;
    end
    @(negedge clk); enable = 1'b0;
    if (checked_count != sample_count || mismatch_count != 0)
      $fatal(1, "BP EFDSM4 mismatches=%0d", mismatch_count);
    $display("BP_EFDSM4_BLOCK_BITTRUE_PASS samples=%0d", sample_count);
    $finish;
  end
endmodule

`default_nettype wire
