`timescale 1ns/1ps
`default_nettype none

// Reproducible asynchronous FIFO stress. Small depth forces source-side
// backpressure while randomized sink readiness checks ordering and sideband.
module tb_dpd_observer_async_bridge_random;
  localparam integer N = 129;
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
  integer write_index = 0;
  integer read_index = 0;
  integer lfsr = 32'h55aa_0f0f;

  always #3 feedback_clk = ~feedback_clk;
  always #5 aclk = ~aclk;

  dpd_observer_async_bridge #(.W(16), .USER_W(1), .ADDR_W(2)) dut (
    .feedback_clk(feedback_clk), .feedback_rst_n(rst_n),
    .s_axis_tdata(s_tdata), .s_axis_tlast(s_tlast), .s_axis_tuser(s_tuser),
    .s_axis_tvalid(s_tvalid), .s_axis_tready(s_tready),
    .source_stall_count(source_stall_count), .source_drop_count(source_drop_count),
    .aclk(aclk), .aresetn(rst_n), .obs_i(obs_i), .obs_q(obs_q),
    .obs_last(obs_last), .obs_invalid(obs_invalid), .obs_valid(obs_valid),
    .obs_ready(obs_ready)
  );

  function automatic integer next_lfsr(input integer value);
    begin
      next_lfsr = (value << 1) ^ (((value >> 31) ^ (value >> 21) ^
                                    (value >> 1) ^ value) & 1);
    end
  endfunction

  always_comb begin
    s_tvalid = rst_n && (write_index < N);
    s_tdata = {16'(write_index * -17 + 1000), 16'(write_index * 29 - 400)};
    s_tlast = (write_index == N-1);
    s_tuser = ((write_index % 17) == 7);
  end

  always @(posedge feedback_clk) begin
    if (!rst_n) write_index <= 0;
    else if (s_tvalid && s_tready) write_index <= write_index + 1;
  end

  always @(posedge aclk) begin
    if (!rst_n) begin
      read_index <= 0;
      lfsr <= 32'h55aa_0f0f;
      obs_ready <= 1'b0;
    end else begin
      lfsr <= next_lfsr(lfsr);
      obs_ready <= lfsr[0] | lfsr[3];
      if (obs_valid && obs_ready) begin
        if (obs_i !== (read_index * 29 - 400) ||
            obs_q !== (read_index * -17 + 1000) ||
            obs_invalid !== ((read_index % 17) == 7) ||
            obs_last !== (read_index == N-1))
          $fatal(1, "random async bridge mismatch n=%0d", read_index);
        read_index <= read_index + 1;
      end
    end
  end

  initial begin
    obs_ready = 1'b0;
    repeat (6) @(posedge aclk);
    rst_n = 1'b1;
    wait (read_index == N);
    repeat (4) @(posedge aclk);
    if (source_stall_count == 0) $fatal(1, "random bridge did not backpressure source");
    if (source_drop_count != 0) $fatal(1, "random bridge dropped feedback samples");
    $display("DPD_ASYNC_BRIDGE_RANDOM_PASS samples=%0d stalls=%0d", N, source_stall_count);
    $finish;
  end
endmodule

`default_nettype wire
