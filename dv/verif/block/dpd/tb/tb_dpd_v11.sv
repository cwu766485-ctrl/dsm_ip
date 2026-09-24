`timescale 1ns/1ps
`default_nettype none

module tb_dpd_v11;
  localparam int W = 16;
  logic clk;
  logic rst_n;

  logic [2:0] active_taps;
  logic signed [63:0] c1_re;
  logic signed [63:0] c1_im;
  logic signed [63:0] c3_re;
  logic signed [63:0] c3_im;
  logic signed [63:0] c5_re;
  logic signed [63:0] c5_im;
  logic signed [15:0] mp_i_in;
  logic signed [15:0] mp_q_in;
  logic mp_in_valid;
  wire mp_in_ready;
  wire signed [15:0] mp_i_out;
  wire signed [15:0] mp_q_out;
  wire mp_out_valid;
  logic mp_out_ready;
  wire [31:0] mp_sample_count;
  wire [31:0] mp_saturation_count;

  logic obs_enable;
  logic obs_start;
  logic obs_clear;
  logic [4:0] obs_delay;
  logic signed [15:0] obs_gain_re;
  logic signed [15:0] obs_gain_im;
  logic signed [15:0] obs_temperature;
  logic [31:0] obs_window;
  logic signed [15:0] ref_i;
  logic signed [15:0] ref_q;
  logic ref_valid;
  logic signed [15:0] obs_i;
  logic signed [15:0] obs_q;
  logic obs_last;
  logic obs_invalid;
  logic obs_valid;
  wire obs_ready;
  wire obs_active;
  wire obs_done;
  wire obs_last_seen;
  wire [31:0] obs_paired_count;
  wire [31:0] obs_dropped_count;
  wire [63:0] obs_error_acc;
  wire signed [15:0] obs_latched_temperature;
  wire [31:0] obs_ref_mag_acc;
  wire [31:0] obs_mag_acc;
  wire [31:0] obs_peak;
  wire [15:0] obs_clip_count;
  wire [15:0] obs_saturation_count;
  wire [31:0] obs_slew_acc;
  wire [31:0] obs_spec_bin0;
  wire [31:0] obs_spec_bin1;
  wire [31:0] obs_spec_bin2;
  wire [31:0] obs_spec_adj;

  logic condition_valid;
  logic [7:0] condition_version;
  logic [15:0] qam_order;
  logic [31:0] bandwidth_khz;
  logic [31:0] backoff_ppm;
  logic signed [15:0] power_q8_8;
  logic signed [15:0] temperature_q8_8;
  logic [31:0] monitor_state;
  wire [2:0] seed_package;
  wire condition_known;
  wire fallback_required;
  wire local_search_required;

  int mp_sent;
  int mp_received;
  int expected_mp [0:4];

  initial clk = 1'b0;
  always #5 clk = ~clk;

  dpd_memory_poly u_memory_poly (
    .clk(clk), .rst_n(rst_n), .active_taps(active_taps),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .i_in(mp_i_in), .q_in(mp_q_in),
    .in_valid(mp_in_valid), .in_ready(mp_in_ready),
    .i_out(mp_i_out), .q_out(mp_q_out), .out_valid(mp_out_valid),
    .out_ready(mp_out_ready), .sample_count(mp_sample_count),
    .saturation_count(mp_saturation_count)
  );

  dpd_observer u_observer (
    .clk(clk), .rst_n(rst_n), .enable(obs_enable), .start(obs_start),
    .clear(obs_clear), .delay_samples(obs_delay), .gain_re(obs_gain_re),
    .gain_im(obs_gain_im), .temperature_q8_8(obs_temperature),
    .window_samples(obs_window), .ref_i(ref_i),
    .ref_q(ref_q), .ref_valid(ref_valid), .obs_i(obs_i), .obs_q(obs_q),
    .obs_last(obs_last), .obs_invalid(obs_invalid), .obs_valid(obs_valid),
    .obs_ready(obs_ready), .active(obs_active), .done(obs_done),
    .last_seen(obs_last_seen), .paired_count(obs_paired_count),
    .dropped_count(obs_dropped_count), .error_acc(obs_error_acc),
    .latched_temperature_q8_8(obs_latched_temperature),
    .ref_mag_acc(obs_ref_mag_acc), .obs_mag_acc(obs_mag_acc),
    .obs_peak(obs_peak), .clip_count(obs_clip_count),
    .saturation_count(obs_saturation_count), .slew_acc(obs_slew_acc),
    .spec_bin0(obs_spec_bin0), .spec_bin1(obs_spec_bin1),
    .spec_bin2(obs_spec_bin2), .spec_adj(obs_spec_adj)
  );

  dpd_seed_predictor u_predictor (
    .condition_valid(condition_valid), .condition_version(condition_version),
    .qam_order(qam_order), .bandwidth_khz(bandwidth_khz),
    .backoff_ppm(backoff_ppm), .power_q8_8(power_q8_8),
    .temperature_q8_8(temperature_q8_8), .monitor_state(monitor_state),
    .seed_package(seed_package), .condition_known(condition_known),
    .fallback_required(fallback_required),
    .local_search_required(local_search_required)
  );

  initial begin
    rst_n = 1'b0;
    active_taps = 3'd2;
    c1_re = {16'sd0, 16'sd0, 16'sd8192, 16'sd16384};
    c1_im = 64'sd0;
    c3_re = 64'sd0;
    c3_im = 64'sd0;
    c5_re = 64'sd0;
    c5_im = 64'sd0;
    mp_i_in = 16'sd0;
    mp_q_in = 16'sd0;
    mp_in_valid = 1'b0;
    mp_out_ready = 1'b1;
    mp_sent = 0;
    mp_received = 0;
    expected_mp[0] = 1000;
    expected_mp[1] = 2500;
    expected_mp[2] = 4000;
    expected_mp[3] = 5500;
    expected_mp[4] = 7000;

    obs_enable = 1'b0;
    obs_start = 1'b0;
    obs_clear = 1'b0;
    obs_delay = 5'd1;
    obs_gain_re = 16'sd16384;
    obs_gain_im = 16'sd0;
    obs_temperature = 16'sd6400;
    obs_window = 32'd4;
    ref_i = 16'sd0;
    ref_q = 16'sd0;
    ref_valid = 1'b0;
    obs_i = 16'sd0;
    obs_q = 16'sd0;
    obs_last = 1'b0;
    obs_invalid = 1'b0;
    obs_valid = 1'b0;

    condition_valid = 1'b1;
    condition_version = 8'd1;
    qam_order = 16'd16;
    bandwidth_khz = 32'd20000;
    backoff_ppm = 32'd580000;
    power_q8_8 = 16'sd0;
    temperature_q8_8 = 16'sd6400;
    monitor_state = 32'd0;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    #1;
    if (!condition_known || fallback_required || seed_package != 3'd2 ||
        !local_search_required) $fatal(1, "known condition policy mismatch");
    backoff_ppm = 32'd700000;
    #1;
    if (seed_package != 3'd5 || fallback_required) $fatal(1, "seed 5 selection mismatch");
    monitor_state = 32'd1;
    #1;
    if (!fallback_required) $fatal(1, "monitor fault did not force fallback");
    monitor_state = 32'd0;
    qam_order = 16'd256;
    #1;
    if (condition_known || !fallback_required) $fatal(1, "unknown QAM was accepted");

    for (int n = 1; n <= 5; n++) begin
      @(negedge clk);
      mp_i_in = n * 1000;
      mp_q_in = 16'sd0;
      mp_in_valid = 1'b1;
      @(negedge clk);
      mp_in_valid = 1'b0;
    end
    wait (mp_received == 5);
    if (mp_sample_count != 5 || mp_saturation_count != 0)
      $fatal(1, "memory polynomial counters mismatch");

    @(negedge clk);
    ref_i = 16'sd100;
    ref_valid = 1'b1;
    @(negedge clk);
    ref_valid = 1'b0;
    obs_enable = 1'b1;
    obs_start = 1'b1;
    @(negedge clk);
    obs_start = 1'b0;
    for (int n = 1; n <= 4; n++) begin
      ref_i = (n + 1) * 100;
      obs_i = n * 100;
      ref_valid = 1'b1;
      obs_valid = 1'b1;
      obs_last = (n == 4);
      @(negedge clk);
    end
    ref_valid = 1'b0;
    obs_valid = 1'b0;
    obs_last = 1'b0;
    repeat (2) @(posedge clk);
    if (!obs_done || obs_active || obs_paired_count != 4 ||
        obs_dropped_count != 0 || obs_error_acc != 0 || !obs_last_seen)
      $fatal(1, "observation alignment/window mismatch");
    if (obs_latched_temperature != 16'sd6400 || obs_ref_mag_acc != 32'd1000 ||
        obs_mag_acc != 32'd1000 || obs_peak != 32'd400 ||
        obs_clip_count != 0 || obs_saturation_count != 0 ||
        obs_slew_acc != 32'd300 || obs_spec_bin0 != 32'd1000 ||
        obs_spec_bin1 != 32'd400 || obs_spec_bin2 != 32'd200 ||
        obs_spec_adj != 32'd1200)
      $fatal(1, "observation complex monitor-statistics mismatch");

    @(negedge clk);
    obs_gain_re = 16'sd32767;
    obs_temperature = 16'sd12800;
    obs_delay = 5'd0;
    obs_window = 32'd1;
    obs_start = 1'b1;
    @(negedge clk);
    obs_start = 1'b0;
    ref_i = 16'sd20000;
    obs_i = 16'sd20000;
    ref_valid = 1'b1;
    obs_valid = 1'b1;
    obs_last = 1'b1;
    @(negedge clk);
    ref_valid = 1'b0;
    obs_valid = 1'b0;
    obs_last = 1'b0;
    repeat (2) @(posedge clk);
    if (!obs_done || obs_paired_count != 1 || obs_error_acc != 64'd19998 ||
        obs_latched_temperature != 16'sd12800 || obs_ref_mag_acc != 32'd20000 ||
        obs_mag_acc != 32'd32767 || obs_peak != 32'd32767 ||
        obs_clip_count != 16'd1 || obs_saturation_count != 16'd1 ||
        obs_slew_acc != 32'd0 || obs_spec_bin0 != 32'd32767 ||
        obs_spec_bin1 != 32'd32767 || obs_spec_bin2 != 32'd32767 ||
        obs_spec_adj != 32'd65534)
      $fatal(1, "observation saturation/temperature boundary mismatch");

    $display("DPD v1.1 unit PASS");
    $finish;
  end

  always @(posedge clk) begin
    if (rst_n && mp_in_valid && mp_in_ready) mp_sent <= mp_sent + 1;
    if (rst_n && mp_out_valid && mp_out_ready) begin
      if (mp_i_out !== expected_mp[mp_received] || mp_q_out !== 0)
        $fatal(1, "memory polynomial mismatch n=%0d got=(%0d,%0d) expected=%0d",
               mp_received, mp_i_out, mp_q_out, expected_mp[mp_received]);
      mp_received <= mp_received + 1;
    end
  end

endmodule

`default_nettype wire
