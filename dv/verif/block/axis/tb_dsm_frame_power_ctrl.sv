`timescale 1ns/1ps
module tb_dsm_frame_power_ctrl;
  logic s_clk=0, c_clk=0, s_rst_n=0, c_rst_n=0, run_request=0;
  logic s_accept=0, core_accept=0, output_accept=0, core_input_valid=0, output_valid=0;
  wire core_en, ingress_en; wire [2:0] state; wire [7:0] outstanding;
  dsm_frame_power_ctrl #(.PREFILL_WORDS(4)) dut (
    .s_clk(s_clk), .s_rst_n(s_rst_n), .s_accept(s_accept), .run_request(run_request),
    .core_clk(c_clk), .core_rst_n(c_rst_n), .core_accept(core_accept),
    .output_accept(output_accept), .core_input_valid(core_input_valid),
    .output_valid(output_valid), .core_activity_enable(core_en),
    .ingress_enable(ingress_en), .power_state(state), .outstanding_words(outstanding));
  always #4 s_clk=~s_clk;
  always #2 c_clk=~c_clk;
  initial begin
    repeat (3) @(posedge c_clk); s_rst_n=1; c_rst_n=1;
    @(negedge s_clk); run_request=1;
    wait (ingress_en);
    repeat (4) begin @(negedge s_clk); s_accept=1; @(negedge s_clk); s_accept=0; end
    repeat (8) @(posedge c_clk);
    if (!core_en || !ingress_en || state != 3) $fatal(1, "controller did not enter RUN");
    @(negedge c_clk); core_accept=1; core_input_valid=1;
    @(negedge c_clk); core_accept=0; output_accept=1; output_valid=1;
    @(negedge c_clk); output_accept=0; output_valid=0; core_input_valid=0; run_request=0;
    repeat (8) @(posedge c_clk);
    if (core_en || state != 1) $fatal(1, "controller did not drain to IDLE");
    $display("DSM_FRAME_POWER_CTRL_PASS"); $finish;
  end
endmodule
