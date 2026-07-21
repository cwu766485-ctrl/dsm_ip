#include "dpd_tinyml_tree.h"

#include <limits.h>

#define Q20_SCALE 1048576u

static int32_t clamp_i64(int64_t value) {
  if (value > INT32_MAX) {
    return INT32_MAX;
  }
  if (value < INT32_MIN) {
    return INT32_MIN;
  }
  return (int32_t)value;
}

static int32_t ratio_u64_q20(uint64_t numerator, uint64_t denominator) {
  uint64_t rounded;

  if (denominator == 0u) {
    denominator = 1u;
  }
  if (numerator > (UINT64_MAX - denominator / 2u) / Q20_SCALE) {
    return INT32_MAX;
  }
  rounded = (numerator * Q20_SCALE + denominator / 2u) / denominator;
  return rounded > (uint64_t)INT32_MAX ? INT32_MAX : (int32_t)rounded;
}

static int32_t ratio_i64_q20(int64_t numerator, int64_t denominator) {
  uint64_t magnitude;
  uint64_t rounded;

  if (denominator <= 0) {
    return 0;
  }
  magnitude = numerator < 0 ? (uint64_t)(-(numerator + 1)) + 1u :
                              (uint64_t)numerator;
  if (magnitude > (UINT64_MAX - (uint64_t)denominator / 2u) / Q20_SCALE) {
    return numerator < 0 ? INT32_MIN : INT32_MAX;
  }
  rounded = (magnitude * Q20_SCALE + (uint64_t)denominator / 2u) /
            (uint64_t)denominator;
  return clamp_i64(numerator < 0 ? -(int64_t)rounded : (int64_t)rounded);
}

int dpd_tinyml_build_features(const dpd_tinyml_raw_input_t *raw,
                              dpd_tinyml_input_t *input) {
  if ((raw == 0) || (input == 0)) {
    return 0;
  }

  input->valid = (uint8_t)(raw->valid != 0u && raw->sample_count != 0u);
  input->feature_q20[0] = ratio_u64_q20(raw->qam_order, 64u);
  input->feature_q20[1] = ratio_u64_q20(raw->bandwidth_khz, 40000u);
  input->feature_q20[2] = ratio_u64_q20(raw->backoff_ppm, 1000000u);
  input->feature_q20[3] = ratio_i64_q20(raw->temperature_q8_8, 85 * 256);
  input->feature_q20[4] = ratio_u64_q20(raw->output_power, raw->input_power);
  input->feature_q20[5] = ratio_u64_q20(raw->peak, raw->avg_mag);
  input->feature_q20[6] = ratio_u64_q20(raw->evm_proxy, raw->input_power);
  input->feature_q20[7] = ratio_u64_q20(raw->acpr_proxy, raw->output_power);
  input->feature_q20[8] = ratio_u64_q20(raw->spec_adj, raw->spec_bin1);
  input->feature_q20[9] = ratio_u64_q20(raw->spec_bin2, raw->spec_bin0);
  input->feature_q20[10] = ratio_u64_q20(raw->clip_count, raw->sample_count);
  input->feature_q20[11] = ratio_u64_q20(raw->saturation_count, raw->sample_count);
  input->feature_q20[12] = ratio_u64_q20(raw->observation_error_l1,
                                         raw->input_power);
  return input->valid != 0u;
}
