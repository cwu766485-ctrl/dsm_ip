#ifndef DPD_TINYML_TREE_H
#define DPD_TINYML_TREE_H

#include <stdint.h>

#define DPD_TINYML_FEATURE_COUNT 13u
#define DPD_TINYML_MODEL_VERSION 0x00020000u
#define DPD_TINYML_FEATURE_SCHEMA_ALIGNED_COMPLEX_PA_MONITOR_V2 2u
#define DPD_TINYML_FALLBACK_PACKAGE 6u

typedef struct {
  int32_t feature_q20[DPD_TINYML_FEATURE_COUNT];
  uint8_t valid;
} dpd_tinyml_input_t;

typedef struct {
  uint32_t qam_order;
  uint32_t bandwidth_khz;
  uint32_t backoff_ppm;
  int32_t temperature_q8_8;
  uint32_t input_power;
  uint32_t output_power;
  uint32_t peak;
  uint32_t avg_mag;
  uint32_t evm_proxy;
  uint32_t acpr_proxy;
  uint32_t spec_bin0;
  uint32_t spec_bin1;
  uint32_t spec_bin2;
  uint32_t spec_adj;
  uint32_t clip_count;
  uint32_t saturation_count;
  uint32_t sample_count;
  uint64_t observation_error_l1;
  uint8_t valid;
} dpd_tinyml_raw_input_t;

typedef struct {
  uint8_t seed_package;
  uint8_t direct;
  uint8_t path;
  uint8_t path_length;
  uint8_t out_of_distribution;
} dpd_tinyml_result_t;

dpd_tinyml_result_t dpd_tinyml_tree_predict(const dpd_tinyml_input_t *input);
int dpd_tinyml_build_features(const dpd_tinyml_raw_input_t *raw,
                              dpd_tinyml_input_t *input);

#endif
