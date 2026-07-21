`timescale 1ns/1ps
`default_nettype none

module dpd_seed_predictor (
  input wire condition_valid,
  input wire [7:0] condition_version,
  input wire [15:0] qam_order,
  input wire [31:0] bandwidth_khz,
  input wire [31:0] backoff_ppm,
  input wire signed [15:0] power_q8_8,
  input wire signed [15:0] temperature_q8_8,
  input wire [31:0] monitor_state,
  output reg [2:0] seed_package,
  output reg condition_known,
  output wire fallback_required,
  output wire local_search_required
);

  reg [31:0] bandwidth_distance;
  reg [31:0] backoff_distance;
  wire qam_known = (qam_order == 16) || (qam_order == 64);
  wire power_known = (power_q8_8 >= -16'sd10240) && (power_q8_8 <= 16'sd10240);
  wire temperature_known = (temperature_q8_8 >= -16'sd10240) &&
                           (temperature_q8_8 <= 16'sd32000);
  wire monitor_fault = |monitor_state[3:0];

  assign fallback_required = !condition_known | monitor_fault;
  // The simulation-qualified policy always verifies a seed with 14 candidates.
  assign local_search_required = 1'b1;

  always @* begin
    bandwidth_distance = (bandwidth_khz > 32'd20000) ?
                         (bandwidth_khz - 32'd20000) :
                         (32'd20000 - bandwidth_khz);
    if (((bandwidth_khz > 32'd40000) ?
         (bandwidth_khz - 32'd40000) :
         (32'd40000 - bandwidth_khz)) < bandwidth_distance) begin
      bandwidth_distance = (bandwidth_khz > 32'd40000) ?
                           (bandwidth_khz - 32'd40000) :
                           (32'd40000 - bandwidth_khz);
    end
    backoff_distance = (backoff_ppm > 32'd580000) ?
                       (backoff_ppm - 32'd580000) :
                       (32'd580000 - backoff_ppm);
    seed_package = 3'd2;
    if (((backoff_ppm > 32'd700000) ?
         (backoff_ppm - 32'd700000) :
         (32'd700000 - backoff_ppm)) < backoff_distance) begin
      backoff_distance = (backoff_ppm > 32'd700000) ?
                         (backoff_ppm - 32'd700000) :
                         (32'd700000 - backoff_ppm);
      seed_package = 3'd5;
    end
    condition_known = condition_valid && (condition_version == 8'd1) &&
                      qam_known && (bandwidth_distance <= 32'd10000) &&
                      (backoff_distance <= 32'd100000) &&
                      power_known && temperature_known;
  end

endmodule

`default_nettype wire
