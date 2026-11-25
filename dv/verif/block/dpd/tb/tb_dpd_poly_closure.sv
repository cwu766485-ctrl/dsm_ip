`timescale 1ns/1ps
`default_nettype none

module tb_dpd_poly_closure #(
`ifdef DPD_POLY_ORDER
  parameter int POLY_ORDER = `DPD_POLY_ORDER
`else
  parameter int POLY_ORDER = 7
`endif
);
  localparam int MAX_VECTORS = 128;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic enable = 1'b1;
  logic signed [15:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im, c7_re, c7_im;
  logic signed [15:0] i_in, q_in;
  logic in_valid = 1'b0;
  wire in_ready;
  wire signed [15:0] i_out, q_out;
  wire out_valid;
  logic out_ready = 1'b1;
  wire [31:0] sample_count, saturation_count;

  integer in_i [0:MAX_VECTORS-1], in_q [0:MAX_VECTORS-1];
  integer in_enable [0:MAX_VECTORS-1];
  integer coeff [0:MAX_VECTORS-1][0:7];
  integer exp_i [0:MAX_VECTORS-1], exp_q [0:MAX_VECTORS-1];
  integer vector_count, expected_saturations;
  integer sent = 0, received = 0, drive_index = 0, cycle_count = 0;
  integer output_stall_cycles = 0, input_stall_cycles = 0;
  integer read_status;
  string vector_file;
  string line;
  logic held_valid = 1'b0;
  logic signed [15:0] held_i, held_q;

  always #5 clk = ~clk;

  dpd_poly #(.W(16), .COEFF_W(16), .COEFF_FRAC(14), .POLY_ORDER(POLY_ORDER)) dut (
    .clk(clk), .rst_n(rst_n), .enable(enable),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .c7_re(c7_re), .c7_im(c7_im),
    .i_in(i_in), .q_in(q_in), .in_valid(in_valid), .in_ready(in_ready),
    .i_out(i_out), .q_out(q_out), .out_valid(out_valid), .out_ready(out_ready),
    .sample_count(sample_count), .saturation_count(saturation_count)
  );

  always @(negedge clk) begin
    if (rst_n)
      out_ready = ((cycle_count % 23) >= 5);
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      cycle_count = 0;
      held_valid = 1'b0;
    end else begin
      cycle_count = cycle_count + 1;
      if (cycle_count > 10000)
        $fatal(1, "dpd_poly timeout order=%0d", POLY_ORDER);
      if (in_valid && !in_ready)
        input_stall_cycles = input_stall_cycles + 1;
      if (out_valid && !out_ready) begin
        output_stall_cycles = output_stall_cycles + 1;
        if (held_valid && (i_out !== held_i || q_out !== held_q))
          $fatal(1, "dpd_poly output changed during stall order=%0d", POLY_ORDER);
        held_i = i_out;
        held_q = q_out;
        held_valid = 1'b1;
      end else if (out_valid && out_ready) begin
        if (received >= sent)
          $fatal(1, "dpd_poly output without accepted input order=%0d", POLY_ORDER);
        if (i_out !== exp_i[received] || q_out !== exp_q[received])
          $fatal(1, "dpd_poly bittrue mismatch order=%0d n=%0d got=(%0d,%0d) expected=(%0d,%0d)",
                 POLY_ORDER, received, i_out, q_out, exp_i[received], exp_q[received]);
        received = received + 1;
        held_valid = 1'b0;
      end else begin
        held_valid = 1'b0;
      end

      if (in_valid && in_ready) begin
        sent = sent + 1;
      end
    end
  end

  initial begin : p_run
    integer fd, code, row;
    integer file_i, file_q, file_enable;
    integer file_c1r, file_c1i, file_c3r, file_c3i;
    integer file_c5r, file_c5i, file_c7r, file_c7i;
    integer file_yi, file_yq;
    if (!$value$plusargs("VECTOR_FILE=%s", vector_file))
      $fatal(1, "VECTOR_FILE plusarg is required");
    if (!$value$plusargs("VECTOR_COUNT=%d", vector_count))
      $fatal(1, "VECTOR_COUNT plusarg is required");
    if (!$value$plusargs("EXPECTED_SATURATIONS=%d", expected_saturations))
      $fatal(1, "EXPECTED_SATURATIONS plusarg is required");
    if (vector_count <= 0 || vector_count > MAX_VECTORS)
      $fatal(1, "invalid vector count %0d", vector_count);
    fd = $fopen(vector_file, "r");
    if (fd == 0) $fatal(1, "cannot open vector file %s", vector_file);
    for (row = 0; row < vector_count; row = row + 1) begin
      code = $fscanf(fd, "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n",
        file_i, file_q, file_enable, file_c1r, file_c1i, file_c3r, file_c3i,
        file_c5r, file_c5i, file_c7r, file_c7i, file_yi, file_yq);
      if (code != 13) $fatal(1, "malformed vector row %0d code=%0d", row, code);
      in_i[row] = file_i; in_q[row] = file_q; in_enable[row] = file_enable;
      coeff[row][0] = file_c1r; coeff[row][1] = file_c1i;
      coeff[row][2] = file_c3r; coeff[row][3] = file_c3i;
      coeff[row][4] = file_c5r; coeff[row][5] = file_c5i;
      coeff[row][6] = file_c7r; coeff[row][7] = file_c7i;
      exp_i[row] = file_yi; exp_q[row] = file_yq;
    end
    $fclose(fd);

    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    while (drive_index < vector_count) begin
      @(negedge clk);
      in_valid = 1'b1;
      enable = in_enable[drive_index][0];
      i_in = in_i[drive_index][15:0]; q_in = in_q[drive_index][15:0];
      c1_re = coeff[drive_index][0][15:0]; c1_im = coeff[drive_index][1][15:0];
      c3_re = coeff[drive_index][2][15:0]; c3_im = coeff[drive_index][3][15:0];
      c5_re = coeff[drive_index][4][15:0]; c5_im = coeff[drive_index][5][15:0];
      c7_re = coeff[drive_index][6][15:0]; c7_im = coeff[drive_index][7][15:0];
      do @(posedge clk); while (in_ready !== 1'b1);
      drive_index = drive_index + 1;
    end
    @(negedge clk);
    in_valid = 1'b0;
    enable = 1'b0;
    out_ready = 1'b1;
    wait (received == vector_count);
    @(negedge clk);
    if (sent != vector_count || sample_count != vector_count)
      $fatal(1, "dpd_poly count mismatch sent=%0d samples=%0d expected=%0d",
             sent, sample_count, vector_count);
    if (saturation_count != expected_saturations)
      $fatal(1, "dpd_poly saturation count=%0d expected=%0d",
             saturation_count, expected_saturations);
    if (output_stall_cycles == 0 || input_stall_cycles == 0)
      $fatal(1, "dpd_poly did not cover both sides of pipeline backpressure");
    $display("DPD_POLY_CLOSURE_PASS order=%0d vectors=%0d saturations=%0d input_stalls=%0d output_stalls=%0d",
             POLY_ORDER, vector_count, saturation_count,
             input_stall_cycles, output_stall_cycles);
    $finish;
  end
endmodule

`default_nettype wire
