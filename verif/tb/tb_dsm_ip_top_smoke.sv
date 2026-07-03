`timescale 1ns/1ps
`default_nettype none

module tb_dsm_ip_top_smoke;
  localparam int W = 16;
  localparam int RF_W = 16;
  localparam int PHASE_W = 24;
  localparam int N_SAMPLES = 64;

  logic clk;
  logic rst_n;
  logic in_valid;
  logic signed [W-1:0] i_in;
  logic signed [W-1:0] q_in;
  logic [PHASE_W-1:0] cfg_phase_inc;

  logic dsm_valid_fs4;
  logic i_bit_fs4;
  logic q_bit_fs4;
  logic signed [3:0] i_yout_fs4;
  logic signed [3:0] q_yout_fs4;
  logic rf_valid_fs4;
  logic rf_bit_fs4;
  logic signed [RF_W-1:0] rf_signed_fs4;
  logic [PHASE_W-1:0] phase_acc_fs4;

  logic dsm_valid_nco;
  logic i_bit_nco;
  logic q_bit_nco;
  logic signed [3:0] i_yout_nco;
  logic signed [3:0] q_yout_nco;
  logic rf_valid_nco;
  logic rf_bit_nco;
  logic signed [RF_W-1:0] rf_signed_nco;
  logic [PHASE_W-1:0] phase_acc_nco;

  dsm_ip_top #(
    .W(W),
    .RF_W(RF_W),
    .PHASE_W(PHASE_W),
    .ALGORITHM(2),
    .DUC_MODE(0)
  ) dut_fs4 (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .cfg_phase_inc(cfg_phase_inc),
    .i_in(i_in),
    .q_in(q_in),
    .dsm_valid(dsm_valid_fs4),
    .i_bit(i_bit_fs4),
    .q_bit(q_bit_fs4),
    .i_yout(i_yout_fs4),
    .q_yout(q_yout_fs4),
    .rf_valid(rf_valid_fs4),
    .rf_bit(rf_bit_fs4),
    .rf_signed(rf_signed_fs4),
    .phase_acc_dbg(phase_acc_fs4)
  );

  dsm_ip_top #(
    .W(W),
    .RF_W(RF_W),
    .PHASE_W(PHASE_W),
    .ALGORITHM(2),
    .DUC_MODE(1)
  ) dut_nco (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .cfg_phase_inc(cfg_phase_inc),
    .i_in(i_in),
    .q_in(q_in),
    .dsm_valid(dsm_valid_nco),
    .i_bit(i_bit_nco),
    .q_bit(q_bit_nco),
    .i_yout(i_yout_nco),
    .q_yout(q_yout_nco),
    .rf_valid(rf_valid_nco),
    .rf_bit(rf_bit_nco),
    .rf_signed(rf_signed_nco),
    .phase_acc_dbg(phase_acc_nco)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  int sample_count;
  int fs4_valid_count;
  int nco_valid_count;

  initial begin
    rst_n = 1'b0;
    in_valid = 1'b0;
    i_in = '0;
    q_in = '0;
    cfg_phase_inc = 24'h400000;
    sample_count = 0;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    for (sample_count = 0; sample_count < N_SAMPLES; sample_count++) begin
      @(posedge clk);
      in_valid <= 1'b1;
      i_in <= $signed(16'sd1024 + sample_count);
      q_in <= $signed(-16'sd512 + sample_count);
    end

    @(posedge clk);
    in_valid <= 1'b0;
    i_in <= '0;
    q_in <= '0;

    repeat (8) @(posedge clk);

    if (fs4_valid_count == 0) $fatal(1, "dsm_ip_top Fs/4 path produced no rf_valid");
    if (nco_valid_count == 0) $fatal(1, "dsm_ip_top NCO path produced no rf_valid");
    $display("DSM IP top smoke PASS: fs4_valid=%0d nco_valid=%0d", fs4_valid_count, nco_valid_count);
    $finish;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fs4_valid_count <= 0;
      nco_valid_count <= 0;
    end else begin
      if (rf_valid_fs4) fs4_valid_count <= fs4_valid_count + 1;
      if (rf_valid_nco) nco_valid_count <= nco_valid_count + 1;
    end
  end
endmodule

`default_nettype wire
