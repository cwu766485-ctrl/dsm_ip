`timescale 1ns/1ps
`default_nettype none

module tb_bp_ef2_map_compose_pipe;
  localparam int ACC_W = 28;
  localparam int MAP4 = 5;
  localparam int MAP8 = 9;
  localparam int LATENCY = 3*MAP8;
  localparam int TRANSACTIONS = 12;
  logic clk = 1'b0, rst_n = 1'b0, in_valid = 1'b0;
  logic signed [63:0] left_x = '0, right_x = '0;
  wire [MAP4-1:0] lv, ls, rv, rs;
  wire signed [MAP4*ACC_W-1:0] llo, lhi, lof, rlo, rhi, rof;
  wire [MAP4*4-1:0] lb, rb;
  wire [MAP8-1:0] cv, cs, pv, ps;
  wire signed [MAP8*ACC_W-1:0] clo, chi, cof, plo, phi, pof;
  wire [MAP8*8-1:0] cb, pb;
  wire pipe_valid;
  integer drive_index, check_index, errors, cycle;
  logic [MAP8-1:0] exp_v [0:TRANSACTIONS-1], exp_s [0:TRANSACTIONS-1];
  logic signed [MAP8*ACC_W-1:0] exp_lo [0:TRANSACTIONS-1], exp_hi [0:TRANSACTIONS-1], exp_of [0:TRANSACTIONS-1];
  logic [MAP8*8-1:0] exp_b [0:TRANSACTIONS-1];

  bp_ef2_phase_map4 u_left (.x_vec(left_x), .region_valid(lv), .region_slope_neg(ls), .region_lo_bus(llo), .region_hi_bus(lhi), .region_offset_bus(lof), .region_bits_bus(lb));
  bp_ef2_phase_map4 u_right (.x_vec(right_x), .region_valid(rv), .region_slope_neg(rs), .region_lo_bus(rlo), .region_hi_bus(rhi), .region_offset_bus(rof), .region_bits_bus(rb));
  bp_ef2_map_compose u_comb (.l_valid(lv), .l_slope_neg(ls), .l_lo_bus(llo), .l_hi_bus(lhi), .l_offset_bus(lof), .l_bits_bus(lb), .r_valid(rv), .r_slope_neg(rs), .r_lo_bus(rlo), .r_hi_bus(rhi), .r_offset_bus(rof), .r_bits_bus(rb), .out_valid(cv), .out_slope_neg(cs), .out_lo_bus(clo), .out_hi_bus(chi), .out_offset_bus(cof), .out_bits_bus(cb));
  bp_ef2_map_compose_pipe u_pipe (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .l_valid(lv), .l_slope_neg(ls), .l_lo_bus(llo), .l_hi_bus(lhi), .l_offset_bus(lof), .l_bits_bus(lb), .r_valid(rv), .r_slope_neg(rs), .r_lo_bus(rlo), .r_hi_bus(rhi), .r_offset_bus(rof), .r_bits_bus(rb), .out_valid(pipe_valid), .out_map_valid(pv), .out_slope_neg(ps), .out_lo_bus(plo), .out_hi_bus(phi), .out_offset_bus(pof), .out_bits_bus(pb));
  always #5 clk = ~clk;

  task automatic set_inputs(input integer t);
    integer n;
    begin
      for (n = 0; n < 4; n = n + 1) begin
        left_x[n*16 +: 16] = ((t*1831 + n*7919 + 41) % 65536) - 32768;
        right_x[n*16 +: 16] = ((t*3571 + n*4567 + 919) % 65536) - 32768;
      end
    end
  endtask

  initial begin
    drive_index = 0; check_index = 0; errors = 0; cycle = 0;
    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    while (drive_index < TRANSACTIONS) begin
      @(negedge clk);
      cycle = cycle + 1;
      if ((cycle % 5) == 3) begin in_valid = 1'b0; left_x = '0; right_x = '0; end
      else begin
        set_inputs(drive_index);
        in_valid = 1'b1;
        #1;
        exp_v[drive_index] = cv; exp_s[drive_index] = cs; exp_lo[drive_index] = clo;
        exp_hi[drive_index] = chi; exp_of[drive_index] = cof; exp_b[drive_index] = cb;
        drive_index = drive_index + 1;
      end
    end
    @(negedge clk); in_valid = 1'b0;
    repeat (LATENCY + 6) @(negedge clk);
    if (check_index != TRANSACTIONS) $fatal(1, "lost outputs %0d/%0d", check_index, TRANSACTIONS);
    if (errors != 0) $fatal(1, "compose-pipe errors=%0d", errors);
    $display("BP_EF2_MAP_COMPOSE_PIPE_PASS transactions=%0d latency=%0d", TRANSACTIONS, LATENCY);
    $finish;
  end

  always @(posedge clk) begin
    #1;
    if (rst_n && pipe_valid) begin
      if ((pv !== exp_v[check_index]) || (ps !== exp_s[check_index]) || (plo !== exp_lo[check_index]) || (phi !== exp_hi[check_index]) || (pof !== exp_of[check_index]) || (pb !== exp_b[check_index])) begin
        $error("compose pipeline mismatch transaction=%0d", check_index); errors = errors + 1;
      end
      check_index = check_index + 1;
    end
  end
endmodule

`default_nettype wire
