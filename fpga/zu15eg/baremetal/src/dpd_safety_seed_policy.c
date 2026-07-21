/* Fixed-point PS selector generated constants are kept in the matching header. */
#include "dpd_safety_seed_policy.h"

#include <limits.h>

#define Q20_SCALE 1048576ULL

static int32_t normalize_q20(int32_t value, int32_t center, int32_t scale)
{
    int64_t delta = (int64_t)value - (int64_t)center;
    uint64_t magnitude;

    if (scale <= 0) {
        return 0;
    }
    magnitude = (uint64_t)(delta < 0 ? -delta : delta);
    if (magnitude > (UINT64_MAX - (uint64_t)scale / 2U) / Q20_SCALE) {
        return delta < 0 ? INT32_MIN : INT32_MAX;
    }
    magnitude = (magnitude * Q20_SCALE + (uint64_t)scale / 2U) /
                (uint64_t)scale;
    if (magnitude > (uint64_t)INT32_MAX) {
        return delta < 0 ? INT32_MIN : INT32_MAX;
    }
    return delta < 0 ? -(int32_t)magnitude : (int32_t)magnitude;
}

static uint64_t squared_distance(const int32_t *left, const int32_t *right)
{
    uint64_t total = 0U;
    uint32_t index;

    for (index = 0U; index < DPD_TINYML_FEATURE_COUNT; ++index) {
        int64_t delta = (int64_t)left[index] - (int64_t)right[index];
        uint64_t magnitude = (uint64_t)(delta < 0 ? -delta : delta);
        uint64_t square;
        if (magnitude > 3037000499ULL) {
            return UINT64_MAX;
        }
        square = magnitude * magnitude;
        if (total > UINT64_MAX - square) {
            return UINT64_MAX;
        }
        total += square;
    }
    return total;
}

static int find_waveform(const dpd_tinyml_input_t *input)
{
    uint32_t waveform;
    for (waveform = 0U; waveform < DPD_SAFETY_SEED_POLICY_WAVEFORMS; ++waveform) {
        if (input->feature_q20[0] == dsm_dpd_safety_seed_waveform_q20[waveform][0] &&
            input->feature_q20[1] == dsm_dpd_safety_seed_waveform_q20[waveform][1] &&
            input->feature_q20[2] == dsm_dpd_safety_seed_waveform_q20[waveform][2]) {
            return (int)waveform;
        }
    }
    return -1;
}

dpd_safety_seed_result_t dpd_safety_seed_policy_predict(const dpd_tinyml_input_t *input)
{
    dpd_safety_seed_result_t result = {DPD_TINYML_FALLBACK_PACKAGE, 0U, 0U,
                                       DPD_SAFETY_SEED_POLICY_LOCAL_CANDIDATES, 0U};
    int32_t query[DPD_TINYML_FEATURE_COUNT];
    uint64_t nearest_distance[DPD_SAFETY_SEED_POLICY_K];
    uint32_t nearest_index[DPD_SAFETY_SEED_POLICY_K];
    int waveform;
    uint32_t index;
    uint32_t count = 0U;
    uint64_t best_cost = UINT64_MAX;

    if (input == 0 || input->valid == 0U) {
        return result;
    }
    waveform = find_waveform(input);
    if (waveform < 0) {
        return result;
    }
    for (index = 0U; index < DPD_TINYML_FEATURE_COUNT; ++index) {
        query[index] = normalize_q20(input->feature_q20[index],
                                     dsm_dpd_safety_seed_center_q20[index],
                                     dsm_dpd_safety_seed_scale_q20[index]);
    }
    for (index = 0U; index < DPD_SAFETY_SEED_POLICY_EVIDENCE_ROWS; ++index) {
        int32_t candidate[DPD_TINYML_FEATURE_COUNT];
        uint64_t distance;
        uint32_t position;
        if (dsm_dpd_safety_seed_evidence[index].waveform != (uint8_t)waveform) {
            continue;
        }
        for (position = 0U; position < DPD_TINYML_FEATURE_COUNT; ++position) {
            candidate[position] = normalize_q20(
                dsm_dpd_safety_seed_evidence[index].feature_q20[position],
                dsm_dpd_safety_seed_center_q20[position],
                dsm_dpd_safety_seed_scale_q20[position]);
        }
        distance = squared_distance(query, candidate);
        position = count < DPD_SAFETY_SEED_POLICY_K ? count : DPD_SAFETY_SEED_POLICY_K;
        while (position > 0U && distance < nearest_distance[position - 1U]) {
            if (position < DPD_SAFETY_SEED_POLICY_K) {
                nearest_distance[position] = nearest_distance[position - 1U];
                nearest_index[position] = nearest_index[position - 1U];
            }
            --position;
        }
        if (position < DPD_SAFETY_SEED_POLICY_K) {
            nearest_distance[position] = distance;
            nearest_index[position] = index;
        }
        ++count;
    }
    if (count < DPD_SAFETY_SEED_POLICY_K ||
        nearest_distance[0] > DPD_SAFETY_SEED_POLICY_MAX_DISTANCE_Q20 *
                              DPD_SAFETY_SEED_POLICY_MAX_DISTANCE_Q20) {
        return result;
    }
    result.nearest_distance_sq_q40 = nearest_distance[0];
    for (index = 0U; index < 6U; ++index) {
        uint64_t cost = 0U;
        uint32_t neighbor;
        uint8_t safe = 1U;
        for (neighbor = 0U; neighbor < DPD_SAFETY_SEED_POLICY_K; ++neighbor) {
            const dpd_safety_seed_evidence_t *row =
                &dsm_dpd_safety_seed_evidence[nearest_index[neighbor]];
            if (row->safe[index] == 0U) {
                safe = 0U;
                break;
            }
            if (cost > UINT64_MAX - row->cost[index]) {
                safe = 0U;
                break;
            }
            cost += row->cost[index];
        }
        if (safe != 0U && cost < best_cost) {
            result.seed_package = (uint8_t)index;
            result.safety_qualified = 1U;
            result.safe_support = DPD_SAFETY_SEED_POLICY_K;
            best_cost = cost;
        }
    }
    if (result.safety_qualified != 0U) {
        /* Restore the diagnostic distance after cost-only package ranking. */
        result.nearest_distance_sq_q40 = nearest_distance[0];
    }
    return result;
}
