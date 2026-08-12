`timescale 1ns/1ps
`default_nettype none

// Uses a Python-generated golden sequence but inserts reproducible enable
// bubbles. A disabled cycle must not advance either DSM state or vector index.
module tb_dsm_core_bp_ef2_random;
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
  integer lfsr = 32'h0bad_cafe;
  integer timeout_count = 0;

  dsm_core_bp_ef2 #(.W_IN(W), .ACC_W(ACC_W), .SATURATE(1'b1)) dut (
    .clk(clk), .rst_n(rst_n), .enable(enable), .x_in(x_in),
    .y_bit(y_bit), .y_signed(y_signed), .v_state(v_state)
  );
  always #5 clk = ~clk;

  function automatic integer next_lfsr(input integer value);
    begin
      next_lfsr = (value << 1) ^ (((value >> 31) ^ (value >> 21) ^
                                    (value >> 1) ^ value) & 1);
    end
  endfunction

  initial begin : load_vectors
    integer fd, status, index, unused_i, unused_q, unused_phase, unused_registered_bit;
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
    if (sample_count == 0) $fatal(1, "no random BP EFDSM2 vectors loaded");
  end

  initial begin
    wait (sample_count > 0);
    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    while (checked_count < sample_count) begin
      @(negedge clk);
      lfsr = next_lfsr(lfsr);
      if (lfsr[0]) begin
        enable = 1'b1;
        x_in = if_vector[checked_count];
        @(posedge clk);
        #1;
        if (y_bit !== bit_vector[checked_count][0] ||
            $signed(y_signed) !== signed_vector[checked_count] ||
            $signed(v_state) !== quantizer_vector[checked_count]) begin
          $fatal(1, "random BP EFDSM2 mismatch n=%0d", checked_count);
        end
        checked_count = checked_count + 1;
      end else begin
        enable = 1'b0;
        x_in = '0;
      end
      timeout_count = timeout_count + 1;
      if (timeout_count > sample_count * 8) $fatal(1, "random BP EFDSM2 timeout");
    end
    @(negedge clk);
    enable = 1'b0;
    $display("BP_EFDSM2_RANDOM_PROTOCOL_PASS samples=%0d", sample_count);
    $finish;
  end
endmodule

`default_nettype wire
