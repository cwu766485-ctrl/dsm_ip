#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "dpd_tinyml_tree.h"

int main(int argc, char **argv) {
  char line[2048];
  char name[128];
  FILE *vectors;
  unsigned int count = 0;

  if (argc != 2) {
    fprintf(stderr, "usage: %s VECTOR_FILE\n", argv[0]);
    return 2;
  }
  vectors = fopen(argv[1], "r");
  if (vectors == NULL) {
    perror(argv[1]);
    return 2;
  }
  if (fgets(line, sizeof(line), vectors) == NULL) {
    fprintf(stderr, "empty vector file\n");
    fclose(vectors);
    return 2;
  }

  while (fgets(line, sizeof(line), vectors) != NULL) {
    dpd_tinyml_input_t input;
    dpd_tinyml_result_t actual;
    unsigned int expected_package;
    unsigned int expected_direct;
    unsigned int expected_path;
    unsigned int expected_path_length;
    unsigned int expected_ood;
    unsigned int valid;
    unsigned int index;
    int offset = 0;
    int consumed = 0;

    if (sscanf(line, "%127s %u%n", name, &valid, &consumed) != 2) {
      fprintf(stderr, "malformed vector line: %s", line);
      fclose(vectors);
      return 2;
    }
    offset += consumed;
    input.valid = (uint8_t)valid;
    for (index = 0; index < DPD_TINYML_FEATURE_COUNT; ++index) {
      if (sscanf(line + offset, " %" SCNd32 "%n",
                 &input.feature_q20[index], &consumed) != 1) {
        fprintf(stderr, "%s: missing feature %u\n", name, index);
        fclose(vectors);
        return 2;
      }
      offset += consumed;
    }
    if (sscanf(line + offset, " %u %u %u %u %u", &expected_package,
               &expected_direct, &expected_path, &expected_path_length,
               &expected_ood) != 5) {
      fprintf(stderr, "%s: missing expected result\n", name);
      fclose(vectors);
      return 2;
    }

    actual = dpd_tinyml_tree_predict(&input);
    if ((actual.seed_package != expected_package) ||
        (actual.direct != expected_direct) ||
        (actual.path != expected_path) ||
        (actual.path_length != expected_path_length) ||
        (actual.out_of_distribution != expected_ood)) {
      fprintf(stderr,
              "%s: expected %u/%u/%u/%u/%u, got %u/%u/%u/%u/%u\n",
              name, expected_package, expected_direct, expected_path,
              expected_path_length, expected_ood, actual.seed_package,
              actual.direct, actual.path, actual.path_length,
              actual.out_of_distribution);
      fclose(vectors);
      return 1;
    }
    ++count;
  }

  fclose(vectors);
  printf("C TinyML tree PASS: %u decisions\n", count);
  return count > 0u ? 0 : 1;
}
