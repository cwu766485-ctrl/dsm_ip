`timescale 1ns/1ps
`default_nettype none

// Exercise both real Centered-Cubic queues, DPD, metadata FIFOs and the
// SKU-specific PA sink path with a legal short-packet metadata schedule.
module thermo5_v14_cubic_chain_harness (
  input logic clk, rst_n, source_offer,
  input logic [3:0] pa_ready
);
  for (genvar arch = 1; arch <= 3; arch += 2) begin : g_sku
    logic [5:0] word_index;
    logic valid_held;
    wire source_ready;
    wire source_valid = source_offer || valid_held;
    wire source_start = (word_index % 7) == 0;
    wire source_end = word_index == 55;

    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        word_index <= '0;
        valid_held <= 1'b0;
      end else begin
        valid_held <= source_valid && !source_ready;
        if (source_valid && source_ready)
          word_index <= source_end ? '0 : word_index + 1'b1;
      end
    end

    tid32_thermo5_frontend_tx #(
      .MAX_TAPS(1), .INTERP_TAPS(2), .INTERP_CENTERED_CUBIC(1'b1),
      .DSM_ARCH(arch), .TIDSM_ORDER(arch == 1 ? 1 : 2),
      .STEP(arch == 1 ? 7168 : 5120)
    ) dut (
      .clk(clk), .rst_n(rst_n), .enable(1'b1), .in_valid(source_valid),
      .in_ready(source_ready), .in_frame_start(source_start),
      .in_frame_end(source_end), .in_frame_gain(16'sd16384),
      .in_i_vec('0), .in_q_vec('0), .dpd_active_taps(3'd1),
      .c1_re(16'sd16384), .c1_im('0), .c3_re('0), .c3_im('0),
      .c5_re('0), .c5_im('0), .pa_valid(), .pa_data(),
      .dpd_config_boundary(), .pa_ready(pa_ready)
    );

    wire [1:0] count1 = dut.g_interp1_centered.u_interp_1.q_count;
    wire [1:0] count2 = dut.g_interp2_centered.u_interp_2.q_count;
    wire replace1 = count1 == 1 && dut.g_interp1_centered.u_interp_1.pop_head &&
                                   dut.g_interp1_centered.u_interp_1.push_input;
    wire replace2 = count2 == 1 && dut.g_interp2_centered.u_interp_2.pop_head &&
                                   dut.g_interp2_centered.u_interp_2.push_input;
    wire tail0 = dut.g_interp2_centered.u_interp_2.q0_tail;
    wire tail1 = dut.g_interp2_centered.u_interp_2.q1_tail;

    a_no_two_queued_tails: assert property (@(posedge clk)
      disable iff (!rst_n) !(count2 == 2 && tail0 && tail1));
    c_stage1_single_entry_replacement: cover property (@(posedge clk)
      disable iff (!rst_n) replace1);
    c_stage2_single_entry_replacement: cover property (@(posedge clk)
      disable iff (!rst_n) replace2);
    c_stage2_tail_lookahead: cover property (@(posedge clk)
      disable iff (!rst_n) count2 == 2 && !tail0 && tail1);
    c_stage2_tail_with_pa_blocked: cover property (@(posedge clk)
      disable iff (!rst_n) (count2 != 0) && tail0 && (&pa_ready) == 1'b0);
  end
endmodule

`default_nettype wire
