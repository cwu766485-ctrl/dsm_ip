#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "dpd_tinyml_tree.h"

#define TOKEN_COUNT 38

static uint64_t parse_u64(const char *value) {
  return (uint64_t)strtoull(value, 0, 0);
}

static int64_t parse_i64(const char *value) {
  return (int64_t)strtoll(value, 0, 0);
}

int main(int argc, char **argv) {
  char line[4096];
  char *token[TOKEN_COUNT];
  FILE *vectors;
  unsigned int count = 0;

  if (argc != 2) {
    fprintf(stderr, "usage: %s VECTOR_FILE\n", argv[0]);
    return 2;
  }
  vectors = fopen(argv[1], "r");
  if (vectors == 0) {
    perror(argv[1]);
    return 2;
  }
  if (fgets(line, sizeof(line), vectors) == 0) {
    fclose(vectors);
    return 2;
  }

  while (fgets(line, sizeof(line), vectors) != 0) {
    dpd_tinyml_raw_input_t raw;
    dpd_tinyml_input_t input;
    dpd_tinyml_result_t result;
    char *cursor;
    unsigned int index = 0;
    unsigned int feature;
    unsigned int base;

    cursor = strtok(line, " \t\r\n");
    while ((cursor != 0) && (index < TOKEN_COUNT)) {
      token[index++] = cursor;
      cursor = strtok(0, " \t\r\n");
    }
    if ((index != TOKEN_COUNT) || (cursor != 0)) {
      fprintf(stderr, "malformed feature vector after %u rows: %u tokens\n",
              count, index);
      fclose(vectors);
      return 2;
    }

    raw.valid = (uint8_t)parse_u64(token[1]);
    raw.qam_order = (uint32_t)parse_u64(token[2]);
    raw.bandwidth_khz = (uint32_t)parse_u64(token[3]);
    raw.backoff_ppm = (uint32_t)parse_u64(token[4]);
    raw.temperature_q8_8 = (int32_t)parse_i64(token[5]);
    raw.input_power = (uint32_t)parse_u64(token[6]);
    raw.output_power = (uint32_t)parse_u64(token[7]);
    raw.peak = (uint32_t)parse_u64(token[8]);
    raw.avg_mag = (uint32_t)parse_u64(token[9]);
    raw.evm_proxy = (uint32_t)parse_u64(token[10]);
    raw.acpr_proxy = (uint32_t)parse_u64(token[11]);
    raw.spec_bin0 = (uint32_t)parse_u64(token[12]);
    raw.spec_bin1 = (uint32_t)parse_u64(token[13]);
    raw.spec_bin2 = (uint32_t)parse_u64(token[14]);
    raw.spec_adj = (uint32_t)parse_u64(token[15]);
    raw.clip_count = (uint32_t)parse_u64(token[16]);
    raw.saturation_count = (uint32_t)parse_u64(token[17]);
    raw.sample_count = (uint32_t)parse_u64(token[18]);
    raw.observation_error_l1 = parse_u64(token[19]);

    if (!dpd_tinyml_build_features(&raw, &input)) {
      fprintf(stderr, "%s: valid raw feature build failed\n", token[0]);
      fclose(vectors);
      return 1;
    }
    base = 20;
    for (feature = 0; feature < DPD_TINYML_FEATURE_COUNT; ++feature) {
      int32_t expected = (int32_t)parse_i64(token[base + feature]);
      if (input.feature_q20[feature] != expected) {
        fprintf(stderr, "%s: feature %u expected %d got %d\n", token[0],
                feature, expected, input.feature_q20[feature]);
        fclose(vectors);
        return 1;
      }
    }
    result = dpd_tinyml_tree_predict(&input);
    base += DPD_TINYML_FEATURE_COUNT;
    if ((result.seed_package != parse_u64(token[base])) ||
        (result.direct != parse_u64(token[base + 1])) ||
        (result.path != parse_u64(token[base + 2])) ||
        (result.path_length != parse_u64(token[base + 3])) ||
        (result.out_of_distribution != parse_u64(token[base + 4]))) {
      fprintf(stderr, "%s: end-to-end decision mismatch\n", token[0]);
      fclose(vectors);
      return 1;
    }
    ++count;
  }
  fclose(vectors);
  printf("C TinyML feature+tree PASS: %u decisions\n", count);
  return count == 288u ? 0 : 1;
}
