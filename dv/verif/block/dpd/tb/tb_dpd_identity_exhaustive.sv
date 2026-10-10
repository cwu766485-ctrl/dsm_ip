`timescale 1ns/1ps

// Exhaust every signed 16-bit value on each component under the frozen
// DPD1/identity coefficient contract. The other component is held at an
// extreme value, and a third diagonal sweep tests simultaneous changes.
module tb_dpd_identity_exhaustive;
  localparam int N = 3 * 65536;
  logic clk = 0;
  always #5 clk = ~clk;
  logic rst_n = 0;
  logic in_valid = 0;
  logic signed [15:0] i_in = 0, q_in = 0;
  wire in_ready, out_valid;
  wire signed [15:0] i_out, q_out;
  logic out_ready = 1;
  wire [31:0] sample_count, saturation_count;
  logic signed [15:0] expected_i [0:N-1];
  logic signed [15:0] expected_q [0:N-1];
  int write_index = 0, read_index = 0;
  int invalid_sat_slots = 0;

  dpd_memory_poly #(.W(16), .COEFF_W(16), .COEFF_FRAC(14),
                    .MAX_TAPS(1), .USE_EXTERNAL_TAPS(0)) dut (
    .clk(clk), .rst_n(rst_n), .active_taps(3'd1),
    .c1_re(16'sd16384), .c1_im(16'sd0),
    .c3_re(16'sd0), .c3_im(16'sd0),
    .c5_re(16'sd0), .c5_im(16'sd0),
    .i_in(i_in), .q_in(q_in), .i_tap_vec(16'sd0), .q_tap_vec(16'sd0),
    .in_valid(in_valid), .in_ready(in_ready),
    .i_out(i_out), .q_out(q_out), .out_valid(out_valid),
    .out_ready(out_ready), .sample_count(sample_count),
    .saturation_count(saturation_count)
  );

  task automatic tick(input bit send,
                      input logic signed [15:0] i_value,
                      input logic signed [15:0] q_value);
    @(negedge clk);
    in_valid = send;
    i_in = i_value;
    q_in = q_value;
    @(posedge clk);
    if (out_valid) begin
      if (read_index >= write_index)
        $fatal(1, "Output without accepted input at %0d", read_index);
      if (i_out !== expected_i[read_index] ||
          q_out !== expected_q[read_index] || dut.sat_i || dut.sat_q)
        $fatal(1, "Identity mismatch at %0d: got (%0d,%0d) expected (%0d,%0d) sat=%b%b",
               read_index, i_out, q_out, expected_i[read_index],
               expected_q[read_index], dut.sat_i, dut.sat_q);
      read_index++;
    end else if (dut.sat_i || dut.sat_q) begin
      invalid_sat_slots++;
    end
    if (send) begin
      if (!in_ready) $fatal(1, "Unexpected input backpressure");
      expected_i[write_index] = i_value;
      expected_q[write_index] = q_value;
      write_index++;
    end
  endtask

  initial begin
    repeat (4) @(negedge clk);
    rst_n = 1;
    for (int pass = 0; pass < 3; pass++) begin
      for (int value = 0; value < 65536; value++) begin
        if (value % 17 == 0) tick(0, 16'sd0, 16'sd0);
        case (pass)
          0: tick(1, value[15:0], 16'sh8000);
          1: tick(1, 16'sd32767, value[15:0]);
          2: tick(1, value[15:0], ~value[15:0]);
        endcase
      end
    end
    repeat (16) tick(0, 16'sd0, 16'sd0);
    @(negedge clk);
    if (write_index != N || read_index != N || sample_count != N ||
        saturation_count != 0)
      $fatal(1, "Counts: accepted=%0d output=%0d samples=%0d saturations=%0d",
             write_index, read_index, sample_count, saturation_count);
    $display("DPD_IDENTITY_EXHAUSTIVE_PASS accepted=%0d output=%0d invalid_sat_slots=%0d min=-32768 max=32767",
             write_index, read_index, invalid_sat_slots);
    $finish;
  end
endmodule
