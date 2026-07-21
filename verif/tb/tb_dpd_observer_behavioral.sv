`timescale 1ns/1ps
`default_nettype none

module tb_dpd_observer_behavioral;
  localparam int MAX_REF = 128;
  localparam int MAX_OBS = 128;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic enable = 1'b0;
  logic start = 1'b0;
  logic clear = 1'b0;
  logic [4:0] delay_samples;
  logic signed [15:0] gain_re;
  logic signed [15:0] gain_im;
  logic signed [15:0] temperature_q8_8;
  logic [31:0] window_samples;
  logic signed [15:0] ref_i = 0;
  logic signed [15:0] ref_q = 0;
  logic ref_valid = 1'b0;
  logic signed [15:0] obs_i = 0;
  logic signed [15:0] obs_q = 0;
  logic obs_last = 1'b0;
  logic obs_invalid = 1'b0;
  logic obs_valid = 1'b0;
  wire obs_ready;
  wire active;
  wire done;
  wire last_seen;
  wire [31:0] paired_count;
  wire [31:0] dropped_count;
  wire [63:0] error_acc;
  wire signed [15:0] latched_temperature_q8_8;
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

  integer ref_i_data [0:MAX_REF-1];
  integer ref_q_data [0:MAX_REF-1];
  integer obs_i_data [0:MAX_OBS-1];
  integer obs_q_data [0:MAX_OBS-1];
  integer obs_invalid_data [0:MAX_OBS-1];
  integer delay_meta;
  integer gain_re_meta;
  integer gain_im_meta;
  integer pairs_meta;
  integer drops_meta;
  longint unsigned error_meta;
  integer samples_meta;
  integer temperature_meta;
  longint unsigned ref_mag_meta;
  longint unsigned obs_mag_meta;
  longint unsigned peak_meta;
  integer clip_meta;
  integer saturation_meta;
  longint unsigned slew_meta;
  longint unsigned spec_bin0_meta;
  longint unsigned spec_bin1_meta;
  longint unsigned spec_bin2_meta;
  longint unsigned spec_adj_meta;

  always #5 clk = ~clk;

  dpd_observer dut (
    .clk(clk), .rst_n(rst_n), .enable(enable), .start(start), .clear(clear),
    .delay_samples(delay_samples), .gain_re(gain_re), .gain_im(gain_im),
    .temperature_q8_8(temperature_q8_8),
    .window_samples(window_samples), .ref_i(ref_i), .ref_q(ref_q),
    .ref_valid(ref_valid), .obs_i(obs_i), .obs_q(obs_q), .obs_last(obs_last),
    .obs_invalid(obs_invalid), .obs_valid(obs_valid), .obs_ready(obs_ready),
    .active(active), .done(done), .last_seen(last_seen),
    .paired_count(paired_count), .dropped_count(dropped_count),
    .error_acc(error_acc), .latched_temperature_q8_8(latched_temperature_q8_8),
    .ref_mag_acc(ref_mag_acc), .obs_mag_acc(obs_mag_acc), .obs_peak(obs_peak),
    .clip_count(clip_count), .saturation_count(saturation_count),
    .slew_acc(slew_acc), .spec_bin0(spec_bin0), .spec_bin1(spec_bin1),
    .spec_bin2(spec_bin2), .spec_adj(spec_adj)
  );

  task load_vectors;
    integer fd;
    integer code;
    integer code_tail;
    integer index;
    integer unused;
    reg [4095:0] header;
    begin
      fd = $fopen("dpd_observer_metadata.csv", "r");
      if (fd == 0) $fatal(1, "cannot open observer metadata");
      unused = $fgets(header, fd);
      code = $fscanf(fd, "%d,%d,%d,%d,%d,%d,%d,%d,%d,", delay_meta,
        gain_re_meta, gain_im_meta, pairs_meta, drops_meta, error_meta,
        samples_meta, temperature_meta, ref_mag_meta);
      code_tail = $fscanf(fd, "%d,%d,%d,%d,%d,%d,%d,%d,%d\n", obs_mag_meta, peak_meta,
        clip_meta, saturation_meta, slew_meta, spec_bin0_meta, spec_bin1_meta,
        spec_bin2_meta, spec_adj_meta);
      if (code != 9 || code_tail != 9)
        $fatal(1, "invalid observer metadata head=%0d tail=%0d", code, code_tail);
      $fclose(fd);

      fd = $fopen("dpd_observer_ref.csv", "r");
      if (fd == 0) $fatal(1, "cannot open observer reference");
      unused = $fgets(header, fd);
      index = 0;
      while ($fscanf(fd, "%d,%d,%d\n", unused, ref_i_data[index],
                     ref_q_data[index]) == 3) index = index + 1;
      if (index != samples_meta + delay_meta) $fatal(1, "reference count mismatch");
      $fclose(fd);

      fd = $fopen("dpd_observer_feedback.csv", "r");
      if (fd == 0) $fatal(1, "cannot open observer feedback");
      unused = $fgets(header, fd);
      index = 0;
      while ($fscanf(fd, "%d,%d,%d,%d\n", unused, obs_i_data[index],
                     obs_q_data[index], obs_invalid_data[index]) == 4)
        index = index + 1;
      if (index != samples_meta) $fatal(1, "feedback count mismatch");
      $fclose(fd);
    end
  endtask

  initial begin
    load_vectors();
    delay_samples = delay_meta[4:0];
    gain_re = gain_re_meta;
    gain_im = gain_im_meta;
    temperature_q8_8 = temperature_meta;
    window_samples = pairs_meta;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    for (int index = 0; index < delay_meta; index++) begin
      @(negedge clk);
      ref_i = ref_i_data[index];
      ref_q = ref_q_data[index];
      ref_valid = 1'b1;
    end
    @(negedge clk);
    ref_valid = 1'b0;
    enable = 1'b1;
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;

    for (int index = 0; index < samples_meta; index++) begin
      ref_i = ref_i_data[index + delay_meta];
      ref_q = ref_q_data[index + delay_meta];
      ref_valid = 1'b1;
      obs_i = obs_i_data[index];
      obs_q = obs_q_data[index];
      obs_invalid = obs_invalid_data[index];
      obs_last = (index == samples_meta - 1);
      obs_valid = 1'b1;
      @(negedge clk);
    end
    ref_valid = 1'b0;
    obs_valid = 1'b0;
    obs_invalid = 1'b0;
    obs_last = 1'b0;
    repeat (3) @(posedge clk);

    if (!done || active || !last_seen) $fatal(1, "observer window state mismatch");
    if (paired_count != pairs_meta) $fatal(1, "pair mismatch: %0d", paired_count);
    if (dropped_count != drops_meta) $fatal(1, "drop mismatch: %0d", dropped_count);
    if (error_acc != error_meta) $fatal(1, "error mismatch got=%0d expected=%0d",
      error_acc, error_meta);
    if (latched_temperature_q8_8 != temperature_meta ||
        ref_mag_acc != ref_mag_meta || obs_mag_acc != obs_mag_meta ||
        obs_peak != peak_meta || clip_count != clip_meta ||
        saturation_count != saturation_meta || slew_acc != slew_meta ||
        spec_bin0 != spec_bin0_meta || spec_bin1 != spec_bin1_meta ||
        spec_bin2 != spec_bin2_meta || spec_adj != spec_adj_meta)
      $fatal(1, "observer monitor-statistics mismatch");
    $display("Behavioral PA observer PASS pairs=%0d drops=%0d error=%0d temp=%0d peak=%0d",
      paired_count, dropped_count, error_acc, latched_temperature_q8_8, obs_peak);
    $finish;
  end
endmodule

`default_nettype wire
