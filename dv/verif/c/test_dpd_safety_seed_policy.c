#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "dpd_safety_seed_policy.h"

int main(int argc, char **argv)
{
    char line[2048];
    char name[160];
    FILE *vectors;
    unsigned int count = 0U;

    if (argc != 2) {
        fprintf(stderr, "usage: %s VECTOR_FILE\n", argv[0]);
        return 2;
    }
    vectors = fopen(argv[1], "r");
    if (vectors == NULL || fgets(line, sizeof(line), vectors) == NULL) {
        fprintf(stderr, "cannot read vector file\n");
        return 2;
    }
    while (fgets(line, sizeof(line), vectors) != NULL) {
        dpd_tinyml_input_t input;
        dpd_safety_seed_result_t actual;
        unsigned int expected_package;
        unsigned int expected_qualified;
        unsigned int expected_support;
        uint64_t expected_distance;
        unsigned int valid;
        unsigned int index;
        int offset = 0;
        int consumed = 0;

        if (sscanf(line, "%159s %u%n", name, &valid, &consumed) != 2) {
            fprintf(stderr, "malformed vector: %s", line);
            return 2;
        }
        offset += consumed;
        input.valid = (uint8_t)valid;
        for (index = 0U; index < DPD_TINYML_FEATURE_COUNT; ++index) {
            if (sscanf(line + offset, " %" SCNd32 "%n", &input.feature_q20[index],
                       &consumed) != 1) {
                fprintf(stderr, "%s: missing feature %u\n", name, index);
                return 2;
            }
            offset += consumed;
        }
        if (sscanf(line + offset, " %u %u %u %" SCNu64, &expected_package,
                   &expected_qualified, &expected_support, &expected_distance) != 4) {
            fprintf(stderr, "%s: missing expected result\n", name);
            return 2;
        }
        actual = dpd_safety_seed_policy_predict(&input);
        if (actual.seed_package != expected_package ||
            actual.safety_qualified != expected_qualified ||
            actual.safe_support != expected_support ||
            actual.local_candidates != DPD_SAFETY_SEED_POLICY_LOCAL_CANDIDATES ||
            actual.nearest_distance_sq_q40 != expected_distance) {
            fprintf(stderr, "%s: expected %u/%u/%u/%" PRIu64 ", got %u/%u/%u/%" PRIu64 "\n",
                    name, expected_package, expected_qualified, expected_support,
                    expected_distance, actual.seed_package, actual.safety_qualified,
                    actual.safe_support, actual.nearest_distance_sq_q40);
            return 1;
        }
        ++count;
    }
    fclose(vectors);
    printf("C safety-first seed policy PASS: %u decisions\n", count);
    return count == 0U ? 1 : 0;
}
