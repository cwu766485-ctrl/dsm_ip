`timescale 1ns/1ps
`default_nettype none

// Integration contract for an asynchronous feedback stream and the observer.
// The reference side mirrors the bridge output, making zero error a strict
// transport/alignment oracle while the source and sink clocks remain unrelated.
module tb_feedback_bridge_observer;
  localparam integer W = 16;
  localparam integer N = 129;
  localparam integer EXPECTED_INVALID = 12;
  localparam integer EXPECTED_PAIRS = N - EXPECTED_INVALID;

  logic feedback_clk = 1'b0;
  logic aclk = 1'b0;
  logic rst_n = 1'b0;
  logic enable = 1'b0;
  logic start = 1'b0;
  logic clear = 1'b0;
  logic [(2*W)-1:0] s_tdata;
  logic s_tlast;
  logic s_tuser;
  logic s_tvalid;
  wire s_tready;
  wire [31:0] source_stall_count;
  wire [31:0] source_drop_count;
  wire signed [W-1:0] obs_i;
  wire signed [W-1:0] obs_q;
  wire obs_last;
  wire obs_invalid;
  wire obs_valid;
  wire obs_ready;
  wire active;
  wire done;
  wire last_seen;
  wire [31:0] paired_count;
  wire [31:0] dropped_count;
  wire [63:0] error_acc;
  wire [31:0] ref_mag_acc;
  wire [31:0] obs_mag_acc;
  wire [31:0] obs_peak;
  wire [15:0] clip_count;
  wire [15:0] saturation_count;
  wire [31:0] slew_acc;
  wire [31:0] spec_bin0;
  wire [31:0] spec_bin1;
  wire [31:0] spec_bin2;
  wire [31:0] spec_adj;
  wire [4:0] overflow_flags;
  integer write_index = 0;

  function automatic logic signed [W-1:0] sample(
      input integer index, input bit is_q);
    integer raw;
    begin
      if (index == 0) sample = 16'sh8000;
      else if (index == 1) sample = 16'sh7fff;
      else begin
        raw = is_q ? (index * -883 + 239) : (index * 1429 - 611);
        sample = raw[W-1:0];
      end
    end
  endfunction

  always #3 feedback_clk = ~feedback_clk;
  always #5 aclk = ~aclk;

  always_comb begin
    s_tvalid = rst_n && (write_index < N);
    s_tdata = {sample(write_index, 1'b1), sample(write_index, 1'b0)};
    s_tlast = (write_index == N-1);
    s_tuser = ((write_index % 11) == 3) && (write_index != N-1);
  end

  always @(posedge feedback_clk) begin
    if (!rst_n) write_index <= 0;
    else if (s_tvalid && s_tready) write_index <= write_index + 1;
  end

  dpd_observer_async_bridge #(
    .W(W), .USER_W(1), .ADDR_W(2), .DROP_ON_FULL(0)
  ) u_bridge (
    .feedback_clk(feedback_clk), .feedback_rst_n(rst_n),
    .s_axis_tdata(s_tdata), .s_axis_tlast(s_tlast), .s_axis_tuser(s_tuser),
    .s_axis_tvalid(s_tvalid), .s_axis_tready(s_tready),
    .source_stall_count(source_stall_count), .source_drop_count(source_drop_count),
    .aclk(aclk), .aresetn(rst_n), .obs_i(obs_i), .obs_q(obs_q),
    .obs_last(obs_last), .obs_invalid(obs_invalid), .obs_valid(obs_valid),
    .obs_ready(obs_ready)
  );

  dpd_observer u_observer (
    .clk(aclk), .rst_n(rst_n), .enable(enable), .start(start), .clear(clear),
    .delay_samples(5'd0), .gain_re(16'sd16384), .gain_im('0),
    .temperature_q8_8(16'sd6400), .window_samples(EXPECTED_PAIRS),
    .ref_i(obs_i), .ref_q(obs_q), .ref_valid(obs_valid),
    .obs_i(obs_i), .obs_q(obs_q), .obs_last(obs_last), .obs_invalid(obs_invalid),
    .obs_valid(obs_valid), .obs_ready(obs_ready), .active(active), .done(done),
    .last_seen(last_seen), .paired_count(paired_count), .dropped_count(dropped_count),
    .error_acc(error_acc), .latched_temperature_q8_8(), .ref_mag_acc(ref_mag_acc),
    .obs_mag_acc(obs_mag_acc), .obs_peak(obs_peak), .clip_count(clip_count),
    .saturation_count(saturation_count), .slew_acc(slew_acc), .spec_bin0(spec_bin0),
    .spec_bin1(spec_bin1), .spec_bin2(spec_bin2), .spec_adj(spec_adj),
    .overflow_flags(overflow_flags)
  );

  initial begin
    repeat (6) @(negedge aclk);
    rst_n = 1'b1;
    enable = 1'b1;
    start = 1'b1;
    @(negedge aclk);
    start = 1'b0;
    wait (write_index == N);
    wait (done);
    repeat (4) @(posedge aclk);
    if (paired_count != EXPECTED_PAIRS || dropped_count != EXPECTED_INVALID ||
        error_acc != 0 || !last_seen || active)
      $fatal(1, "feedback subsystem count/state mismatch pair=%0d drop=%0d error=%0d",
             paired_count, dropped_count, error_acc);
    if (source_stall_count == 0 || source_drop_count != 0 || overflow_flags != 0)
      $fatal(1, "feedback subsystem bridge/overflow mismatch stalls=%0d drops=%0d flags=%0h",
             source_stall_count, source_drop_count, overflow_flags);
    if (ref_mag_acc != obs_mag_acc || obs_peak == 0 ||
        (spec_bin0 == 0 && spec_bin1 == 0 && spec_bin2 == 0 && spec_adj == 0))
      $fatal(1, "feedback subsystem monitor accumulation mismatch");
    $display("FEEDBACK_SUBSYSTEM_PASS samples=%0d pairs=%0d invalid=%0d stalls=%0d",
             N, paired_count, dropped_count, source_stall_count);
    $finish;
  end
endmodule

`default_nettype wire
