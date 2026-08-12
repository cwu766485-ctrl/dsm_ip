`timescale 1ns/1ps
`default_nettype none

// DPD bypass is an exact subsystem oracle: it verifies the ten-stage DPD
// alignment and the connected interpolation data/ready path without mixing in
// a second DPD arithmetic oracle already covered at block level.
module tb_tx_frontend_python_bittrue;
  localparam int W = 16;
  localparam int MAX_IN = 128;
  localparam int MAX_OUT = 512;
  localparam int MAX_CYCLES = 120000;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic [1:0] dpd_mode = 2'd0;
  logic signed [W-1:0] i_in = '0;
  logic signed [W-1:0] q_in = '0;
  logic in_valid = 1'b0;
  wire in_ready;
  wire signed [W-1:0] dpd_i;
  wire signed [W-1:0] dpd_q;
  wire dpd_valid;
  wire dpd_ready;
  wire signed [W-1:0] i_out;
  wire signed [W-1:0] q_out;
  wire out_valid;
  logic out_ready = 1'b0;

  integer input_i [0:MAX_IN-1];
  integer input_q [0:MAX_IN-1];
  integer expected_i [0:MAX_OUT-1];
  integer expected_q [0:MAX_OUT-1];
  integer n_input = 0;
  integer n_output = 0;
  integer sent = 0;
  integer received = 0;
  integer cycle_count = 0;
  integer stall_count = 0;
  integer lfsr = 32'h4a11_ce55;

  function automatic integer next_lfsr(input integer value);
    begin
      next_lfsr = (value << 1) ^ (((value >> 31) ^ (value >> 21) ^
                                    (value >> 1) ^ value) & 1);
    end
  endfunction

  dpd_frontend u_dpd (
    .clk(clk), .rst_n(rst_n), .mode(dpd_mode),
    .c1_re(16'sd16384), .c1_im('0), .c3_re('0), .c3_im('0),
    .c5_re('0), .c5_im('0), .c7_re('0), .c7_im('0),
    .mp_active_taps(3'd4), .mp_coeff_we(1'b0), .mp_commit(1'b0),
    .mp_coeff_tap('0), .mp_coeff_order('0), .mp_coeff_re('0), .mp_coeff_im('0),
    .mp_coeff_rdata_re(), .mp_coeff_rdata_im(), .mp_active_bank(),
    .lut_we(1'b0), .lut_commit(1'b0), .lut_waddr('0),
    .lut_wgain_re('0), .lut_wgain_im('0), .lut_raddr('0),
    .lut_rgain_re(), .lut_rgain_im(), .lut_active_bank(),
    .safety_enable(1'b1), .safety_clear(1'b0), .safety_fault(),
    .mp_commit_rejected(), .lut_commit_rejected(),
    .i_in(i_in), .q_in(q_in), .in_valid(in_valid), .in_ready(in_ready),
    .i_out(dpd_i), .q_out(dpd_q), .out_valid(dpd_valid), .out_ready(dpd_ready),
    .effective_mode_out(), .busy(), .sample_count(), .saturation_count()
  );

  dsm_interp_frontend #(.W_IN(W), .W_OUT(W), .INTERP_MODE(1)) u_interp (
    .clk(clk), .rst_n(rst_n), .enable(1'b1),
    .i_in(dpd_i), .q_in(dpd_q), .in_valid(dpd_valid), .in_ready(dpd_ready),
    .i_out(i_out), .q_out(q_out), .out_valid(out_valid), .out_ready(out_ready)
  );

  always #5 clk = ~clk;

  initial begin : load_vectors
    integer fd;
    integer status;
    integer index;
    integer i_value;
    integer q_value;
    string kind;
    string header;
    fd = $fopen("tx_frontend_equivalence.csv", "r");
    if (fd == 0) $fatal(1, "Unable to open tx_frontend_equivalence.csv");
    status = $fgets(header, fd);
    while (!$feof(fd)) begin
      status = $fscanf(fd, "%s %d %d %d\n", kind, index, i_value, q_value);
      if (status == 4) begin
        if (kind == "IN") begin
          input_i[n_input] = i_value;
          input_q[n_input] = q_value;
          n_input = n_input + 1;
        end else if (kind == "OUT") begin
          expected_i[n_output] = i_value;
          expected_q[n_output] = q_value;
          n_output = n_output + 1;
        end else begin
          $fatal(1, "Unknown vector kind %s", kind);
        end
      end else if (!$feof(fd)) begin
        $fatal(1, "Malformed vector row");
      end
    end
    $fclose(fd);
    if (n_input == 0 || n_output == 0) $fatal(1, "No subsystem vectors loaded");
  end

  always @(posedge clk) begin
    if (rst_n) begin
      cycle_count <= cycle_count + 1;
      if (cycle_count > MAX_CYCLES) $fatal(1, "TX frontend timeout");
      if (in_valid && in_ready) sent <= sent + 1;
      if (out_valid && out_ready) begin
        if ($signed(i_out) !== expected_i[received] ||
            $signed(q_out) !== expected_q[received]) begin
          $fatal(1, "TX frontend mismatch n=%0d got=(%0d,%0d) expected=(%0d,%0d)",
                 received, $signed(i_out), $signed(q_out),
                 expected_i[received], expected_q[received]);
        end
        received <= received + 1;
      end
      if (out_valid && !out_ready) stall_count <= stall_count + 1;
    end
  end

  initial begin : drive
    wait (n_input > 0);
    repeat (5) @(negedge clk);
    rst_n = 1'b1;
    while (received < n_output) begin
      @(negedge clk);
      lfsr = next_lfsr(lfsr);
      out_ready = lfsr[1] | lfsr[4];
      in_valid = (sent < n_input) && lfsr[0];
      i_in = input_i[sent];
      q_in = input_q[sent];
    end
    @(negedge clk);
    in_valid = 1'b0;
    out_ready = 1'b1;
    repeat (3) @(posedge clk);
    if (sent != n_input || received != n_output)
      $fatal(1, "TX frontend count mismatch sent=%0d/%0d received=%0d/%0d",
             sent, n_input, received, n_output);
    if (stall_count == 0) $fatal(1, "TX frontend did not exercise backpressure");
    $display("TX_FRONTEND_PYTHON_BITTRUE_PASS inputs=%0d outputs=%0d stalls=%0d",
             n_input, n_output, stall_count);
    $finish;
  end
endmodule

`default_nettype wire
