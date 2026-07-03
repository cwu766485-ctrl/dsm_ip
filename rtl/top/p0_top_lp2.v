`timescale 1ns/1ps
`default_nettype none

// P0 wrapper: LPDSM2 (2nd-order single-loop, sign-domain)
module p0_top_lp2 #(
  parameter integer W = 16,
  parameter integer ADDR_W = 16,
  parameter integer DEPTH = 65536,
  parameter integer ACC_W = 40,
  parameter integer IN_SHIFT = 0,
  parameter         DSM_SATURATE = 1'b1,
  parameter integer PHASE_W = 24,
  parameter         USE_FILE_ROM = 1'b1,
  parameter         MEM_I_FILE = "rom_i.mem",
  parameter         MEM_Q_FILE = "rom_q.mem"
) (
  input  wire                clk,
  input  wire                rst_n,
  input  wire                enable,
  input  wire                use_nco,
  input  wire [PHASE_W-1:0]  phase_inc,
  output wire                sample_valid,
  output wire [ADDR_W-1:0]   rom_addr,
  output wire                i_bit,
  output wire                q_bit,
  output reg                 rf_valid,
  output reg                 rf_bit,
  output wire signed [W-1:0] i_dbg,
  output wire signed [W-1:0] q_dbg
);

  wire signed [ACC_W-1:0] v_i1_state;
  wire signed [ACC_W-1:0] v_i2_state;
  wire signed [ACC_W-1:0] v_q1_state;
  wire signed [ACC_W-1:0] v_q2_state;
  wire signed [W-1:0]     rf_dbg;

  wire rf_valid_fs4;
  wire rf_bit_fs4;
  wire rf_valid_nco;
  wire signed [W-1:0] rf_nco;
  wire [PHASE_W-1:0] phase_acc_dbg;

  wire signed [1:0] i_s = i_bit ? 2'sd1 : -2'sd1;
  wire signed [1:0] q_s = q_bit ? 2'sd1 : -2'sd1;

  rom_reader #(
    .W(W),
    .ADDR_W(ADDR_W),
    .DEPTH(DEPTH),
    .USE_FILE_ROM(USE_FILE_ROM),
    .MEM_I_FILE(MEM_I_FILE),
    .MEM_Q_FILE(MEM_Q_FILE)
  ) u_rom (
    .clk   (clk),
    .rst_n (rst_n),
    .enable(enable),
    .addr  (rom_addr),
    .i_data(i_dbg),
    .q_data(q_dbg),
    .valid (sample_valid)
  );

  dsm_core_dsm2 #(
    .W_IN(W),
    .ACC_W(ACC_W),
    .IN_SHIFT(IN_SHIFT),
    .SATURATE(DSM_SATURATE)
  ) u_i (
    .clk     (clk),
    .rst_n   (rst_n),
    .enable  (sample_valid),
    .x_in    (i_dbg),
    .y_bit   (i_bit),
    .y_signed(),
    .v1_state(v_i1_state),
    .v2_state(v_i2_state)
  );

  dsm_core_dsm2 #(
    .W_IN(W),
    .ACC_W(ACC_W),
    .IN_SHIFT(IN_SHIFT),
    .SATURATE(DSM_SATURATE)
  ) u_q (
    .clk     (clk),
    .rst_n   (rst_n),
    .enable  (sample_valid),
    .x_in    (q_dbg),
    .y_bit   (q_bit),
    .y_signed(),
    .v1_state(v_q1_state),
    .v2_state(v_q2_state)
  );

  duc_fs4_merge #(
    .W_OUT(W)
  ) u_duc (
    .clk      (clk),
    .rst_n    (rst_n),
    .in_valid (sample_valid),
    .i_bit    (i_bit),
    .q_bit    (q_bit),
    .rf_valid (rf_valid_fs4),
    .rf_bit   (rf_bit_fs4),
    .rf_signed(rf_dbg),
    .phase    ()
  );

  duc_nco_mix_signed #(
    .W_IN(2),
    .W_OUT(W),
    .PHASE_W(PHASE_W)
  ) u_nco (
    .clk          (clk),
    .rst_n        (rst_n),
    .in_valid     (sample_valid),
    .phase_inc    (phase_inc),
    .i_data       (i_s),
    .q_data       (q_s),
    .rf_valid     (rf_valid_nco),
    .rf_signed    (rf_nco),
    .phase_acc_dbg(phase_acc_dbg)
  );

  always @* begin
    if (use_nco) begin
      rf_valid = rf_valid_nco;
      rf_bit   = ~rf_nco[W-1];
    end else begin
      rf_valid = rf_valid_fs4;
      rf_bit   = rf_bit_fs4;
    end
  end

endmodule

`default_nettype wire
