`timescale 1ns/1ps
`default_nettype none

module tb_dsm_axis14_to_core8_cdc #(
  parameter bit USE_XPM_FIFO = 1'b0
);
  localparam int W = 16;
  localparam int SRC_LANES = 14;
  localparam int CORE_LANES = 8;
  localparam int SRC_WORDS = 8;
  localparam int CORE_WORDS = (SRC_WORDS*SRC_LANES)/CORE_LANES;

  logic s_clk = 1'b0, c_clk = 1'b0;
  logic s_rst_n = 1'b0, c_rst_n = 1'b0, c_enable = 1'b0;
  logic s_valid = 1'b0, s_frame_start = 1'b0;
  logic signed [SRC_LANES*W-1:0] s_i = '0, s_q = '0;
  logic signed [W-1:0] s_gain = '0;
  wire s_ready, fifo_full;
  wire c_valid, c_frame_start, c_underflow, c_protocol_error;
  wire signed [CORE_LANES*W-1:0] c_i, c_q;
  wire signed [W-1:0] c_gain;
  logic c_ready = 1'b1;
  integer sent, got, lane, errors, expected_sample;
  logic stream_seen;
  integer accepted_before_enable;

  dsm_axis14_to_core8_cdc #(.W(W), .GAIN_W(W), .FIFO_ADDR_W(4), .USE_XPM_FIFO(USE_XPM_FIFO)) dut (
    .s_axis_aclk(s_clk), .s_axis_aresetn(s_rst_n), .s_axis_tvalid(s_valid), .s_axis_tready(s_ready),
    .s_axis_i_vec(s_i), .s_axis_q_vec(s_q), .s_axis_tuser_frame_start(s_frame_start),
    .s_axis_tuser_frame_gain(s_gain), .s_axis_fifo_full(fifo_full),
    .core_clk(c_clk), .core_aresetn(c_rst_n), .core_enable(c_enable), .core_drain(1'b0),
    .core_valid(c_valid), .core_ready(c_ready), .core_i_vec(c_i), .core_q_vec(c_q),
    .core_frame_start(c_frame_start), .core_frame_gain(c_gain),
    .core_underflow(c_underflow), .core_protocol_error(c_protocol_error)
  );

  always #4 s_clk = ~s_clk;                 // 125 MHz
  always #2.285714286 c_clk = ~c_clk;       // 218.75 MHz

  task automatic drive_source_word(input integer word_index);
    integer k;
    begin
      @(negedge s_clk);
      s_valid = 1'b1;
      s_frame_start = ((word_index % 4) == 0);
      s_gain = ((word_index % 4) == 0) ? (16'sd16384-word_index) : '0;
      for (k = 0; k < SRC_LANES; k = k + 1) begin
        s_i[k*W +: W] = word_index*SRC_LANES + k;
        s_q[k*W +: W] = -(word_index*SRC_LANES + k);
      end
      do @(posedge s_clk); while (!s_ready);
      sent = sent + 1;
      @(negedge s_clk);
      s_valid = 1'b0;
    end
  endtask

  initial begin
    sent = 0; got = 0; errors = 0; stream_seen = 1'b0;
    accepted_before_enable = 0;
    // XPM has one reset for both pointer domains.  Release both domains before
    // traffic, prefill one superframe while the core is disabled, then run.
    repeat (4) @(negedge s_clk); s_rst_n = 1'b1;
    repeat (4) @(negedge c_clk); c_rst_n = 1'b1;
    repeat (4) @(posedge s_clk);
    // Fill at least one 56-sample superframe before enabling the core domain.
    repeat (4) drive_source_word(sent);
    if (sent != 4) $fatal(1, "CDC prefill contract failed: accepted=%0d expected=4", sent);
    while (sent < SRC_WORDS) drive_source_word(sent);
    @(negedge c_clk); c_enable = 1'b1;
    fork
      begin wait (got == CORE_WORDS); end
      begin repeat (2000) @(posedge c_clk); $fatal(1, "CDC test timeout sent=%0d got=%0d", sent, got); end
    join_any
    disable fork;
    @(negedge c_clk); c_enable = 1'b0;
    repeat (4) @(posedge c_clk);
    if (errors != 0) $fatal(1, "CDC gearbox mismatches=%0d", errors);
    if (c_underflow) $fatal(1, "CDC underflow asserted");
    if (c_protocol_error) $fatal(1, "CDC protocol error asserted");
    $display("DSM_AXIS14_TO_CORE8_CDC_PASS src_words=%0d core_words=%0d", SRC_WORDS, CORE_WORDS);
    $finish;
  end

  always @(posedge c_clk) begin
    if (c_rst_n && c_enable) begin
      if (stream_seen && (got < CORE_WORDS) && !c_valid) begin
        $error("unexpected core bubble after stream start, word=%0d", got);
        errors <= errors + 1;
      end
      if (c_valid && c_ready) begin
        stream_seen <= 1'b1;
        if (c_frame_start !== ((got % 7) == 0)) begin
          $error("frame-start mismatch core_word=%0d got=%b", got, c_frame_start);
          errors <= errors + 1;
        end
        if (c_frame_start && c_gain !== (16'sd16384 - ((got/7)*4))) begin
          $error("frame-gain mismatch core_word=%0d got=%0d", got, c_gain);
          errors <= errors + 1;
        end
        for (lane = 0; lane < CORE_LANES; lane = lane + 1) begin
          expected_sample = got*CORE_LANES + lane;
          if ($signed(c_i[lane*W +: W]) !== expected_sample) begin
            $error("I order mismatch word=%0d lane=%0d got=%0d exp=%0d", got, lane,
                   $signed(c_i[lane*W +: W]), expected_sample);
            errors <= errors + 1;
          end
          if ($signed(c_q[lane*W +: W]) !== -expected_sample) begin
            $error("Q order mismatch word=%0d lane=%0d got=%0d exp=%0d", got, lane,
                   $signed(c_q[lane*W +: W]), -expected_sample);
            errors <= errors + 1;
          end
        end
        got <= got + 1;
      end
    end
  end

  // Reset release is asynchronous-assert/synchronous-deassert.  No core word
  // may escape before both the synchronized core reset and explicit prefill
  // enable have completed.
  always @(posedge c_clk) begin
    if (!c_enable && c_valid) begin
      $error("core_valid asserted before FIFO prefill enable");
      errors <= errors + 1;
    end
  end
endmodule

`default_nettype wire
