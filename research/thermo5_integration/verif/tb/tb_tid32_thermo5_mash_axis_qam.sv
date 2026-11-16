`timescale 1ns/1ps
`default_nettype none

module tb_tid32_thermo5_mash_axis_qam #(
  parameter int SOURCE_BEATS = 3004,
  parameter int EXPECTED_WORDS = 5257
);
  localparam int W = 16;
  logic s_clk = 1'b0, core_clk = 1'b0;
  logic s_rst_n = 1'b0, core_rst_n = 1'b0;
  logic core_drain = 1'b0;
  logic s_valid = 1'b0, s_frame_start = 1'b0, s_last = 1'b0;
  logic signed [14*W-1:0] s_i = '0, s_q = '0;
  wire s_ready, s_fifo_full, core_underflow, core_protocol_error;
  wire [1:0] pa_valid;
  logic [1:0] pa_ready = 2'b11;
  wire [63:0] pa0, pa1;
  wire frame_start, frame_end, tail, overflow_error;
  wire [15:0] config_id, reset_epoch;
  logic [W-1:0] i_samples[0:14*SOURCE_BEATS-1];
  logic [W-1:0] q_samples[0:14*SOURCE_BEATS-1];
  logic [63:0] expected_pa0[0:EXPECTED_WORDS-1];
  logic [63:0] expected_pa1[0:EXPECTED_WORDS-1];
  integer beat, lane, accepted, produced, errors, cycles;
  integer pa0_fd, pa1_fd;
  string pa0_path, pa1_path;
  logic signed [15:0] c1_re;

  always #4 s_clk = ~s_clk;
  always #2.285714 core_clk = ~core_clk;

  tid32_thermo5_mash_axis_frontend_tx #(
    .W(W), .GAIN_W(16), .DPD_MAX_TAPS(1), .INTERP_TAPS(2),
    .FPGA_USE_XPM_FIFO(1'b0), .CONFIG_ID(16'h0042), .RESET_EPOCH(16'h0001)
  ) dut (
    .s_axis_aclk(s_clk), .s_axis_aresetn(s_rst_n),
    .s_axis_tvalid(s_valid), .s_axis_tready(s_ready),
    .s_axis_i_vec(s_i), .s_axis_q_vec(s_q),
    .s_axis_tuser_frame_start(s_frame_start), .s_axis_tlast(s_last),
    .s_axis_tuser_frame_gain(16'sh4000), .s_axis_fifo_full(s_fifo_full),
    .core_clk(core_clk), .core_aresetn(core_rst_n),
    .core_drain(core_drain),
    .core_underflow(core_underflow), .core_protocol_error(core_protocol_error),
    .dpd_active_taps(3'd1), .c1_re(c1_re), .c1_im(16'sd0),
    .c3_re(16'sd0), .c3_im(16'sd0), .c5_re(16'sd0), .c5_im(16'sd0),
    .mash_pa_valid(pa_valid), .mash_pa_ready(pa_ready),
    .mash_pa0_data(pa0), .mash_pa1_data(pa1),
    .out_frame_start(frame_start), .out_frame_end(frame_end), .out_tail(tail),
    .out_config_id(config_id), .out_reset_epoch(reset_epoch),
    .adapter_overflow(overflow_error)
  );

  initial begin
    $readmemh("axis_i_samples.mem", i_samples);
    $readmemh("axis_q_samples.mem", q_samples);
    $readmemh("expected_mash_pa0.mem", expected_pa0);
    $readmemh("expected_mash_pa1.mem", expected_pa1);
    if (!$value$plusargs("pa0=%s", pa0_path)) $fatal(1,"missing +pa0=<path>");
    if (!$value$plusargs("pa1=%s", pa1_path)) $fatal(1,"missing +pa1=<path>");
    pa0_fd=$fopen(pa0_path,"w");
    pa1_fd=$fopen(pa1_path,"w");
    if (!pa0_fd || !pa1_fd) $fatal(1,"cannot open PA capture output");
    c1_re = 16'sh4000;
    accepted=0; produced=0; errors=0; cycles=0;
    repeat (8) begin @(negedge s_clk); end
    s_rst_n=1'b1;
    repeat (8) begin @(negedge core_clk); end
    core_rst_n=1'b1;

    for (beat=0; beat<SOURCE_BEATS; beat=beat+1) begin
      @(negedge s_clk);
      s_valid=1'b1;
      s_frame_start=(beat==0);
      s_last=(beat==SOURCE_BEATS-1);
      for (lane=0; lane<14; lane=lane+1) begin
        s_i[lane*W +: W]=i_samples[beat*14+lane];
        s_q[lane*W +: W]=q_samples[beat*14+lane];
      end
      do @(posedge s_clk); while (!s_ready);
      accepted=accepted+1;
    end
    @(negedge s_clk);
    s_valid=1'b0; s_frame_start=1'b0; s_last=1'b0;
    core_drain=1'b1;

    wait(produced==EXPECTED_WORDS);
    repeat (4) @(posedge core_clk);
    if (accepted!=SOURCE_BEATS || errors!=0 || core_underflow ||
        core_protocol_error || overflow_error || s_fifo_full)
      $fatal(1,"MASH QAM RTL mismatch accepted=%0d/%0d produced=%0d/%0d errors=%0d underflow=%b protocol=%b overflow=%b",
        accepted,SOURCE_BEATS,produced,EXPECTED_WORDS,errors,core_underflow,
        core_protocol_error,overflow_error);
    $display("THERMO5_MASH_AXIS_QAM_BITTRUE_PASS source_beats=%0d pa_words=%0d II=1",accepted,produced);
    $fclose(pa0_fd); $fclose(pa1_fd);
    $finish;
  end

  always @(posedge core_clk) begin
    cycles=cycles+1;
    if (core_rst_n && (|pa_valid)) begin
      if (pa_valid!==2'b11)
        $fatal(1,"PA pair lost atomic valid: %b",pa_valid);
      if (config_id!==16'h0042 || reset_epoch!==16'h0001 || tail)
        $fatal(1,"MASH output metadata mismatch word=%0d cfg=%h epoch=%h tail=%b",
          produced,config_id,reset_epoch,tail);
      if (frame_start !== (produced==0) || frame_end !== (produced==EXPECTED_WORDS-1))
        $fatal(1,"frame marker mismatch word=%0d start=%b end=%b",produced,frame_start,frame_end);
      if (pa0!==expected_pa0[produced] || pa1!==expected_pa1[produced]) begin
        errors=errors+1;
        if(errors<5) $error("PA Golden mismatch word=%0d",produced);
      end
      $fdisplay(pa0_fd,"%016h",pa0);
      $fdisplay(pa1_fd,"%016h",pa1);
      produced=produced+1;
    end
    if (cycles>2000000) $fatal(1,"MASH QAM watchdog accepted=%0d produced=%0d",accepted,produced);
  end
endmodule

`default_nettype wire
