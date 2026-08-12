`timescale 1ns/1ps
`default_nettype none

module tb_if_dsm_python_bittrue;
  localparam int W = 16;
  localparam int MAX_SAMPLES = 4096;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic in_valid = 1'b0;
  logic signed [W-1:0] i_in = '0;
  logic signed [W-1:0] q_in = '0;
  logic if_valid;
  logic signed [W-1:0] if_sample;
  logic rf_valid;
  logic rf_bit;
  logic signed [W-1:0] rf_signed;
  logic [1:0] if_phase;

  integer i_vector [0:MAX_SAMPLES-1];
  integer q_vector [0:MAX_SAMPLES-1];
  integer phase_vector [0:MAX_SAMPLES-1];
  integer if_vector [0:MAX_SAMPLES-1];
  integer rf_bit_vector [0:MAX_SAMPLES-1];
  integer rf_signed_vector [0:MAX_SAMPLES-1];
  integer sample_count = 0;
  integer if_count = 0;
  integer rf_count = 0;
  integer mismatch_count = 0;

  tx_bp_if_top #(
    .W(W),
    .ACC_W(28),
    .SATURATE(1'b1),
    .BP_ALGORITHM(1)
  ) dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
    .i_in(i_in), .q_in(q_in), .if_valid(if_valid),
    .if_sample(if_sample), .rf_valid(rf_valid), .rf_bit(rf_bit),
    .rf_signed(rf_signed), .if_phase(if_phase)
  );

  always #5 clk = ~clk;

  initial begin : load_vectors
    integer fd;
    integer status;
    integer index;
    integer registered_bit;
    integer quantizer_input;
    string header;

    fd = $fopen("bp_ef2_equivalence.csv", "r");
    if (fd == 0) $fatal(1, "Unable to open bp_ef2_equivalence.csv");
    status = $fgets(header, fd);
    while (!$feof(fd) && sample_count < MAX_SAMPLES) begin
      status = $fscanf(fd, "%d,%d,%d,%d,%d,%d,%d,%d,%d\n",
        index,
        i_vector[sample_count],
        q_vector[sample_count],
        phase_vector[sample_count],
        if_vector[sample_count],
        registered_bit,
        rf_bit_vector[sample_count],
        rf_signed_vector[sample_count],
        quantizer_input
      );
      if (status == 9) sample_count = sample_count + 1;
      else if (!$feof(fd)) $fatal(1, "Malformed vector row %0d", sample_count);
    end
    $fclose(fd);
    if (sample_count == 0) $fatal(1, "No vectors loaded");
  end

  initial begin : drive
    wait (sample_count > 0);
    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    for (int n = 0; n < sample_count; n++) begin
      @(negedge clk);
      in_valid = 1'b1;
      i_in = i_vector[n];
      q_in = q_vector[n];
    end
    @(negedge clk);
    in_valid = 1'b0;
    i_in = '0;
    q_in = '0;
    repeat (5) @(negedge clk);
    if (if_count != sample_count)
      $fatal(1, "IF count mismatch: actual=%0d expected=%0d", if_count, sample_count);
    if (rf_count != sample_count)
      $fatal(1, "RF count mismatch: actual=%0d expected=%0d", rf_count, sample_count);
    if (mismatch_count != 0)
      $fatal(1, "IF/DSM Python bit-true failed: mismatches=%0d", mismatch_count);
    $display("IF_DSM_PYTHON_BITTRUE_PASS samples=%0d", sample_count);
    $finish;
  end

  always @(negedge clk) begin : compare_outputs
    if (rst_n && if_valid) begin
      if ($signed(if_sample) !== if_vector[if_count]) begin
        $error("IF mismatch n=%0d actual=%0d expected=%0d",
          if_count, $signed(if_sample), if_vector[if_count]);
        mismatch_count = mismatch_count + 1;
      end
      if_count = if_count + 1;
    end
    if (rst_n && rf_valid) begin
      if (rf_bit !== rf_bit_vector[rf_count][0]) begin
        $error("RF bit mismatch n=%0d actual=%0d expected=%0d",
          rf_count, rf_bit, rf_bit_vector[rf_count]);
        mismatch_count = mismatch_count + 1;
      end
      if ($signed(rf_signed) !== rf_signed_vector[rf_count]) begin
        $error("RF signed mismatch n=%0d actual=%0d expected=%0d",
          rf_count, $signed(rf_signed), rf_signed_vector[rf_count]);
        mismatch_count = mismatch_count + 1;
      end
      if (if_phase !== phase_vector[rf_count][1:0]) begin
        $error("RF phase mismatch n=%0d actual=%0d expected=%0d",
          rf_count, if_phase, phase_vector[rf_count][1:0]);
        mismatch_count = mismatch_count + 1;
      end
      rf_count = rf_count + 1;
    end
  end
endmodule

`default_nettype wire
