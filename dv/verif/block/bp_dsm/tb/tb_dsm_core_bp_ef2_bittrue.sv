`timescale 1ns/1ps
`default_nettype none

module tb_dsm_core_bp_ef2_bittrue;
  localparam int W = 16;
  localparam int ACC_W = 28;
  localparam int MAX_SAMPLES = 4096;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic enable = 1'b0;
  logic signed [W-1:0] x_in = '0;
  wire y_bit;
  wire signed [W-1:0] y_signed;
  wire signed [ACC_W-1:0] v_state;

  integer if_vector [0:MAX_SAMPLES-1];
  integer bit_vector [0:MAX_SAMPLES-1];
  integer signed_vector [0:MAX_SAMPLES-1];
  integer quantizer_vector [0:MAX_SAMPLES-1];
  integer sample_count = 0;
  integer checked_count = 0;
  integer mismatch_count = 0;

  dsm_core_bp_ef2 #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b1)) dut (
    .clk(clk), .rst_n(rst_n), .enable(enable), .x_in(x_in),
    .y_bit(y_bit), .y_signed(y_signed), .v_state(v_state)
  );

  always #5 clk = ~clk;

  initial begin : load_vectors
    integer fd;
    integer status;
    integer index;
    integer unused_i;
    integer unused_q;
    integer unused_phase;
    integer unused_registered_bit;
    string header;
    fd = $fopen("bp_ef2_equivalence.csv", "r");
    if (fd == 0) $fatal(1, "cannot open bp_ef2_equivalence.csv");
    status = $fgets(header, fd);
    while (!$feof(fd) && sample_count < MAX_SAMPLES) begin
      status = $fscanf(fd, "%d,%d,%d,%d,%d,%d,%d,%d,%d\n",
        index, unused_i, unused_q, unused_phase, if_vector[sample_count],
        unused_registered_bit, bit_vector[sample_count], signed_vector[sample_count],
        quantizer_vector[sample_count]);
      if (status == 9) sample_count = sample_count + 1;
      else if (!$feof(fd)) $fatal(1, "malformed vector row %0d", sample_count);
    end
    $fclose(fd);
    if (sample_count == 0) $fatal(1, "no BP EFDSM2 vectors loaded");
  end

  initial begin : drive_and_finish
    wait (sample_count > 0);
    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    for (int n = 0; n < sample_count; n++) begin
      @(negedge clk);
      #1;
      enable = 1'b1;
      x_in = if_vector[n];
    end
    @(negedge clk);
    #1;
    enable = 1'b0;
    x_in = '0;
    repeat (2) @(negedge clk);
    if (checked_count != sample_count)
      $fatal(1, "checked count mismatch: got=%0d expected=%0d", checked_count, sample_count);
    if (mismatch_count != 0) $fatal(1, "BP EFDSM2 mismatches=%0d", mismatch_count);
    $display("BP_EFDSM2_BLOCK_BITTRUE_PASS samples=%0d", sample_count);
    $finish;
  end

  always @(negedge clk) begin
    if (rst_n && enable && (checked_count < sample_count)) begin
      if (y_bit !== bit_vector[checked_count][0]) begin
        $error("bit mismatch n=%0d actual=%0d expected=%0d", checked_count,
          y_bit, bit_vector[checked_count]);
        mismatch_count = mismatch_count + 1;
      end
      if ($signed(y_signed) !== signed_vector[checked_count]) begin
        $error("signed mismatch n=%0d actual=%0d expected=%0d", checked_count,
          $signed(y_signed), signed_vector[checked_count]);
        mismatch_count = mismatch_count + 1;
      end
      if ($signed(v_state) !== quantizer_vector[checked_count]) begin
        $error("state mismatch n=%0d actual=%0d expected=%0d", checked_count,
          $signed(v_state), quantizer_vector[checked_count]);
        mismatch_count = mismatch_count + 1;
      end
      checked_count = checked_count + 1;
    end
  end
endmodule

`default_nettype wire
