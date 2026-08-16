`timescale 1ns/1ps
`default_nettype none

// DROP_ON_FULL is an explicit loss policy for a feedback ADC source that
// cannot be backpressured. Verify that it drops only full-FIFO beats, never
// stalls the source, and preserves order for all accepted samples.
module tb_dpd_observer_async_bridge_drop;
  localparam integer N = 96;
  logic feedback_clk = 1'b0;
  logic aclk = 1'b0;
  logic rst_n = 1'b0;
  logic [31:0] s_tdata;
  logic s_tlast;
  logic s_tuser;
  logic s_tvalid;
  wire s_tready;
  wire [31:0] source_stall_count;
  wire [31:0] source_drop_count;
  wire signed [15:0] obs_i;
  wire signed [15:0] obs_q;
  wire obs_last;
  wire obs_invalid;
  wire obs_valid;
  logic obs_ready;
  integer write_index;
  integer read_count;
  integer last_i;
  integer sink_cycle;

  always #2 feedback_clk = ~feedback_clk;
  always #5 aclk = ~aclk;

  dpd_observer_async_bridge #(
    .W(16), .USER_W(1), .ADDR_W(2), .DROP_ON_FULL(1)
  ) dut (
    .feedback_clk(feedback_clk), .feedback_rst_n(rst_n),
    .s_axis_tdata(s_tdata), .s_axis_tlast(s_tlast), .s_axis_tuser(s_tuser),
    .s_axis_tvalid(s_tvalid), .s_axis_tready(s_tready),
    .source_stall_count(source_stall_count), .source_drop_count(source_drop_count),
    .aclk(aclk), .aresetn(rst_n), .obs_i(obs_i), .obs_q(obs_q),
    .obs_last(obs_last), .obs_invalid(obs_invalid), .obs_valid(obs_valid),
    .obs_ready(obs_ready)
  );

  always_comb begin
    s_tvalid = rst_n && (write_index < N);
    s_tdata = {16'(write_index * -17 + 1000), 16'(write_index * 29 - 400)};
    s_tlast = (write_index == N - 1);
    s_tuser = ((write_index % 13) == 5);
  end

  always @(posedge feedback_clk) begin
    if (!rst_n)
      write_index <= 0;
    else if (s_tvalid && s_tready)
      write_index <= write_index + 1;
  end

  always @(posedge aclk) begin
    integer sample_index;
    if (!rst_n) begin
      obs_ready <= 1'b0;
      read_count <= 0;
      last_i <= -32768;
      sink_cycle <= 0;
    end else begin
      sink_cycle <= sink_cycle + 1;
      // Hold the sink initially so the depth-four FIFO reaches full, then
      // drain with deterministic backpressure to exercise repeated full hits.
      obs_ready <= (sink_cycle >= 24) && ((sink_cycle % 3) != 0);
      if (obs_valid && obs_ready) begin
        sample_index = (obs_i + 400) / 29;
        if ((obs_i + 400) != (sample_index * 29) ||
            obs_q != (sample_index * -17 + 1000) ||
            obs_i <= last_i)
          $fatal(1, "drop bridge ordering/data mismatch i=%0d q=%0d", obs_i, obs_q);
        if (obs_invalid !== ((sample_index % 13) == 5))
          $fatal(1, "drop bridge user mismatch sample=%0d", sample_index);
        if (obs_last !== (sample_index == N - 1))
          $fatal(1, "drop bridge last mismatch sample=%0d", sample_index);
        last_i <= obs_i;
        read_count <= read_count + 1;
      end
    end
  end

  initial begin
    write_index = 0;
    read_count = 0;
    last_i = -32768;
    sink_cycle = 0;
    obs_ready = 1'b0;
    repeat (6) @(posedge aclk);
    rst_n = 1'b1;
    wait (write_index == N);
    repeat (80) @(posedge aclk);
    if (source_stall_count != 0)
      $fatal(1, "drop-on-full source unexpectedly stalled count=%0d", source_stall_count);
    if (source_drop_count == 0)
      $fatal(1, "drop-on-full did not record a full-FIFO drop");
    if ((read_count + source_drop_count) != N)
      $fatal(1, "accepted/drop accounting mismatch read=%0d drop=%0d total=%0d",
             read_count, source_drop_count, N);
    $display("DPD_ASYNC_BRIDGE_DROP_PASS sent=%0d read=%0d drops=%0d",
             N, read_count, source_drop_count);
    $finish;
  end
endmodule

`default_nettype wire
