#include <stddef.h>

#include "xaxidma.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xparameters.h"

#if __has_include("dpd_coeffs.h")
#include "dpd_coeffs.h"
#else
#define DSM_DPD_C1_WORD 0xFFFB4009U
#define DSM_DPD_C3_WORD 0xF1A41F6FU
#define DSM_DPD_C5_WORD 0xDE503A39U
#define DSM_DPD_LUT_LEN 16U
#define DSM_DPD_NUM_PACKAGES 1U
static const u32 dsm_dpd_lut_words[DSM_DPD_LUT_LEN] = {
    0x00004000U, 0x00004000U, 0x00004000U, 0x00004000U,
    0x00004000U, 0x00004000U, 0x00004000U, 0x00004000U,
    0x00004000U, 0x00004000U, 0x00004000U, 0x00004000U,
    0x00004000U, 0x00004000U, 0x00004000U, 0x00004000U
};
static const u32 dsm_dpd_c1_words[DSM_DPD_NUM_PACKAGES] = { DSM_DPD_C1_WORD };
static const u32 dsm_dpd_c3_words[DSM_DPD_NUM_PACKAGES] = { DSM_DPD_C3_WORD };
static const u32 dsm_dpd_c5_words[DSM_DPD_NUM_PACKAGES] = { DSM_DPD_C5_WORD };
static const char *const dsm_dpd_package_names[DSM_DPD_NUM_PACKAGES] = {
    "fallback"
};
static const u32 dsm_dpd_poly_evm_ppm[DSM_DPD_NUM_PACKAGES] = { 0U };
static const u32 dsm_dpd_lut_evm_ppm[DSM_DPD_NUM_PACKAGES] = { 0U };
static const u32 dsm_dpd_poly_sndr_mdB[DSM_DPD_NUM_PACKAGES] = { 0U };
static const u32 dsm_dpd_lut_sndr_mdB[DSM_DPD_NUM_PACKAGES] = { 0U };
static const u32 dsm_dpd_lut_packages[DSM_DPD_NUM_PACKAGES][DSM_DPD_LUT_LEN] = {
    {
        0x00004000U, 0x00004000U, 0x00004000U, 0x00004000U,
        0x00004000U, 0x00004000U, 0x00004000U, 0x00004000U,
        0x00004000U, 0x00004000U, 0x00004000U, 0x00004000U,
        0x00004000U, 0x00004000U, 0x00004000U, 0x00004000U
    }
};
#endif

#if __has_include("cal_config.h")
#include "cal_config.h"
#endif

#if __has_include("dpd_seed.h")
#include "dpd_seed.h"
#endif

#if __has_include("dpd_trace_policy.h")
#include "dpd_trace_policy.h"
#endif

#if __has_include("dpd_tx_waveform.h")
#include "dpd_tx_waveform.h"
#endif

#if __has_include("dpd_ai_policy.h")
#include "dpd_ai_policy.h"
#endif

#if __has_include("dpd_tinyml_hierarchy_policy.h")
#include "dpd_tinyml_hierarchy_policy.h"
#endif

#if __has_include("dpd_tinyml_lut_v2.h")
#include "dpd_tinyml_lut_v2.h"
#endif

#if __has_include("dpd_tinyml_packages_v2.h")
#include "dpd_tinyml_packages_v2.h"
#endif

#if __has_include("dpd_tinyml_tree.h")
#include "dpd_tinyml_tree.h"
#endif

#if __has_include("dpd_safety_seed_policy.h")
#include "dpd_safety_seed_policy.h"
#endif

#ifndef DSM_DPD_SEED_AVAILABLE
#define DSM_DPD_SEED_AVAILABLE 0U
#endif
#ifndef DSM_DPD_SEED_PACKAGE_IDX
#define DSM_DPD_SEED_PACKAGE_IDX 0U
#endif
#ifndef DSM_DPD_SEED_C1_WORD
#define DSM_DPD_SEED_C1_WORD DSM_DPD_C1_WORD
#endif
#ifndef DSM_DPD_SEED_C3_WORD
#define DSM_DPD_SEED_C3_WORD DSM_DPD_C3_WORD
#endif
#ifndef DSM_DPD_SEED_C5_WORD
#define DSM_DPD_SEED_C5_WORD DSM_DPD_C5_WORD
#endif
#ifndef DSM_DPD_TRACE_POLICY_AVAILABLE
#define DSM_DPD_TRACE_POLICY_AVAILABLE 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MODE
#define DSM_DPD_TRACE_POLICY_MODE DPD_MODE_LUT
#endif
#ifndef DSM_DPD_TRACE_POLICY_PACKAGE_IDX
#define DSM_DPD_TRACE_POLICY_PACKAGE_IDX 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_PREDICTED_COST
#define DSM_DPD_TRACE_POLICY_PREDICTED_COST 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_NEAREST_DISTANCE_PPM
#define DSM_DPD_TRACE_POLICY_NEAREST_DISTANCE_PPM 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_COST_STDDEV
#define DSM_DPD_TRACE_POLICY_COST_STDDEV 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_REL_STDDEV_PPM
#define DSM_DPD_TRACE_POLICY_REL_STDDEV_PPM 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MAX_DISTANCE_PPM
#define DSM_DPD_TRACE_POLICY_MAX_DISTANCE_PPM 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MAX_REL_STDDEV_PPM
#define DSM_DPD_TRACE_POLICY_MAX_REL_STDDEV_PPM 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MAX_RUNTIME_RESIDUAL_PPM
#define DSM_DPD_TRACE_POLICY_MAX_RUNTIME_RESIDUAL_PPM 150000U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MONITOR_AVAILABLE
#define DSM_DPD_TRACE_POLICY_MONITOR_AVAILABLE 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MAX_MONITOR_DISTANCE_PPM
#define DSM_DPD_TRACE_POLICY_MAX_MONITOR_DISTANCE_PPM 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MON_INPUT_POWER
#define DSM_DPD_TRACE_POLICY_MON_INPUT_POWER 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MON_OUTPUT_POWER
#define DSM_DPD_TRACE_POLICY_MON_OUTPUT_POWER 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MON_PEAK
#define DSM_DPD_TRACE_POLICY_MON_PEAK 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MON_AVG_MAG
#define DSM_DPD_TRACE_POLICY_MON_AVG_MAG 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MON_EVM_PROXY
#define DSM_DPD_TRACE_POLICY_MON_EVM_PROXY 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MON_ACPR_PROXY
#define DSM_DPD_TRACE_POLICY_MON_ACPR_PROXY 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MON_SPEC_BIN0
#define DSM_DPD_TRACE_POLICY_MON_SPEC_BIN0 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MON_SPEC_BIN1
#define DSM_DPD_TRACE_POLICY_MON_SPEC_BIN1 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MON_SPEC_BIN2
#define DSM_DPD_TRACE_POLICY_MON_SPEC_BIN2 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MON_SPEC_ADJ
#define DSM_DPD_TRACE_POLICY_MON_SPEC_ADJ 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MON_CLIP
#define DSM_DPD_TRACE_POLICY_MON_CLIP 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_MON_SATURATION
#define DSM_DPD_TRACE_POLICY_MON_SATURATION 0U
#endif
#ifndef DSM_DPD_TRACE_POLICY_DIRECT
#define DSM_DPD_TRACE_POLICY_DIRECT 1U
#endif
#ifndef DSM_DPD_TRACE_POLICY_FALLBACK_ROUNDS
#define DSM_DPD_TRACE_POLICY_FALLBACK_ROUNDS 1U
#endif
#ifndef DSM_DPD_TRACE_POLICY_FALLBACK_INITIAL_STEP
#define DSM_DPD_TRACE_POLICY_FALLBACK_INITIAL_STEP 64
#endif
#ifndef DSM_DPD_AI_POLICY_AVAILABLE
#define DSM_DPD_AI_POLICY_AVAILABLE 0U
#endif
#ifndef DSM_DPD_AI_POLICY_DIRECT_ALLOWED
#define DSM_DPD_AI_POLICY_DIRECT_ALLOWED 0U
#endif
#ifndef DSM_DPD_AI_POLICY_FORCE_LOCAL_SEARCH
#define DSM_DPD_AI_POLICY_FORCE_LOCAL_SEARCH 1U
#endif
#ifndef DSM_DPD_AI_POLICY_LOCAL_ROUNDS
#define DSM_DPD_AI_POLICY_LOCAL_ROUNDS 1U
#endif
#ifndef DSM_DPD_AI_POLICY_LOCAL_STEP_Q214
#define DSM_DPD_AI_POLICY_LOCAL_STEP_Q214 64
#endif
#ifndef DSM_DPD_TX_WAVEFORM_AVAILABLE
#define DSM_DPD_TX_WAVEFORM_AVAILABLE 0U
#endif
#ifndef DPD_TINYML_HIERARCHY_POLICY_AVAILABLE
#define DPD_TINYML_HIERARCHY_POLICY_AVAILABLE 0U
#endif
#ifndef DPD_TINYML_HIERARCHY_POLICY_DIRECT_ALLOWED
#define DPD_TINYML_HIERARCHY_POLICY_DIRECT_ALLOWED 0U
#endif
#ifndef DPD_TINYML_HIERARCHY_POLICY_LOCAL_CANDIDATES
#define DPD_TINYML_HIERARCHY_POLICY_LOCAL_CANDIDATES 14U
#endif
#ifndef DPD_TINYML_HIERARCHY_POLICY_ACTIVE_TAPS
#define DPD_TINYML_HIERARCHY_POLICY_ACTIVE_TAPS 4U
#endif
#ifndef DPD_TINYML_LUT_V2_AVAILABLE
#define DPD_TINYML_LUT_V2_AVAILABLE 0U
#endif
#ifndef DPD_TINYML_PACKAGE_TABLE_V2_AVAILABLE
#define DPD_TINYML_PACKAGE_TABLE_V2_AVAILABLE 0U
#endif
#ifndef DPD_SAFETY_SEED_POLICY_CONSTANTS_AVAILABLE
#define DPD_SAFETY_SEED_POLICY_CONSTANTS_AVAILABLE 0U
#endif
#ifndef DPD_SAFETY_SEED_POLICY_BOARD_ENABLE_ALLOWED
#define DPD_SAFETY_SEED_POLICY_BOARD_ENABLE_ALLOWED 0U
#endif
#ifndef DPD_SAFETY_SEED_POLICY_DIRECT_ALLOWED
#define DPD_SAFETY_SEED_POLICY_DIRECT_ALLOWED 0U
#endif
#ifndef DPD_SAFETY_SEED_POLICY_LOCAL_CANDIDATES
#define DPD_SAFETY_SEED_POLICY_LOCAL_CANDIDATES 14U
#endif

#ifndef DSM_BASEADDR
#define DSM_BASEADDR 0xA0010000U
#endif

#ifndef DMA_DEV_ID
#if defined(XPAR_AXIDMA_0_DEVICE_ID)
#define DMA_DEV_ID XPAR_AXIDMA_0_DEVICE_ID
#elif defined(XPAR_XAXIDMA_0_BASEADDR)
#define DMA_DEV_ID XPAR_XAXIDMA_0_BASEADDR
#elif defined(XPAR_AXI_DMA_0_BASEADDR)
#define DMA_DEV_ID XPAR_AXI_DMA_0_BASEADDR
#else
#error "No AXI DMA device identifier or base address macro found in xparameters.h"
#endif
#endif

#define DMA_BYTES 0x00004000U
#define DMA_WORDS (DMA_BYTES / 4U)

#if DSM_DPD_TX_WAVEFORM_AVAILABLE && (DSM_DPD_TX_WAVEFORM_WORDS != DMA_WORDS)
#error "Generated DPD TX waveform length must match the fixed DMA transfer length"
#endif

#define DSM_CTRL                  0x00U
#define DSM_VERSION               0x14U
#define DSM_INPUT_SAMPLE_COUNT    0x18U
#define DSM_OUTPUT_SAMPLE_COUNT   0x1CU
#define DSM_ERROR_STATUS          0x24U
#define DSM_FRONTEND_SAMPLE_COUNT 0x28U
#define DSM_INPUT_STALL_COUNT     0x2CU
#define DSM_INTERP_MODE           0x30U
#define DSM_DPD_CTRL              0x40U
#define DSM_DPD_C1                0x44U
#define DSM_DPD_C3                0x48U
#define DSM_DPD_C5                0x4CU
#define DSM_DPD_SAMPLE_COUNT      0x50U
#define DSM_DPD_SATURATION_COUNT  0x54U
#define DSM_DPD_LUT_ADDR          0x58U
#define DSM_DPD_LUT_DATA          0x5CU
#define DSM_DPD_LUT_COMMIT        0x60U
#define DSM_MON_INPUT_POWER       0x64U
#define DSM_MON_OUTPUT_POWER      0x68U
#define DSM_MON_CLIP_COUNT        0x6CU
#define DSM_MON_PEAK              0x70U
#define DSM_MON_AVG_MAG           0x74U
#define DSM_MON_EVM_PROXY         0x78U
#define DSM_MON_ACPR_PROXY        0x7CU
#define DSM_MON_SPEC_BIN0         0x80U
#define DSM_MON_SPEC_BIN1         0x84U
#define DSM_MON_SPEC_BIN2         0x88U
#define DSM_MON_SPEC_ADJ          0x8CU
#define DSM_CONDITION_CTRL        0xBCU
#define DSM_CONDITION_QAM         0xC0U
#define DSM_CONDITION_BW_KHZ      0xC4U
#define DSM_CONDITION_BACKOFF     0xC8U
#define DSM_CONDITION_ENV         0xCCU
#define DSM_CONDITION_MONITOR     0xD0U
#define DSM_SEED_STATUS           0xD4U
#define DSM_OBS_ENV                0xD8U
#define DSM_OBS_REF_MAG            0xDCU
#define DSM_OBS_MAG                0xE0U
#define DSM_OBS_PEAK               0xE4U
#define DSM_OBS_CLIP_SAT           0xE8U
#define DSM_OBS_SLEW               0xECU
#define DSM_OBS_SPEC_BIN0          0xF0U
#define DSM_OBS_SPEC_BIN1          0xF4U
#define DSM_OBS_SPEC_BIN2          0xF8U
#define DSM_OBS_SPEC_ADJ           0xFCU
#define DSM_OBS_CTRL               0x9CU
#define DSM_OBS_STATUS             0xA8U
#define DSM_OBS_PAIR_COUNT         0xACU
#define DSM_OBS_ERROR_LO           0xB4U
#define DSM_OBS_ERROR_HI           0xB8U
#define DSM_MP_SELECT              0x90U
#define DSM_MP_DATA                0x94U
#define DSM_MP_COMMIT              0x98U

#define DPD_MODE_BYPASS 0U
#define DPD_MODE_POLY   1U
#define DPD_MODE_LUT    2U
#define DPD_MODE_MEMORY 3U

#ifndef CAL_WEIGHT_PROXY_EVM
#define CAL_WEIGHT_PROXY_EVM   1U
#endif
#ifndef CAL_PENALTY_SATURATION
#define CAL_PENALTY_SATURATION 1000000U
#endif
#ifndef CAL_PENALTY_ERROR
#define CAL_PENALTY_ERROR      1000000U
#endif
#ifndef CAL_PENALTY_STALL
#define CAL_PENALTY_STALL      100000U
#endif
#ifndef CAL_PENALTY_CLIP
#define CAL_PENALTY_CLIP       1000000U
#endif
#ifndef CAL_EVM_PROXY_SHIFT
#define CAL_EVM_PROXY_SHIFT    8U
#endif
#ifndef CAL_ACPR_PROXY_SHIFT
#define CAL_ACPR_PROXY_SHIFT   10U
#endif
#ifndef CAL_SPEC_ADJ_SHIFT
#define CAL_SPEC_ADJ_SHIFT     10U
#endif

#ifndef CAL_SEARCH_INITIAL_STEP_Q214
#define CAL_SEARCH_INITIAL_STEP_Q214 128
#endif
#ifndef CAL_SEARCH_MIN_STEP_Q214
#define CAL_SEARCH_MIN_STEP_Q214     16
#endif
#ifndef CAL_SEARCH_MAX_ROUNDS
#define CAL_SEARCH_MAX_ROUNDS        3U
#endif
#ifndef CAL_REPLAY_ONLY
#define CAL_REPLAY_ONLY              0U
#endif
#ifndef CAL_REPLAY_MODE
#define CAL_REPLAY_MODE              DPD_MODE_LUT
#endif
#ifndef CAL_REPLAY_PACKAGE_IDX
#define CAL_REPLAY_PACKAGE_IDX       0U
#endif
#ifndef CAL_REPLAY_USE_WORDS
#define CAL_REPLAY_USE_WORDS         0U
#endif
#ifndef CAL_REPLAY_C1_WORD
#define CAL_REPLAY_C1_WORD           DSM_DPD_C1_WORD
#endif
#ifndef CAL_REPLAY_C3_WORD
#define CAL_REPLAY_C3_WORD           DSM_DPD_C3_WORD
#endif
#ifndef CAL_REPLAY_C5_WORD
#define CAL_REPLAY_C5_WORD           DSM_DPD_C5_WORD
#endif
#ifndef CAL_USE_SOFTWARE_SEED
#define CAL_USE_SOFTWARE_SEED         1U
#endif
#ifndef CAL_TRACE_POLICY_ONLY
#define CAL_TRACE_POLICY_ONLY         0U
#endif
#ifndef CAL_FORCE_POLICY_LOCAL_SEARCH
#define CAL_FORCE_POLICY_LOCAL_SEARCH 0U
#endif
#ifndef CAL_AI_POLICY_ONLY
#define CAL_AI_POLICY_ONLY            0U
#endif
#ifndef CAL_TINYML_HIERARCHY_ONLY
#define CAL_TINYML_HIERARCHY_ONLY      0U
#endif
#ifndef CAL_SAFETY_SEED_POLICY_ONLY
#define CAL_SAFETY_SEED_POLICY_ONLY     0U
#endif

typedef struct {
    u32 mode;
    u32 package_idx;
    u32 c1_word;
    u32 c3_word;
    u32 c5_word;
    u32 searched;
    u32 proxy_evm_ppm;
    u32 proxy_sndr_mdB;
    u32 input_power;
    u32 output_power;
    u32 saturation_count;
    u32 clip_count;
    u32 error_status;
    u32 stall_count;
    u32 peak_word;
    u32 avg_mag_word;
    u32 evm_proxy;
    u32 acpr_proxy;
    u32 spec_bin0_proxy;
    u32 spec_bin1_proxy;
    u32 spec_bin2_proxy;
    u32 spec_adj_proxy;
    u32 cost;
} CalibrationResult;

#define CAL_TRACE_MAGIC       0x43414C54U
#define CAL_TRACE_VERSION     0x00010000U
#define CAL_TRACE_CAPACITY    64U
#define CAL_TRACE_STAGE_SEED  1U
#define CAL_TRACE_STAGE_PKG   2U
#define CAL_TRACE_STAGE_SEARCH 3U
#define CAL_TRACE_STAGE_REPLAY 4U
#define CAL_TRACE_STAGE_FINAL 5U
#define CAL_TRACE_STAGE_POLICY 6U
#define CAL_TRACE_DECISION_ACCEPT 1U
#define CAL_TRACE_DECISION_REJECT 2U
#define CAL_TRACE_DECISION_SELECTED 3U
#define CAL_TRACE_REASON_BEST 1U
#define CAL_TRACE_REASON_NOT_BEST 2U
#define CAL_TRACE_REASON_LOWER_COST 3U
#define CAL_TRACE_REASON_NOT_LOWER 4U
#define CAL_TRACE_REASON_FIXED_REPLAY 5U
#define CAL_TRACE_REASON_FINAL_REPLAY 6U
#define CAL_TRACE_REASON_POLICY_REPLAY 7U

typedef struct {
    u32 candidate_id;
    u32 round;
    u32 stage;
    u32 decision;
    u32 reason;
    u32 mode;
    u32 package_idx;
    u32 searched;
    u32 c1_word;
    u32 c3_word;
    u32 c5_word;
    u32 proxy_evm_ppm;
    u32 proxy_sndr_mdB;
    u32 input_power;
    u32 output_power;
    u32 saturation_count;
    u32 clip_count;
    u32 error_status;
    u32 stall_count;
    u32 peak_word;
    u32 avg_mag_word;
    u32 evm_proxy;
    u32 acpr_proxy;
    u32 spec_bin0_proxy;
    u32 spec_bin1_proxy;
    u32 spec_bin2_proxy;
    u32 spec_adj_proxy;
    u32 cost;
} CalibrationTraceRecord;

typedef struct {
    u32 magic;
    u32 version;
    u32 header_size;
    u32 record_size;
    u32 capacity;
    u32 count;
    u32 complete;
    u32 overflow;
    CalibrationTraceRecord records[CAL_TRACE_CAPACITY];
} CalibrationTraceBuffer;

/* Global symbol is resolved from the ELF by the XSDB capture wrapper. */
CalibrationTraceBuffer g_cal_trace_buffer __attribute__((aligned(64)));

static u32 g_candidate_id = 0U;

static XAxiDma AxiDma;
static u32 TxBuffer[DMA_WORDS] __attribute__((aligned(64)));

static int check_counters(void);
static u32 perturb_coeff_word(u32 word, u32 upper, int delta);
static int run_stream(void);
static u32 calibration_cost(u32 proxy_evm_ppm, u32 saturation_count,
                            u32 clip_count, u32 error_status,
                            u32 stall_count, u32 evm_proxy,
                            u32 acpr_proxy, u32 spec_adj_proxy);

static inline u32 dsm_read(u32 offset)
{
    return Xil_In32(DSM_BASEADDR + offset);
}

static inline void dsm_write(u32 offset, u32 value)
{
    Xil_Out32(DSM_BASEADDR + offset, value);
}

static void publish_runtime_condition(void)
{
    u32 qam = 16U;
    u32 bandwidth_khz = 20000U;
    u32 backoff_ppm = 580000U;
    u32 monitor_state = 0U;
#if DSM_DPD_TX_WAVEFORM_AVAILABLE
    qam = DSM_DPD_TX_WAVEFORM_QAM;
    bandwidth_khz = (DSM_DPD_TX_WAVEFORM_USED_SUBCARRIERS > 48U) ?
                    40000U : 20000U;
    backoff_ppm = DSM_DPD_TX_WAVEFORM_INPUT_BACKOFF_PPM;
#endif
    if (dsm_read(DSM_ERROR_STATUS) != 0U ||
        dsm_read(DSM_MON_CLIP_COUNT) != 0U ||
        dsm_read(DSM_DPD_SATURATION_COUNT) != 0U) {
        monitor_state = 1U;
    }
    dsm_write(DSM_CONDITION_QAM, qam);
    dsm_write(DSM_CONDITION_BW_KHZ, bandwidth_khz);
    dsm_write(DSM_CONDITION_BACKOFF, backoff_ppm);
    dsm_write(DSM_CONDITION_ENV, (6400U << 16)); /* 25 C, 0 dB in Q8.8. */
    dsm_write(DSM_CONDITION_MONITOR, monitor_state);
    dsm_write(DSM_CONDITION_CTRL, 0x00000101U);
    xil_printf("PL_SEED_STATUS        = 0x%08x\r\n", dsm_read(DSM_SEED_STATUS));
}

static void calibration_trace_init(void)
{
    g_cal_trace_buffer.magic = CAL_TRACE_MAGIC;
    g_cal_trace_buffer.version = CAL_TRACE_VERSION;
    g_cal_trace_buffer.header_size = (u32)offsetof(CalibrationTraceBuffer, records);
    g_cal_trace_buffer.record_size = (u32)sizeof(CalibrationTraceRecord);
    g_cal_trace_buffer.capacity = CAL_TRACE_CAPACITY;
    g_cal_trace_buffer.count = 0U;
    g_cal_trace_buffer.complete = 0U;
    g_cal_trace_buffer.overflow = 0U;
    Xil_DCacheFlushRange((UINTPTR)&g_cal_trace_buffer, sizeof(g_cal_trace_buffer));
}

static u32 calibration_trace_stage(const char *stage)
{
    if (stage[0] == 's' && stage[1] == 'o') return CAL_TRACE_STAGE_SEED;
    if (stage[0] == 'p' && stage[1] == 'o') return CAL_TRACE_STAGE_POLICY;
    if (stage[0] == 'p') return CAL_TRACE_STAGE_PKG;
    if (stage[0] == 's') return CAL_TRACE_STAGE_SEARCH;
    if (stage[0] == 'r') return CAL_TRACE_STAGE_REPLAY;
    return CAL_TRACE_STAGE_FINAL;
}

static u32 calibration_trace_decision(const char *decision)
{
    if (decision[0] == 'a') return CAL_TRACE_DECISION_ACCEPT;
    if (decision[0] == 'r') return CAL_TRACE_DECISION_REJECT;
    return CAL_TRACE_DECISION_SELECTED;
}

static u32 calibration_trace_reason(const char *reason)
{
    if (reason[0] == 'b') return CAL_TRACE_REASON_BEST;
    if (reason[0] == 'n' && reason[4] == 'b') return CAL_TRACE_REASON_NOT_BEST;
    if (reason[0] == 'l') return CAL_TRACE_REASON_LOWER_COST;
    if (reason[0] == 'n') return CAL_TRACE_REASON_NOT_LOWER;
    if (reason[0] == 'f' && reason[2] == 'x') return CAL_TRACE_REASON_FIXED_REPLAY;
    if (reason[0] == 'p') return CAL_TRACE_REASON_POLICY_REPLAY;
    return CAL_TRACE_REASON_FINAL_REPLAY;
}

static void calibration_trace_store(const char *stage, u32 round,
                                    const CalibrationResult *result,
                                    const char *decision, const char *reason)
{
    u32 index = g_cal_trace_buffer.count;
    if (index >= CAL_TRACE_CAPACITY) {
        g_cal_trace_buffer.overflow = 1U;
        Xil_DCacheFlushRange((UINTPTR)&g_cal_trace_buffer, g_cal_trace_buffer.header_size);
        return;
    }

    CalibrationTraceRecord *record = &g_cal_trace_buffer.records[index];
    record->candidate_id = g_candidate_id;
    record->round = round;
    record->stage = calibration_trace_stage(stage);
    record->decision = calibration_trace_decision(decision);
    record->reason = calibration_trace_reason(reason);
    record->mode = result->mode;
    record->package_idx = result->package_idx;
    record->searched = result->searched;
    record->c1_word = result->c1_word;
    record->c3_word = result->c3_word;
    record->c5_word = result->c5_word;
    record->proxy_evm_ppm = result->proxy_evm_ppm;
    record->proxy_sndr_mdB = result->proxy_sndr_mdB;
    record->input_power = result->input_power;
    record->output_power = result->output_power;
    record->saturation_count = result->saturation_count;
    record->clip_count = result->clip_count;
    record->error_status = result->error_status;
    record->stall_count = result->stall_count;
    record->peak_word = result->peak_word;
    record->avg_mag_word = result->avg_mag_word;
    record->evm_proxy = result->evm_proxy;
    record->acpr_proxy = result->acpr_proxy;
    record->spec_bin0_proxy = result->spec_bin0_proxy;
    record->spec_bin1_proxy = result->spec_bin1_proxy;
    record->spec_bin2_proxy = result->spec_bin2_proxy;
    record->spec_adj_proxy = result->spec_adj_proxy;
    record->cost = result->cost;
    Xil_DCacheFlushRange((UINTPTR)record, sizeof(*record));
    g_cal_trace_buffer.count = index + 1U;
    Xil_DCacheFlushRange((UINTPTR)&g_cal_trace_buffer, g_cal_trace_buffer.header_size);
}

static void calibration_trace_complete(void)
{
    g_cal_trace_buffer.complete = 1U;
    Xil_DCacheFlushRange((UINTPTR)&g_cal_trace_buffer, g_cal_trace_buffer.header_size);
}

static int expect_eq(const char *name, u32 got, u32 expected)
{
    if (got != expected) {
        xil_printf("FAIL %s got=0x%08x expected=0x%08x\r\n",
                   name, got, expected);
        return XST_FAILURE;
    }
    xil_printf("PASS %s = 0x%08x\r\n", name, got);
    return XST_SUCCESS;
}

static void fill_iq_vector(void)
{
#if DSM_DPD_TX_WAVEFORM_AVAILABLE
    for (u32 n = 0; n < DMA_WORDS; n++) {
        TxBuffer[n] = dsm_dpd_tx_waveform_words[n];
    }
#else
    for (u32 n = 0; n < DMA_WORDS; n++) {
        s16 i = (s16)((n * 97U) & 0x7FFFU);
        s16 q = (s16)(((n * 193U) + 0x1000U) & 0x7FFFU);
        if ((n & 1U) != 0U) {
            i = (s16)-i;
        }
        if ((n & 2U) != 0U) {
            q = (s16)-q;
        }
        TxBuffer[n] = ((u32)(u16)q << 16) | (u32)(u16)i;
    }
#endif
    Xil_DCacheFlushRange((UINTPTR)TxBuffer, DMA_BYTES);
}

static int setup_dma(void)
{
    XAxiDma_Config *cfg = XAxiDma_LookupConfig(DMA_DEV_ID);
    if (cfg == NULL) {
        xil_printf("FAIL XAxiDma_LookupConfig\r\n");
        return XST_FAILURE;
    }
    int status = XAxiDma_CfgInitialize(&AxiDma, cfg);
    if (status != XST_SUCCESS) {
        xil_printf("FAIL XAxiDma_CfgInitialize status=%d\r\n", status);
        return status;
    }
    if (XAxiDma_HasSg(&AxiDma)) {
        xil_printf("FAIL AXI DMA is configured in scatter-gather mode\r\n");
        return XST_FAILURE;
    }
    XAxiDma_Reset(&AxiDma);
    while (!XAxiDma_ResetIsDone(&AxiDma)) {
    }
    return XST_SUCCESS;
}

static int configure_dpd(u32 mode, u32 package_idx)
{
    const u32 pkg = (package_idx < DSM_DPD_NUM_PACKAGES) ? package_idx : 0U;

    dsm_write(DSM_DPD_CTRL, DPD_MODE_BYPASS);

    if (mode == DPD_MODE_POLY) {
        dsm_write(DSM_DPD_C1, dsm_dpd_c1_words[pkg]);
        dsm_write(DSM_DPD_C3, dsm_dpd_c3_words[pkg]);
        dsm_write(DSM_DPD_C5, dsm_dpd_c5_words[pkg]);
        if (expect_eq("DPD_C1", dsm_read(DSM_DPD_C1), dsm_dpd_c1_words[pkg]) != XST_SUCCESS) return XST_FAILURE;
        if (expect_eq("DPD_C3", dsm_read(DSM_DPD_C3), dsm_dpd_c3_words[pkg]) != XST_SUCCESS) return XST_FAILURE;
        if (expect_eq("DPD_C5", dsm_read(DSM_DPD_C5), dsm_dpd_c5_words[pkg]) != XST_SUCCESS) return XST_FAILURE;
    } else if (mode == DPD_MODE_LUT) {
        for (u32 k = 0; k < DSM_DPD_LUT_LEN; k++) {
            dsm_write(DSM_DPD_LUT_ADDR, k);
            dsm_write(DSM_DPD_LUT_DATA, dsm_dpd_lut_packages[pkg][k]);
        }
        dsm_write(DSM_DPD_LUT_ADDR, 0U);
        if (expect_eq("DPD_LUT0", dsm_read(DSM_DPD_LUT_DATA), dsm_dpd_lut_packages[pkg][0]) != XST_SUCCESS) return XST_FAILURE;
        dsm_write(DSM_DPD_LUT_ADDR, DSM_DPD_LUT_LEN - 1U);
        if (expect_eq("DPD_LUT_LAST", dsm_read(DSM_DPD_LUT_DATA), dsm_dpd_lut_packages[pkg][DSM_DPD_LUT_LEN - 1U]) != XST_SUCCESS) return XST_FAILURE;
        dsm_write(DSM_DPD_LUT_COMMIT, 0x00000001U);
        xil_printf("DPD_LUT_ACTIVE_BANK = 0x%08x\r\n", dsm_read(DSM_DPD_LUT_COMMIT));
    } else if (mode != DPD_MODE_BYPASS) {
        xil_printf("FAIL unsupported DPD mode %d\r\n", (int)mode);
        return XST_FAILURE;
    }

    dsm_write(DSM_DPD_CTRL, mode);
    return expect_eq("DPD_CTRL", dsm_read(DSM_DPD_CTRL), mode);
}

static u32 clamp_i16_to_u16(int v)
{
    if (v > 32767) {
        return 32767U;
    }
    if (v < -32768) {
        return (u32)(u16)-32768;
    }
    return (u32)(u16)((s16)v);
}

static int unpack_i16(u32 word, u32 upper)
{
    u16 raw = upper ? (u16)(word >> 16) : (u16)(word & 0xFFFFU);
    return (int)((s16)raw);
}

static u32 perturb_coeff_word(u32 word, u32 upper, int delta)
{
    int re = unpack_i16(word, 0U);
    int im = unpack_i16(word, 1U);
    if (upper) {
        im += delta;
    } else {
        re += delta;
    }
    return (clamp_i16_to_u16(im) << 16) | clamp_i16_to_u16(re);
}

static u32 add_coeff_real_offset(u32 word, int delta)
{
    return perturb_coeff_word(word, 0U, delta);
}

#if DSM_DPD_AI_POLICY_AVAILABLE
static int ai_policy_lookup(u32 *package_idx, u32 *c1_word,
                            u32 *c3_word, u32 *c5_word)
{
#if DSM_DPD_TX_WAVEFORM_AVAILABLE
    for (u32 k = 0U; k < DSM_DPD_AI_POLICY_WAVEFORM_COUNT; k++) {
        const u32 *entry = dsm_dpd_ai_waveform_policy[k];
        if (entry[0] == DSM_DPD_TX_WAVEFORM_QAM &&
            entry[1] == DSM_DPD_TX_WAVEFORM_USED_SUBCARRIERS &&
            entry[2] == DSM_DPD_TX_WAVEFORM_INPUT_BACKOFF_PPM) {
            const u32 pkg = entry[3];
            if (pkg >= 6U) {
                return XST_FAILURE;
            }
            *package_idx = pkg;
            *c1_word = add_coeff_real_offset(entry[4], dsm_dpd_ai_seed_offsets[pkg][0]);
            *c3_word = add_coeff_real_offset(entry[5], dsm_dpd_ai_seed_offsets[pkg][1]);
            *c5_word = add_coeff_real_offset(entry[6], dsm_dpd_ai_seed_offsets[pkg][2]);
            return XST_SUCCESS;
        }
    }
#endif
    return XST_FAILURE;
}
#endif

static int configure_dpd_poly_words(u32 c1_word, u32 c3_word, u32 c5_word)
{
    dsm_write(DSM_DPD_CTRL, DPD_MODE_BYPASS);
    dsm_write(DSM_DPD_C1, c1_word);
    dsm_write(DSM_DPD_C3, c3_word);
    dsm_write(DSM_DPD_C5, c5_word);
    if (expect_eq("DPD_C1", dsm_read(DSM_DPD_C1), c1_word) != XST_SUCCESS) return XST_FAILURE;
    if (expect_eq("DPD_C3", dsm_read(DSM_DPD_C3), c3_word) != XST_SUCCESS) return XST_FAILURE;
    if (expect_eq("DPD_C5", dsm_read(DSM_DPD_C5), c5_word) != XST_SUCCESS) return XST_FAILURE;
    dsm_write(DSM_DPD_CTRL, DPD_MODE_POLY);
    return expect_eq("DPD_CTRL", dsm_read(DSM_DPD_CTRL), DPD_MODE_POLY);
}

static int configure_dpd_memory_package(u32 package_idx, int coefficient_index,
                                        u32 coefficient_upper, int coefficient_delta)
{
#if DPD_TINYML_PACKAGE_TABLE_V2_AVAILABLE
    u32 tap;
    u32 order;
    const u32 pkg = (package_idx < DPD_TINYML_PACKAGE_TABLE_V2_COUNT) ?
                    package_idx : 0U;

    dsm_write(DSM_DPD_CTRL, DPD_MODE_BYPASS);
    for (tap = 0U; tap < DPD_TINYML_PACKAGE_TABLE_V2_TAPS; ++tap) {
        for (order = 0U; order < DPD_TINYML_PACKAGE_TABLE_V2_ORDERS; ++order) {
            dsm_write(DSM_MP_SELECT,
                      (tap & 0x3U) | ((order & 0x3U) << 2) |
                      ((u32)DPD_TINYML_HIERARCHY_POLICY_ACTIVE_TAPS << 8));
            u32 word = dsm_dpd_tinyml_mp_packages[pkg][tap * 3U + order];
            if ((int)(tap * 3U + order) == coefficient_index) {
                word = perturb_coeff_word(word, coefficient_upper, coefficient_delta);
            }
            dsm_write(DSM_MP_DATA, word);
        }
    }
    dsm_write(DSM_MP_COMMIT, 1U);
    dsm_write(DSM_DPD_CTRL, DPD_MODE_MEMORY);
    if (expect_eq("TINYML_MP_DPD_CTRL", dsm_read(DSM_DPD_CTRL), DPD_MODE_MEMORY) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    xil_printf("TINYML_MP_PACKAGE package=%d active_taps=%d active_bank=%d\r\n",
               (int)pkg, (int)DPD_TINYML_HIERARCHY_POLICY_ACTIVE_TAPS,
               (int)(dsm_read(DSM_MP_COMMIT) & 1U));
    return XST_SUCCESS;
#else
    (void)package_idx;
    xil_printf("FAIL observer-v2 TinyML package table is unavailable\r\n");
    return XST_FAILURE;
#endif
}

static int load_observer_v2_input(dpd_tinyml_raw_input_t *raw)
{
#if DPD_TINYML_HIERARCHY_POLICY_AVAILABLE || DPD_SAFETY_SEED_POLICY_CONSTANTS_AVAILABLE
    const u32 env = dsm_read(DSM_OBS_ENV);
    const u32 status = dsm_read(DSM_OBS_STATUS);
    const u32 pair_count = dsm_read(DSM_OBS_PAIR_COUNT);
    const u32 clip_sat = dsm_read(DSM_OBS_CLIP_SAT);
    const u64 error_l1 = ((u64)dsm_read(DSM_OBS_ERROR_HI) << 32) |
                         (u64)dsm_read(DSM_OBS_ERROR_LO);

    if (raw == NULL || ((env >> 24) & 0xFFU) !=
        DPD_TINYML_FEATURE_SCHEMA_ALIGNED_COMPLEX_PA_MONITOR_V2 ||
        (status & 0x4U) == 0U || pair_count == 0U) {
        return XST_FAILURE;
    }
    raw->qam_order = dsm_read(DSM_CONDITION_QAM) & 0xFFFFU;
    raw->bandwidth_khz = dsm_read(DSM_CONDITION_BW_KHZ);
    raw->backoff_ppm = dsm_read(DSM_CONDITION_BACKOFF);
    raw->temperature_q8_8 = (int16_t)(env & 0xFFFFU);
    raw->input_power = dsm_read(DSM_OBS_REF_MAG);
    raw->output_power = dsm_read(DSM_OBS_MAG);
    raw->peak = dsm_read(DSM_OBS_PEAK);
    raw->avg_mag = raw->output_power / pair_count;
    raw->evm_proxy = (u32)error_l1;
    raw->acpr_proxy = dsm_read(DSM_OBS_SLEW);
    raw->spec_bin0 = dsm_read(DSM_OBS_SPEC_BIN0);
    raw->spec_bin1 = dsm_read(DSM_OBS_SPEC_BIN1);
    raw->spec_bin2 = dsm_read(DSM_OBS_SPEC_BIN2);
    raw->spec_adj = dsm_read(DSM_OBS_SPEC_ADJ);
    raw->clip_count = clip_sat & 0xFFFFU;
    raw->saturation_count = (clip_sat >> 16) & 0xFFFFU;
    raw->sample_count = pair_count;
    raw->observation_error_l1 = error_l1;
    raw->valid = 1U;
    return XST_SUCCESS;
#else
    (void)raw;
    return XST_FAILURE;
#endif
}

static u32 tinyml_lut_seed(u32 qam, u32 bandwidth_khz, u32 backoff_ppm)
{
#if DPD_TINYML_LUT_V2_AVAILABLE
    u32 index;
    for (index = 0U; index < DPD_TINYML_LUT_V2_ROWS; ++index) {
        if (dsm_dpd_tinyml_lut_v2[index][0] == qam &&
            dsm_dpd_tinyml_lut_v2[index][1] == bandwidth_khz &&
            dsm_dpd_tinyml_lut_v2[index][2] == backoff_ppm) {
            return dsm_dpd_tinyml_lut_v2[index][3];
        }
    }
#else
    (void)qam;
    (void)bandwidth_khz;
    (void)backoff_ppm;
#endif
    return DPD_TINYML_FALLBACK_PACKAGE;
}

static int run_one_memory_package(u32 package_idx, int coefficient_index,
                                  u32 coefficient_upper, int coefficient_delta,
                                  CalibrationResult *result)
{
#if DPD_TINYML_PACKAGE_TABLE_V2_AVAILABLE
    if (configure_dpd_memory_package(package_idx, coefficient_index, coefficient_upper,
                                     coefficient_delta) != XST_SUCCESS ||
        run_stream() != XST_SUCCESS || check_counters() != XST_SUCCESS) {
        return XST_FAILURE;
    }
    if (result != NULL) {
        result->mode = DPD_MODE_MEMORY;
        result->package_idx = package_idx;
        result->searched = 1U;
        result->c1_word = dsm_dpd_tinyml_mp_packages[package_idx][0];
        result->c3_word = dsm_dpd_tinyml_mp_packages[package_idx][1];
        result->c5_word = dsm_dpd_tinyml_mp_packages[package_idx][2];
        result->proxy_evm_ppm = 0U;
        result->proxy_sndr_mdB = 0U;
        result->input_power = dsm_read(DSM_MON_INPUT_POWER);
        result->output_power = dsm_read(DSM_MON_OUTPUT_POWER);
        result->saturation_count = dsm_read(DSM_DPD_SATURATION_COUNT);
        result->clip_count = dsm_read(DSM_MON_CLIP_COUNT);
        result->error_status = dsm_read(DSM_ERROR_STATUS);
        result->stall_count = dsm_read(DSM_INPUT_STALL_COUNT);
        result->peak_word = dsm_read(DSM_MON_PEAK);
        result->avg_mag_word = dsm_read(DSM_MON_AVG_MAG);
        result->evm_proxy = dsm_read(DSM_MON_EVM_PROXY);
        result->acpr_proxy = dsm_read(DSM_MON_ACPR_PROXY);
        result->spec_bin0_proxy = dsm_read(DSM_MON_SPEC_BIN0);
        result->spec_bin1_proxy = dsm_read(DSM_MON_SPEC_BIN1);
        result->spec_bin2_proxy = dsm_read(DSM_MON_SPEC_BIN2);
        result->spec_adj_proxy = dsm_read(DSM_MON_SPEC_ADJ);
        result->cost = calibration_cost(0U, result->saturation_count,
                                        result->clip_count, result->error_status,
                                        result->stall_count, result->evm_proxy,
                                        result->acpr_proxy, result->spec_adj_proxy);
    }
    return XST_SUCCESS;
#else
    (void)package_idx;
    (void)coefficient_index;
    (void)coefficient_upper;
    (void)coefficient_delta;
    (void)result;
    return XST_FAILURE;
#endif
}

static int run_stream(void)
{
    fill_iq_vector();

    dsm_write(DSM_CTRL, 0x00000004U);
    dsm_write(DSM_CTRL, 0x00000002U);
    dsm_write(DSM_CTRL, 0x00000001U);

    int status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)TxBuffer, DMA_BYTES, XAXIDMA_DMA_TO_DEVICE);
    if (status != XST_SUCCESS) {
        xil_printf("FAIL XAxiDma_SimpleTransfer status=%d\r\n", status);
        return status;
    }

    u32 timeout = 100000000U;
    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE) && timeout != 0U) {
        timeout--;
    }
    if (timeout == 0U) {
        xil_printf("FAIL DMA MM2S timeout\r\n");
        return XST_FAILURE;
    }

    return XST_SUCCESS;
}

static u32 get_package_evm_ppm(u32 mode, u32 package_idx)
{
    const u32 pkg = (package_idx < DSM_DPD_NUM_PACKAGES) ? package_idx : 0U;
    if (mode == DPD_MODE_POLY) {
        return dsm_dpd_poly_evm_ppm[pkg];
    }
    if (mode == DPD_MODE_LUT) {
        return dsm_dpd_lut_evm_ppm[pkg];
    }
    return 0U;
}

static u32 get_package_sndr_mdB(u32 mode, u32 package_idx)
{
    const u32 pkg = (package_idx < DSM_DPD_NUM_PACKAGES) ? package_idx : 0U;
    if (mode == DPD_MODE_POLY) {
        return dsm_dpd_poly_sndr_mdB[pkg];
    }
    if (mode == DPD_MODE_LUT) {
        return dsm_dpd_lut_sndr_mdB[pkg];
    }
    return 0U;
}

static u32 calibration_cost(u32 proxy_evm_ppm, u32 saturation_count,
                            u32 clip_count, u32 error_status,
                            u32 stall_count, u32 evm_proxy,
                            u32 acpr_proxy, u32 spec_adj_proxy)
{
    return (proxy_evm_ppm * CAL_WEIGHT_PROXY_EVM) +
           (saturation_count * CAL_PENALTY_SATURATION) +
           (clip_count * CAL_PENALTY_CLIP) +
           (error_status * CAL_PENALTY_ERROR) +
           (stall_count * CAL_PENALTY_STALL) +
           (evm_proxy >> CAL_EVM_PROXY_SHIFT) +
           (acpr_proxy >> CAL_ACPR_PROXY_SHIFT) +
           (spec_adj_proxy >> CAL_SPEC_ADJ_SHIFT);
}

static void print_calibration_config(void)
{
    xil_printf("CAL_CONFIG weight_proxy_evm=%d penalty_sat=%d penalty_clip=%d penalty_error=%d penalty_stall=%d evm_shift=%d acpr_shift=%d spec_adj_shift=%d initial_step=%d min_step=%d rounds=%d\r\n",
               (int)CAL_WEIGHT_PROXY_EVM,
               (int)CAL_PENALTY_SATURATION,
               (int)CAL_PENALTY_CLIP,
               (int)CAL_PENALTY_ERROR,
               (int)CAL_PENALTY_STALL,
               (int)CAL_EVM_PROXY_SHIFT,
               (int)CAL_ACPR_PROXY_SHIFT,
               (int)CAL_SPEC_ADJ_SHIFT,
               (int)CAL_SEARCH_INITIAL_STEP_Q214,
               (int)CAL_SEARCH_MIN_STEP_Q214,
               (int)CAL_SEARCH_MAX_ROUNDS);
    xil_printf("CAL_SEED_CONFIG enabled=%d available=%d package=%d c1=0x%08x c3=0x%08x c5=0x%08x\r\n",
               (int)CAL_USE_SOFTWARE_SEED,
               (int)DSM_DPD_SEED_AVAILABLE,
               (int)DSM_DPD_SEED_PACKAGE_IDX,
               (u32)DSM_DPD_SEED_C1_WORD,
               (u32)DSM_DPD_SEED_C3_WORD,
               (u32)DSM_DPD_SEED_C5_WORD);
    xil_printf("CAL_TRACE_POLICY enabled=%d available=%d mode=%d package=%d predicted_cost=%d\r\n",
               (int)CAL_TRACE_POLICY_ONLY,
               (int)DSM_DPD_TRACE_POLICY_AVAILABLE,
               (int)DSM_DPD_TRACE_POLICY_MODE,
               (int)DSM_DPD_TRACE_POLICY_PACKAGE_IDX,
               (int)DSM_DPD_TRACE_POLICY_PREDICTED_COST);
    xil_printf("CAL_TRACE_POLICY_FORCE_LOCAL_SEARCH=%d\r\n",
               (int)CAL_FORCE_POLICY_LOCAL_SEARCH);
    xil_printf("CAL_TINYML_HIERARCHY enabled=%d available=%d direct_allowed=%d local_candidates=%d\r\n",
               (int)CAL_TINYML_HIERARCHY_ONLY,
               (int)DPD_TINYML_HIERARCHY_POLICY_AVAILABLE,
               (int)DPD_TINYML_HIERARCHY_POLICY_DIRECT_ALLOWED,
               (int)DPD_TINYML_HIERARCHY_POLICY_LOCAL_CANDIDATES);
    xil_printf("CAL_SAFETY_SEED_POLICY enabled=%d constants=%d board_enable=%d direct_allowed=%d local_candidates=%d\r\n",
               (int)CAL_SAFETY_SEED_POLICY_ONLY,
               (int)DPD_SAFETY_SEED_POLICY_CONSTANTS_AVAILABLE,
               (int)DPD_SAFETY_SEED_POLICY_BOARD_ENABLE_ALLOWED,
               (int)DPD_SAFETY_SEED_POLICY_DIRECT_ALLOWED,
               (int)DPD_SAFETY_SEED_POLICY_LOCAL_CANDIDATES);
    xil_printf("CAL_TRACE_CSV candidate_id,round,stage,mode,package,searched,c1,c3,c5,proxy_evm_ppm,proxy_sndr_mdB,input_power,output_power,saturation,clip,error,stall,evm_proxy,acpr_proxy,spec_bin0,spec_bin1,spec_bin2,spec_adj,cost,decision,reason\r\n");
}

static void print_calibration_trace(const char *stage,
                                    u32 round,
                                    const CalibrationResult *result,
                                    const char *decision,
                                    const char *reason)
{
    calibration_trace_store(stage, round, result, decision, reason);
    xil_printf("CAL_TRACE,%d,%d,%s,%d,%d,%d,0x%08x,0x%08x,0x%08x,%d,%d,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,0x%08x,%d,%s,%s\r\n",
               (int)g_candidate_id,
               (int)round,
               stage,
               (int)result->mode,
               (int)result->package_idx,
               (int)result->searched,
               result->c1_word,
               result->c3_word,
               result->c5_word,
               (int)result->proxy_evm_ppm,
               (int)result->proxy_sndr_mdB,
               result->input_power,
               result->output_power,
               result->saturation_count,
               result->clip_count,
               result->error_status,
               result->stall_count,
               result->evm_proxy,
               result->acpr_proxy,
               result->spec_bin0_proxy,
               result->spec_bin1_proxy,
               result->spec_bin2_proxy,
               result->spec_adj_proxy,
               (int)result->cost,
               decision,
               reason);
}

static int check_counters_mode(u32 require_safe_monitors)
{
    int status = XST_SUCCESS;
    status |= expect_eq("INPUT_SAMPLE_COUNT", dsm_read(DSM_INPUT_SAMPLE_COUNT), DMA_WORDS);
    status |= expect_eq("FRONTEND_SAMPLE_COUNT", dsm_read(DSM_FRONTEND_SAMPLE_COUNT), DMA_WORDS);
    status |= expect_eq("DPD_SAMPLE_COUNT", dsm_read(DSM_DPD_SAMPLE_COUNT), DMA_WORDS);
    status |= expect_eq("OUTPUT_SAMPLE_COUNT", dsm_read(DSM_OUTPUT_SAMPLE_COUNT), DMA_WORDS);
    if (require_safe_monitors != 0U) {
        status |= expect_eq("INPUT_STALL_COUNT", dsm_read(DSM_INPUT_STALL_COUNT), 0U);
        status |= expect_eq("ERROR_STATUS", dsm_read(DSM_ERROR_STATUS), 0U);
    } else {
        xil_printf("INPUT_STALL_COUNT    = 0x%08x\r\n", dsm_read(DSM_INPUT_STALL_COUNT));
        xil_printf("ERROR_STATUS         = 0x%08x\r\n", dsm_read(DSM_ERROR_STATUS));
    }
    xil_printf("DPD_SATURATION_COUNT = 0x%08x\r\n",
               dsm_read(DSM_DPD_SATURATION_COUNT));
    xil_printf("MON_INPUT_POWER      = 0x%08x\r\n", dsm_read(DSM_MON_INPUT_POWER));
    xil_printf("MON_OUTPUT_POWER     = 0x%08x\r\n", dsm_read(DSM_MON_OUTPUT_POWER));
    xil_printf("MON_CLIP_COUNT       = 0x%08x\r\n", dsm_read(DSM_MON_CLIP_COUNT));
    xil_printf("MON_PEAK             = 0x%08x\r\n", dsm_read(DSM_MON_PEAK));
    xil_printf("MON_AVG_MAG          = 0x%08x\r\n", dsm_read(DSM_MON_AVG_MAG));
    xil_printf("MON_EVM_PROXY        = 0x%08x\r\n", dsm_read(DSM_MON_EVM_PROXY));
    xil_printf("MON_ACPR_PROXY       = 0x%08x\r\n", dsm_read(DSM_MON_ACPR_PROXY));
    xil_printf("MON_SPEC_BIN0        = 0x%08x\r\n", dsm_read(DSM_MON_SPEC_BIN0));
    xil_printf("MON_SPEC_BIN1        = 0x%08x\r\n", dsm_read(DSM_MON_SPEC_BIN1));
    xil_printf("MON_SPEC_BIN2        = 0x%08x\r\n", dsm_read(DSM_MON_SPEC_BIN2));
    xil_printf("MON_SPEC_ADJ         = 0x%08x\r\n", dsm_read(DSM_MON_SPEC_ADJ));
    return status;
}

static int check_counters(void)
{
    return check_counters_mode(1U);
}

static int run_one_mode_checked(u32 mode, u32 package_idx,
                                CalibrationResult *result,
                                u32 require_safe_monitors)
{
    xil_printf("\r\n=== DSM DPD bare-metal smoke mode %d package %d ===\r\n",
               (int)mode, (int)package_idx);
    if (package_idx < DSM_DPD_NUM_PACKAGES) {
        xil_printf("PACKAGE_NAME = %s\r\n", dsm_dpd_package_names[package_idx]);
    }
    xil_printf("PROXY_EVM_PPM = %d\r\n", (int)get_package_evm_ppm(mode, package_idx));
    xil_printf("PROXY_SNDR_MDB = %d\r\n", (int)get_package_sndr_mdB(mode, package_idx));
    xil_printf("DSM_VERSION = 0x%08x\r\n", dsm_read(DSM_VERSION));
    xil_printf("INTERP_MODE = 0x%08x\r\n", dsm_read(DSM_INTERP_MODE));

    if (configure_dpd(mode, package_idx) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    if (run_stream() != XST_SUCCESS) {
        return XST_FAILURE;
    }
    if (check_counters_mode(require_safe_monitors) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    if (result != NULL) {
        result->mode = mode;
        result->package_idx = package_idx;
        result->searched = 0U;
        result->c1_word = (package_idx < DSM_DPD_NUM_PACKAGES) ? dsm_dpd_c1_words[package_idx] : 0U;
        result->c3_word = (package_idx < DSM_DPD_NUM_PACKAGES) ? dsm_dpd_c3_words[package_idx] : 0U;
        result->c5_word = (package_idx < DSM_DPD_NUM_PACKAGES) ? dsm_dpd_c5_words[package_idx] : 0U;
        result->proxy_evm_ppm = get_package_evm_ppm(mode, package_idx);
        result->proxy_sndr_mdB = get_package_sndr_mdB(mode, package_idx);
        result->input_power = dsm_read(DSM_MON_INPUT_POWER);
        result->output_power = dsm_read(DSM_MON_OUTPUT_POWER);
        result->saturation_count = dsm_read(DSM_DPD_SATURATION_COUNT);
        result->clip_count = dsm_read(DSM_MON_CLIP_COUNT);
        result->error_status = dsm_read(DSM_ERROR_STATUS);
        result->stall_count = dsm_read(DSM_INPUT_STALL_COUNT);
        result->peak_word = dsm_read(DSM_MON_PEAK);
        result->avg_mag_word = dsm_read(DSM_MON_AVG_MAG);
        result->evm_proxy = dsm_read(DSM_MON_EVM_PROXY);
        result->acpr_proxy = dsm_read(DSM_MON_ACPR_PROXY);
        result->spec_bin0_proxy = dsm_read(DSM_MON_SPEC_BIN0);
        result->spec_bin1_proxy = dsm_read(DSM_MON_SPEC_BIN1);
        result->spec_bin2_proxy = dsm_read(DSM_MON_SPEC_BIN2);
        result->spec_adj_proxy = dsm_read(DSM_MON_SPEC_ADJ);
        result->cost = calibration_cost(result->proxy_evm_ppm,
                                        result->saturation_count,
                                        result->clip_count,
                                        result->error_status,
                                        result->stall_count,
                                        result->evm_proxy,
                                        result->acpr_proxy,
                                        result->spec_adj_proxy);
        xil_printf("CAL_RESULT mode=%d package=%d evm_ppm=%d sndr_mdB=%d in_pwr=0x%08x out_pwr=0x%08x sat=0x%08x clip=0x%08x error=0x%08x stall=0x%08x evm_proxy=0x%08x acpr_proxy=0x%08x spec_adj=0x%08x cost=%d\r\n",
                   (int)result->mode, (int)result->package_idx,
                   (int)result->proxy_evm_ppm, (int)result->proxy_sndr_mdB,
                   result->input_power, result->output_power,
                   result->saturation_count, result->clip_count,
                   result->error_status, result->stall_count,
                   result->evm_proxy, result->acpr_proxy,
                   result->spec_adj_proxy,
                   (int)result->cost);
    }
    xil_printf("PASS mode %d\r\n", (int)mode);
    return XST_SUCCESS;
}

static int run_one_mode(u32 mode, u32 package_idx, CalibrationResult *result)
{
    return run_one_mode_checked(mode, package_idx, result, 1U);
}

static u32 runtime_cost_residual_ppm(u32 measured_cost, u32 predicted_cost)
{
    const u32 denominator = (predicted_cost == 0U) ? 1U : predicted_cost;
    const u32 delta = (measured_cost >= predicted_cost) ?
                      (measured_cost - predicted_cost) :
                      (predicted_cost - measured_cost);
    return (u32)(((u64)delta * 1000000ULL) / (u64)denominator);
}

static u32 monitor_relative_distance_ppm(u32 measured, u32 expected)
{
    const u32 denominator = (expected == 0U) ? 1U : expected;
    const u32 delta = (measured >= expected) ? (measured - expected) :
                      (expected - measured);
    return (u32)(((u64)delta * 1000000ULL) / (u64)denominator);
}

static u32 runtime_monitor_distance_ppm(const CalibrationResult *result)
{
    const u32 measured[12] = {
        result->input_power, result->output_power, result->peak_word,
        result->avg_mag_word, result->evm_proxy, result->acpr_proxy,
        result->spec_bin0_proxy, result->spec_bin1_proxy,
        result->spec_bin2_proxy, result->spec_adj_proxy, result->clip_count,
        result->saturation_count
    };
    const u32 expected[12] = {
        DSM_DPD_TRACE_POLICY_MON_INPUT_POWER,
        DSM_DPD_TRACE_POLICY_MON_OUTPUT_POWER,
        DSM_DPD_TRACE_POLICY_MON_PEAK,
        DSM_DPD_TRACE_POLICY_MON_AVG_MAG,
        DSM_DPD_TRACE_POLICY_MON_EVM_PROXY,
        DSM_DPD_TRACE_POLICY_MON_ACPR_PROXY,
        DSM_DPD_TRACE_POLICY_MON_SPEC_BIN0,
        DSM_DPD_TRACE_POLICY_MON_SPEC_BIN1,
        DSM_DPD_TRACE_POLICY_MON_SPEC_BIN2,
        DSM_DPD_TRACE_POLICY_MON_SPEC_ADJ,
        DSM_DPD_TRACE_POLICY_MON_CLIP,
        DSM_DPD_TRACE_POLICY_MON_SATURATION
    };
    u64 sum = 0U;
    u32 index;
    for (index = 0U; index < 12U; index++) {
        sum += monitor_relative_distance_ppm(measured[index], expected[index]);
    }
    return (u32)(sum / 12U);
}

static int run_one_poly_candidate(u32 package_idx,
                                  u32 c1_word,
                                  u32 c3_word,
                                  u32 c5_word,
                                  CalibrationResult *result)
{
    xil_printf("\r\n=== DSM DPD PS search candidate package %d ===\r\n",
               (int)package_idx);
    xil_printf("SEARCH_C1 = 0x%08x SEARCH_C3 = 0x%08x SEARCH_C5 = 0x%08x\r\n",
               c1_word, c3_word, c5_word);

    if (configure_dpd_poly_words(c1_word, c3_word, c5_word) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    if (run_stream() != XST_SUCCESS) {
        return XST_FAILURE;
    }
    if (check_counters() != XST_SUCCESS) {
        return XST_FAILURE;
    }

    if (result != NULL) {
        result->mode = DPD_MODE_POLY;
        result->package_idx = package_idx;
        result->searched = 1U;
        result->c1_word = c1_word;
        result->c3_word = c3_word;
        result->c5_word = c5_word;
        result->proxy_evm_ppm = get_package_evm_ppm(DPD_MODE_POLY, package_idx);
        result->proxy_sndr_mdB = get_package_sndr_mdB(DPD_MODE_POLY, package_idx);
        result->input_power = dsm_read(DSM_MON_INPUT_POWER);
        result->output_power = dsm_read(DSM_MON_OUTPUT_POWER);
        result->saturation_count = dsm_read(DSM_DPD_SATURATION_COUNT);
        result->clip_count = dsm_read(DSM_MON_CLIP_COUNT);
        result->error_status = dsm_read(DSM_ERROR_STATUS);
        result->stall_count = dsm_read(DSM_INPUT_STALL_COUNT);
        result->peak_word = dsm_read(DSM_MON_PEAK);
        result->avg_mag_word = dsm_read(DSM_MON_AVG_MAG);
        result->evm_proxy = dsm_read(DSM_MON_EVM_PROXY);
        result->acpr_proxy = dsm_read(DSM_MON_ACPR_PROXY);
        result->spec_bin0_proxy = dsm_read(DSM_MON_SPEC_BIN0);
        result->spec_bin1_proxy = dsm_read(DSM_MON_SPEC_BIN1);
        result->spec_bin2_proxy = dsm_read(DSM_MON_SPEC_BIN2);
        result->spec_adj_proxy = dsm_read(DSM_MON_SPEC_ADJ);
        result->cost = calibration_cost(result->proxy_evm_ppm,
                                        result->saturation_count,
                                        result->clip_count,
                                        result->error_status,
                                        result->stall_count,
                                        result->evm_proxy,
                                        result->acpr_proxy,
                                        result->spec_adj_proxy);
        xil_printf("CAL_SEARCH_RESULT package=%d evm_ppm=%d sndr_mdB=%d c1=0x%08x c3=0x%08x c5=0x%08x sat=0x%08x clip=0x%08x error=0x%08x stall=0x%08x evm_proxy=0x%08x acpr_proxy=0x%08x spec_adj=0x%08x cost=%d\r\n",
                   (int)result->package_idx, (int)result->proxy_evm_ppm,
                   (int)result->proxy_sndr_mdB, result->c1_word,
                   result->c3_word, result->c5_word, result->saturation_count,
                   result->clip_count, result->error_status, result->stall_count,
                   result->evm_proxy, result->acpr_proxy,
                   result->spec_adj_proxy, (int)result->cost);
    }
    return XST_SUCCESS;
}

static void copy_result(CalibrationResult *dst, const CalibrationResult *src)
{
    dst->mode = src->mode;
    dst->package_idx = src->package_idx;
    dst->c1_word = src->c1_word;
    dst->c3_word = src->c3_word;
    dst->c5_word = src->c5_word;
    dst->searched = src->searched;
    dst->proxy_evm_ppm = src->proxy_evm_ppm;
    dst->proxy_sndr_mdB = src->proxy_sndr_mdB;
    dst->input_power = src->input_power;
    dst->output_power = src->output_power;
    dst->saturation_count = src->saturation_count;
    dst->clip_count = src->clip_count;
    dst->error_status = src->error_status;
    dst->stall_count = src->stall_count;
    dst->peak_word = src->peak_word;
    dst->avg_mag_word = src->avg_mag_word;
    dst->evm_proxy = src->evm_proxy;
    dst->acpr_proxy = src->acpr_proxy;
    dst->spec_bin0_proxy = src->spec_bin0_proxy;
    dst->spec_bin1_proxy = src->spec_bin1_proxy;
    dst->spec_bin2_proxy = src->spec_bin2_proxy;
    dst->spec_adj_proxy = src->spec_adj_proxy;
    dst->cost = src->cost;
}

static int apply_selected_package(const CalibrationResult *best)
{
    CalibrationResult final_result;
    xil_printf("\r\n=== Apply selected DPD package ===\r\n");
    xil_printf("SELECTED mode=%d package=%d searched=%d evm_ppm=%d sndr_mdB=%d cost=%d\r\n",
               (int)best->mode, (int)best->package_idx,
               (int)best->searched, (int)best->proxy_evm_ppm,
               (int)best->proxy_sndr_mdB, (int)best->cost);

    if (best->searched && best->mode == DPD_MODE_POLY) {
        if (configure_dpd_poly_words(best->c1_word, best->c3_word, best->c5_word) != XST_SUCCESS) {
            return XST_FAILURE;
        }
    } else {
        if (configure_dpd(best->mode, best->package_idx) != XST_SUCCESS) {
            return XST_FAILURE;
        }
    }

    if (expect_eq("SELECTED_DPD_CTRL", dsm_read(DSM_DPD_CTRL), best->mode) != XST_SUCCESS) {
        return XST_FAILURE;
    }

    xil_printf("Re-running stream with selected DPD package to refresh final counters\r\n");
    if (run_stream() != XST_SUCCESS) {
        return XST_FAILURE;
    }
    if (check_counters() != XST_SUCCESS) {
        return XST_FAILURE;
    }

    copy_result(&final_result, best);
    final_result.input_power = dsm_read(DSM_MON_INPUT_POWER);
    final_result.output_power = dsm_read(DSM_MON_OUTPUT_POWER);
    final_result.saturation_count = dsm_read(DSM_DPD_SATURATION_COUNT);
    final_result.clip_count = dsm_read(DSM_MON_CLIP_COUNT);
    final_result.error_status = dsm_read(DSM_ERROR_STATUS);
    final_result.stall_count = dsm_read(DSM_INPUT_STALL_COUNT);
    final_result.peak_word = dsm_read(DSM_MON_PEAK);
    final_result.avg_mag_word = dsm_read(DSM_MON_AVG_MAG);
    final_result.evm_proxy = dsm_read(DSM_MON_EVM_PROXY);
    final_result.acpr_proxy = dsm_read(DSM_MON_ACPR_PROXY);
    final_result.spec_bin0_proxy = dsm_read(DSM_MON_SPEC_BIN0);
    final_result.spec_bin1_proxy = dsm_read(DSM_MON_SPEC_BIN1);
    final_result.spec_bin2_proxy = dsm_read(DSM_MON_SPEC_BIN2);
    final_result.spec_adj_proxy = dsm_read(DSM_MON_SPEC_ADJ);
    final_result.cost = calibration_cost(final_result.proxy_evm_ppm,
                                         final_result.saturation_count,
                                         final_result.clip_count,
                                         final_result.error_status,
                                         final_result.stall_count,
                                         final_result.evm_proxy,
                                         final_result.acpr_proxy,
                                         final_result.spec_adj_proxy);
    g_candidate_id++;
    print_calibration_trace("final", 0U, &final_result, "selected", "final_replay");
    calibration_trace_complete();

    xil_printf("CAL_SELECTED_REPLAY mode=%d package=%d searched=%d c1=0x%08x c3=0x%08x c5=0x%08x cost=%d input=0x%08x frontend=0x%08x dpd=0x%08x output=0x%08x stall=0x%08x error=0x%08x sat=0x%08x evm_proxy=0x%08x acpr_proxy=0x%08x spec_adj=0x%08x\r\n",
               (int)best->mode,
               (int)best->package_idx,
               (int)best->searched,
               best->c1_word,
               best->c3_word,
               best->c5_word,
               (int)best->cost,
               dsm_read(DSM_INPUT_SAMPLE_COUNT),
               dsm_read(DSM_FRONTEND_SAMPLE_COUNT),
               dsm_read(DSM_DPD_SAMPLE_COUNT),
               dsm_read(DSM_OUTPUT_SAMPLE_COUNT),
               dsm_read(DSM_INPUT_STALL_COUNT),
               dsm_read(DSM_ERROR_STATUS),
               dsm_read(DSM_DPD_SATURATION_COUNT),
               dsm_read(DSM_MON_EVM_PROXY),
               dsm_read(DSM_MON_ACPR_PROXY),
               dsm_read(DSM_MON_SPEC_ADJ));
    xil_printf("PASS selected DPD package is retained in PL registers\r\n");
    return XST_SUCCESS;
}

static int run_poly_search_loop_limited(const CalibrationResult *seed,
                                        CalibrationResult *best,
                                        u32 max_rounds,
                                        int initial_step)
{
    CalibrationResult trial;
    u32 coeff_words[3];
    int step = initial_step;

    if (seed->mode != DPD_MODE_POLY || seed->package_idx >= DSM_DPD_NUM_PACKAGES) {
        xil_printf("\r\n=== PS coefficient search skipped: no polynomial seed ===\r\n");
        return XST_SUCCESS;
    }

    xil_printf("\r\n=== PS-side polynomial coefficient search ===\r\n");
    xil_printf("SEARCH seed package=%d initial_step=%d min_step=%d rounds=%d\r\n",
               (int)seed->package_idx, initial_step,
               CAL_SEARCH_MIN_STEP_Q214, (int)max_rounds);

    coeff_words[0] = seed->c1_word;
    coeff_words[1] = seed->c3_word;
    coeff_words[2] = seed->c5_word;

    for (u32 round = 0; round < max_rounds && step >= CAL_SEARCH_MIN_STEP_Q214; round++) {
        xil_printf("SEARCH_ROUND round=%d step=%d seed_cost=%d c1=0x%08x c3=0x%08x c5=0x%08x\r\n",
                   (int)round, step, (int)best->cost,
                   coeff_words[0], coeff_words[1], coeff_words[2]);
        for (u32 coeff = 0; coeff < 3U; coeff++) {
            for (u32 part = 0; part < 2U; part++) {
                for (u32 dir_idx = 0; dir_idx < 2U; dir_idx++) {
                    int delta = (dir_idx == 0U) ? -step : step;
                    u32 cand[3];
                    cand[0] = coeff_words[0];
                    cand[1] = coeff_words[1];
                    cand[2] = coeff_words[2];
                    cand[coeff] = perturb_coeff_word(cand[coeff], part, delta);

                    g_candidate_id++;
                    if (run_one_poly_candidate(seed->package_idx, cand[0], cand[1], cand[2], &trial) != XST_SUCCESS) {
                        return XST_FAILURE;
                    }
                    if (trial.cost < best->cost) {
                        xil_printf("SEARCH_ACCEPT coeff=%d part=%d delta=%d old_cost=%d new_cost=%d\r\n",
                                   (int)coeff, (int)part, delta,
                                   (int)best->cost, (int)trial.cost);
                        print_calibration_trace("search", round, &trial, "accept", "lower_cost");
                        copy_result(best, &trial);
                        coeff_words[0] = trial.c1_word;
                        coeff_words[1] = trial.c3_word;
                        coeff_words[2] = trial.c5_word;
                    } else {
                        print_calibration_trace("search", round, &trial, "reject", "not_lower_cost");
                    }
                }
            }
        }
        step = step / 2;
    }

    return XST_SUCCESS;
}

static int run_poly_search_loop(const CalibrationResult *seed,
                                CalibrationResult *best)
{
    return run_poly_search_loop_limited(seed, best, CAL_SEARCH_MAX_ROUNDS,
                                        CAL_SEARCH_INITIAL_STEP_Q214);
}

static int run_calibration_demo(void)
{
    CalibrationResult best;
    CalibrationResult trial;
    best.mode = DPD_MODE_BYPASS;
    best.package_idx = 0U;
    best.c1_word = 0U;
    best.c3_word = 0U;
    best.c5_word = 0U;
    best.searched = 0U;
    best.proxy_evm_ppm = 0xFFFFFFFFU;
    best.proxy_sndr_mdB = 0U;
    best.input_power = 0U;
    best.output_power = 0U;
    best.saturation_count = 0xFFFFFFFFU;
    best.clip_count = 0xFFFFFFFFU;
    best.error_status = 0xFFFFFFFFU;
    best.stall_count = 0xFFFFFFFFU;
    best.peak_word = 0U;
    best.avg_mag_word = 0U;
    best.evm_proxy = 0xFFFFFFFFU;
    best.acpr_proxy = 0xFFFFFFFFU;
    best.spec_bin0_proxy = 0xFFFFFFFFU;
    best.spec_bin1_proxy = 0xFFFFFFFFU;
    best.spec_bin2_proxy = 0xFFFFFFFFU;
    best.spec_adj_proxy = 0xFFFFFFFFU;
    best.cost = 0xFFFFFFFFU;
    CalibrationResult best_poly;
    copy_result(&best_poly, &best);

    xil_printf("\r\n=== Bare-metal calibration demo ===\r\n");
    xil_printf("DPD packages = %d\r\n", (int)DSM_DPD_NUM_PACKAGES);
    print_calibration_config();

    /* Probe the host-generated nearest-neighbor seed on real PL metrics first. */
    if (CAL_USE_SOFTWARE_SEED != 0U && DSM_DPD_SEED_AVAILABLE != 0U) {
        u32 seed_pkg = (DSM_DPD_SEED_PACKAGE_IDX < DSM_DPD_NUM_PACKAGES) ?
                       DSM_DPD_SEED_PACKAGE_IDX : 0U;
        g_candidate_id++;
        if (run_one_poly_candidate(seed_pkg, (u32)DSM_DPD_SEED_C1_WORD,
                                   (u32)DSM_DPD_SEED_C3_WORD,
                                   (u32)DSM_DPD_SEED_C5_WORD, &trial) != XST_SUCCESS) {
            return XST_FAILURE;
        }
        if (trial.cost < best.cost) {
            print_calibration_trace("software_seed", 0U, &trial, "accept", "best_overall");
            copy_result(&best, &trial);
        } else {
            print_calibration_trace("software_seed", 0U, &trial, "reject", "not_best_overall");
        }
        copy_result(&best_poly, &trial);
    }

    for (u32 pkg = 0; pkg < DSM_DPD_NUM_PACKAGES; pkg++) {
        g_candidate_id++;
        if (run_one_mode(DPD_MODE_POLY, pkg, &trial) != XST_SUCCESS) {
            return XST_FAILURE;
        }
        if (trial.cost < best.cost) {
            print_calibration_trace("package", 0U, &trial, "accept", "best_overall");
            copy_result(&best, &trial);
        } else {
            print_calibration_trace("package", 0U, &trial, "reject", "not_best_overall");
        }
        if (trial.cost < best_poly.cost) {
            copy_result(&best_poly, &trial);
        }
    }

    for (u32 pkg = 0; pkg < DSM_DPD_NUM_PACKAGES; pkg++) {
        g_candidate_id++;
        if (run_one_mode(DPD_MODE_LUT, pkg, &trial) != XST_SUCCESS) {
            return XST_FAILURE;
        }
        if (trial.cost < best.cost) {
            print_calibration_trace("package", 0U, &trial, "accept", "best_overall");
            copy_result(&best, &trial);
        } else {
            print_calibration_trace("package", 0U, &trial, "reject", "not_best_overall");
        }
    }

    if (run_poly_search_loop(&best_poly, &best) != XST_SUCCESS) {
        return XST_FAILURE;
    }

    return apply_selected_package(&best);
}

static int run_replay_demo(void)
{
    CalibrationResult replay;
    const u32 pkg = (CAL_REPLAY_PACKAGE_IDX < DSM_DPD_NUM_PACKAGES) ? CAL_REPLAY_PACKAGE_IDX : 0U;

    xil_printf("\r\n=== Bare-metal calibration replay ===\r\n");
    print_calibration_config();
    xil_printf("CAL_REPLAY_CONFIG mode=%d package=%d use_words=%d c1=0x%08x c3=0x%08x c5=0x%08x\r\n",
               (int)CAL_REPLAY_MODE,
               (int)pkg,
               (int)CAL_REPLAY_USE_WORDS,
               (u32)CAL_REPLAY_C1_WORD,
               (u32)CAL_REPLAY_C3_WORD,
               (u32)CAL_REPLAY_C5_WORD);

    g_candidate_id++;
    if (CAL_REPLAY_USE_WORDS != 0U) {
        if (run_one_poly_candidate(pkg, (u32)CAL_REPLAY_C1_WORD,
                                   (u32)CAL_REPLAY_C3_WORD,
                                   (u32)CAL_REPLAY_C5_WORD,
                                   &replay) != XST_SUCCESS) {
            return XST_FAILURE;
        }
    } else {
        if (run_one_mode(CAL_REPLAY_MODE, pkg, &replay) != XST_SUCCESS) {
            return XST_FAILURE;
        }
    }

    print_calibration_trace("replay", 0U, &replay, "accept", "fixed_replay");
    calibration_trace_complete();
    xil_printf("CAL_SELECTED_REPLAY mode=%d package=%d searched=%d c1=0x%08x c3=0x%08x c5=0x%08x cost=%d input=0x%08x frontend=0x%08x dpd=0x%08x output=0x%08x stall=0x%08x error=0x%08x sat=0x%08x evm_proxy=0x%08x acpr_proxy=0x%08x spec_adj=0x%08x\r\n",
               (int)replay.mode,
               (int)replay.package_idx,
               (int)replay.searched,
               replay.c1_word,
               replay.c3_word,
               replay.c5_word,
               (int)replay.cost,
               dsm_read(DSM_INPUT_SAMPLE_COUNT),
               dsm_read(DSM_FRONTEND_SAMPLE_COUNT),
               dsm_read(DSM_DPD_SAMPLE_COUNT),
               dsm_read(DSM_OUTPUT_SAMPLE_COUNT),
               dsm_read(DSM_INPUT_STALL_COUNT),
               dsm_read(DSM_ERROR_STATUS),
               dsm_read(DSM_DPD_SATURATION_COUNT),
               dsm_read(DSM_MON_EVM_PROXY),
               dsm_read(DSM_MON_ACPR_PROXY),
               dsm_read(DSM_MON_SPEC_ADJ));
    return XST_SUCCESS;
}

static int run_trace_policy_demo(void)
{
    CalibrationResult policy;
    CalibrationResult best;
    u32 residual_ppm;
    u32 monitor_distance_ppm;
    u32 monitor_fault;
    u32 runtime_fault;
    const char *runtime_reason;
    const u32 pkg = (DSM_DPD_TRACE_POLICY_PACKAGE_IDX < DSM_DPD_NUM_PACKAGES) ?
                    DSM_DPD_TRACE_POLICY_PACKAGE_IDX : 0U;

    if (DSM_DPD_TRACE_POLICY_AVAILABLE == 0U) {
        xil_printf("FAIL trace policy requested but no generated policy is available\r\n");
        return XST_FAILURE;
    }

    xil_printf("\r\n=== Bare-metal trace policy replay ===\r\n");
    print_calibration_config();
    xil_printf("CAL_POLICY_CONFIG mode=%d package=%d predicted_cost=%d\r\n",
               (int)DSM_DPD_TRACE_POLICY_MODE, (int)pkg,
               (int)DSM_DPD_TRACE_POLICY_PREDICTED_COST);
    xil_printf("CAL_POLICY_GATE decision=%s nearest_ppm=%d max_distance_ppm=%d cost_stddev=%d rel_stddev_ppm=%d max_rel_stddev_ppm=%d monitor_available=%d max_monitor_distance_ppm=%d fallback_rounds=%d fallback_step=%d\r\n",
               DSM_DPD_TRACE_POLICY_DIRECT ? "direct" : "local_search",
               (int)DSM_DPD_TRACE_POLICY_NEAREST_DISTANCE_PPM,
               (int)DSM_DPD_TRACE_POLICY_MAX_DISTANCE_PPM,
               (int)DSM_DPD_TRACE_POLICY_COST_STDDEV,
               (int)DSM_DPD_TRACE_POLICY_REL_STDDEV_PPM,
               (int)DSM_DPD_TRACE_POLICY_MAX_REL_STDDEV_PPM,
               (int)DSM_DPD_TRACE_POLICY_MONITOR_AVAILABLE,
               (int)DSM_DPD_TRACE_POLICY_MAX_MONITOR_DISTANCE_PPM,
               (int)DSM_DPD_TRACE_POLICY_FALLBACK_ROUNDS,
               (int)DSM_DPD_TRACE_POLICY_FALLBACK_INITIAL_STEP);
    g_candidate_id++;
    if (run_one_mode_checked(DSM_DPD_TRACE_POLICY_MODE, pkg, &policy, 0U) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    print_calibration_trace("policy", 0U, &policy, "selected", "policy_replay");
    residual_ppm = runtime_cost_residual_ppm(policy.cost,
                                             DSM_DPD_TRACE_POLICY_PREDICTED_COST);
    monitor_distance_ppm = (DSM_DPD_TRACE_POLICY_MONITOR_AVAILABLE != 0U) ?
                           runtime_monitor_distance_ppm(&policy) : 0U;
    monitor_fault = ((policy.stall_count != 0U) ||
                     (policy.error_status != 0U) ||
                     (policy.saturation_count != 0U) ||
                     (policy.clip_count != 0U)) ? 1U : 0U;
    runtime_fault = ((residual_ppm > DSM_DPD_TRACE_POLICY_MAX_RUNTIME_RESIDUAL_PPM) ||
                     (monitor_fault != 0U) ||
                     ((DSM_DPD_TRACE_POLICY_MONITOR_AVAILABLE != 0U) &&
                      (monitor_distance_ppm > DSM_DPD_TRACE_POLICY_MAX_MONITOR_DISTANCE_PPM))) ? 1U : 0U;
    runtime_reason = (CAL_FORCE_POLICY_LOCAL_SEARCH != 0U) ? "forced_local_search" :
                     (monitor_fault != 0U) ? "monitor_fault" :
                     ((residual_ppm > DSM_DPD_TRACE_POLICY_MAX_RUNTIME_RESIDUAL_PPM) ?
                      "cost_residual" :
                      (((DSM_DPD_TRACE_POLICY_MONITOR_AVAILABLE != 0U) &&
                        (monitor_distance_ppm > DSM_DPD_TRACE_POLICY_MAX_MONITOR_DISTANCE_PPM)) ?
                       "monitor_distance" : "within_thresholds"));
    xil_printf("CAL_POLICY_RUNTIME_GUARD decision=%s residual_ppm=%d max_residual_ppm=%d monitor_distance_ppm=%d max_monitor_distance_ppm=%d stall=0x%08x error=0x%08x clip=0x%08x saturation=0x%08x reason=%s\r\n",
               ((DSM_DPD_TRACE_POLICY_DIRECT != 0U) && (runtime_fault == 0U) &&
                (CAL_FORCE_POLICY_LOCAL_SEARCH == 0U)) ?
               "direct" : "local_search",
               (int)residual_ppm,
               (int)DSM_DPD_TRACE_POLICY_MAX_RUNTIME_RESIDUAL_PPM,
               (int)monitor_distance_ppm,
               (int)DSM_DPD_TRACE_POLICY_MAX_MONITOR_DISTANCE_PPM,
               policy.stall_count, policy.error_status,
               policy.clip_count,
               policy.saturation_count, runtime_reason);
    if ((DSM_DPD_TRACE_POLICY_DIRECT != 0U) && (runtime_fault == 0U) &&
        (CAL_FORCE_POLICY_LOCAL_SEARCH == 0U)) {
        calibration_trace_complete();
        return XST_SUCCESS;
    }
    if (policy.mode != DPD_MODE_POLY) {
        xil_printf("CAL_POLICY_FALLBACK failed=non_polynomial_policy\r\n");
        calibration_trace_complete();
        return XST_FAILURE;
    }

    copy_result(&best, &policy);
    xil_printf("CAL_POLICY_FALLBACK action=limited_local_search\r\n");
    if (run_poly_search_loop_limited(&policy, &best,
                                     DSM_DPD_TRACE_POLICY_FALLBACK_ROUNDS,
                                     DSM_DPD_TRACE_POLICY_FALLBACK_INITIAL_STEP) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    return apply_selected_package(&best);
}

static int run_ai_policy_demo(void)
{
#if DSM_DPD_AI_POLICY_AVAILABLE
    CalibrationResult policy;
    CalibrationResult best;
    u32 package_idx;
    u32 c1_word;
    u32 c3_word;
    u32 c5_word;

    if (DSM_DPD_AI_POLICY_DIRECT_ALLOWED != 0U ||
        DSM_DPD_AI_POLICY_FORCE_LOCAL_SEARCH == 0U) {
        xil_printf("FAIL AI policy must keep direct disabled and bounded search enabled\r\n");
        return XST_FAILURE;
    }
    if (ai_policy_lookup(&package_idx, &c1_word, &c3_word, &c5_word) != XST_SUCCESS) {
        xil_printf("FAIL AI policy has no matching embedded waveform\r\n");
        return XST_FAILURE;
    }

    xil_printf("\r\n=== AI seed plus mandatory bounded search ===\r\n");
    xil_printf("CAL_AI_POLICY package=%d direct=0 local_candidates=14 c1=0x%08x c3=0x%08x c5=0x%08x\r\n",
               (int)package_idx, c1_word, c3_word, c5_word);
    g_candidate_id++;
    if (run_one_poly_candidate(package_idx, c1_word, c3_word, c5_word, &policy) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    print_calibration_trace("policy", 0U, &policy, "selected", "policy_replay");
    copy_result(&best, &policy);
    if (run_poly_search_loop_limited(&policy, &best,
                                     DSM_DPD_AI_POLICY_LOCAL_ROUNDS,
                                     DSM_DPD_AI_POLICY_LOCAL_STEP_Q214) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    return apply_selected_package(&best);
#else
    xil_printf("FAIL AI policy requested but no generated AI policy is available\r\n");
    return XST_FAILURE;
#endif
}

static int run_tinyml_hierarchy_demo(void)
{
#if DPD_TINYML_HIERARCHY_POLICY_AVAILABLE && DPD_TINYML_PACKAGE_TABLE_V2_AVAILABLE
    dpd_tinyml_raw_input_t raw;
    dpd_tinyml_input_t input;
    dpd_tinyml_result_t tree;
    CalibrationResult policy;
    CalibrationResult trial;
    CalibrationResult best;
    u32 seed_package;
    int best_coefficient = -1;
    u32 best_upper = 0U;
    int best_delta = 0;
    u32 coefficient;
    u32 upper;
    u32 direction;

    if (DPD_TINYML_HIERARCHY_POLICY_DIRECT_ALLOWED != 0U ||
        DPD_TINYML_HIERARCHY_POLICY_LOCAL_CANDIDATES != 14U) {
        xil_printf("FAIL TinyML hierarchy must keep direct disabled and 14-candidate search enabled\r\n");
        return XST_FAILURE;
    }
    if (load_observer_v2_input(&raw) != XST_SUCCESS ||
        dpd_tinyml_build_features(&raw, &input) == 0) {
        xil_printf("FAIL TinyML hierarchy requires completed aligned_complex_pa_monitor_v2 feedback\r\n");
        return XST_FAILURE;
    }
    tree = dpd_tinyml_tree_predict(&input);
    seed_package = tree.direct ? tree.seed_package :
                   tinyml_lut_seed(raw.qam_order, raw.bandwidth_khz, raw.backoff_ppm);
    if (seed_package >= DPD_TINYML_PACKAGE_TABLE_V2_COUNT) {
        xil_printf("FAIL TinyML hierarchy has no tree/LUT seed for this waveform\r\n");
        return XST_FAILURE;
    }

    xil_printf("\r\n=== Observer-v2 TinyML hierarchy plus mandatory 14-candidate MP search ===\r\n");
    print_calibration_config();
    xil_printf("CAL_TINYML_HIERARCHY tree_package=%d tree_direct=%d tree_ood=%d source=%s seed_package=%d local_candidates=14\r\n",
               (int)tree.seed_package, (int)tree.direct, (int)tree.out_of_distribution,
               tree.direct ? "tree" : "lut", (int)seed_package);

    g_candidate_id++;
    if (run_one_memory_package(seed_package, -1, 0U, 0, &policy) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    print_calibration_trace("policy", 0U, &policy, "selected",
                            tree.direct ? "policy_replay" : "fallback_lut");
    copy_result(&best, &policy);

    /* Twelve local MP candidates: C1/C3/C5, real/imaginary, negative/positive. */
    for (coefficient = 0U; coefficient < 3U; ++coefficient) {
        for (upper = 0U; upper < 2U; ++upper) {
            for (direction = 0U; direction < 2U; ++direction) {
                const int delta = direction == 0U ? -64 : 64;
                g_candidate_id++;
                if (run_one_memory_package(seed_package, (int)coefficient, upper,
                                           delta, &trial) != XST_SUCCESS) {
                    return XST_FAILURE;
                }
                if (trial.cost < best.cost) {
                    copy_result(&best, &trial);
                    best_coefficient = (int)coefficient;
                    best_upper = upper;
                    best_delta = delta;
                    print_calibration_trace("search", 0U, &trial, "accept", "lower_cost");
                } else {
                    print_calibration_trace("search", 0U, &trial, "reject", "not_lower_cost");
                }
            }
        }
    }

    g_candidate_id++;
    if (run_one_memory_package(seed_package, best_coefficient, best_upper,
                               best_delta, &trial) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    print_calibration_trace("final", 0U, &trial, "selected", "final_replay");
    calibration_trace_complete();
    xil_printf("CAL_TINYML_HIERARCHY_SELECTED package=%d source=%s local_candidates=14 best_coefficient=%d best_upper=%d best_delta=%d cost=%d\r\n",
               (int)seed_package, tree.direct ? "tree" : "lut", best_coefficient,
               (int)best_upper, best_delta, (int)trial.cost);
    return XST_SUCCESS;
#else
    xil_printf("FAIL TinyML hierarchy requested but its generated policy artifacts are unavailable\r\n");
    return XST_FAILURE;
#endif
}

static int run_safety_seed_policy_demo(void)
{
#if DPD_SAFETY_SEED_POLICY_CONSTANTS_AVAILABLE && DPD_TINYML_PACKAGE_TABLE_V2_AVAILABLE
    dpd_tinyml_raw_input_t raw;
    dpd_tinyml_input_t input;
    dpd_safety_seed_result_t seed;
    CalibrationResult policy;
    CalibrationResult trial;
    CalibrationResult best;
    int best_coefficient = -1;
    u32 best_upper = 0U;
    int best_delta = 0;
    u32 coefficient;
    u32 upper;
    u32 direction;

    if (DPD_SAFETY_SEED_POLICY_DIRECT_ALLOWED != 0U ||
        DPD_SAFETY_SEED_POLICY_LOCAL_CANDIDATES != 14U) {
        xil_printf("FAIL safety seed policy must keep direct disabled and 14-candidate search enabled\r\n");
        return XST_FAILURE;
    }
    if (load_observer_v2_input(&raw) != XST_SUCCESS ||
        dpd_tinyml_build_features(&raw, &input) == 0) {
        xil_printf("FAIL safety seed policy requires completed aligned_complex_pa_monitor_v2 feedback\r\n");
        return XST_FAILURE;
    }
    seed = dpd_safety_seed_policy_predict(&input);
    if (seed.safety_qualified == 0U ||
        seed.seed_package >= DPD_TINYML_PACKAGE_TABLE_V2_COUNT ||
        seed.local_candidates != 14U) {
        xil_printf("FAIL safety seed policy requested fallback_14; no package seed is authorized for this test\r\n");
        return XST_FAILURE;
    }

    xil_printf("\r\n=== Test-only safety-first seed plus mandatory 14-candidate MP search ===\r\n");
    print_calibration_config();
    xil_printf("CAL_SAFETY_SEED_POLICY_TEST package=%d qualified=%d support=%d distance_sq_q40_lo=0x%08x board_enable=%d direct=0 local_candidates=14\r\n",
               (int)seed.seed_package, (int)seed.safety_qualified,
               (int)seed.safe_support, (u32)seed.nearest_distance_sq_q40,
               (int)DPD_SAFETY_SEED_POLICY_BOARD_ENABLE_ALLOWED);

    g_candidate_id++;
    if (run_one_memory_package(seed.seed_package, -1, 0U, 0, &policy) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    print_calibration_trace("policy", 0U, &policy, "selected", "policy_replay");
    copy_result(&best, &policy);

    /* Twelve local MP perturbations: C1/C3/C5, real/imaginary, negative/positive. */
    for (coefficient = 0U; coefficient < 3U; ++coefficient) {
        for (upper = 0U; upper < 2U; ++upper) {
            for (direction = 0U; direction < 2U; ++direction) {
                const int delta = direction == 0U ? -64 : 64;
                g_candidate_id++;
                if (run_one_memory_package(seed.seed_package, (int)coefficient, upper,
                                           delta, &trial) != XST_SUCCESS) {
                    return XST_FAILURE;
                }
                if (trial.cost < best.cost) {
                    copy_result(&best, &trial);
                    best_coefficient = (int)coefficient;
                    best_upper = upper;
                    best_delta = delta;
                    print_calibration_trace("search", 0U, &trial, "accept", "lower_cost");
                } else {
                    print_calibration_trace("search", 0U, &trial, "reject", "not_lower_cost");
                }
            }
        }
    }

    g_candidate_id++;
    if (run_one_memory_package(seed.seed_package, best_coefficient, best_upper,
                               best_delta, &trial) != XST_SUCCESS) {
        return XST_FAILURE;
    }
    print_calibration_trace("final", 0U, &trial, "selected", "final_replay");
    calibration_trace_complete();
    xil_printf("CAL_SAFETY_SEED_POLICY_SELECTED package=%d local_candidates=14 best_coefficient=%d best_upper=%d best_delta=%d cost=%d\r\n",
               (int)seed.seed_package, best_coefficient, (int)best_upper,
               best_delta, (int)trial.cost);
    return XST_SUCCESS;
#else
    xil_printf("FAIL safety seed policy requested but generated constants or MP package table are unavailable\r\n");
    return XST_FAILURE;
#endif
}

int main(void)
{
    calibration_trace_init();
    xil_printf("\r\nZU15EG DSM DPD bare-metal smoke\r\n");
    xil_printf("DSM_BASEADDR = 0x%08x\r\n", (u32)DSM_BASEADDR);
    xil_printf("DMA_DEV_ID   = %d\r\n", DMA_DEV_ID);

    if (setup_dma() != XST_SUCCESS) {
        xil_printf("FAIL DMA setup\r\n");
        return XST_FAILURE;
    }

    publish_runtime_condition();

    if (CAL_REPLAY_ONLY != 0U) {
        if (run_replay_demo() != XST_SUCCESS) {
            xil_printf("FAIL bare-metal calibration replay\r\n");
            return XST_FAILURE;
        }
        xil_printf("\r\nPASS ZU15EG DSM DPD bare-metal calibration replay completed\r\n");
        return XST_SUCCESS;
    }

    if (CAL_AI_POLICY_ONLY != 0U) {
        if (run_ai_policy_demo() != XST_SUCCESS) {
            xil_printf("FAIL bare-metal AI policy replay\r\n");
            return XST_FAILURE;
        }
        xil_printf("PASS bare-metal AI seed plus bounded search\r\n");
        return 0;
    }

    if (CAL_TINYML_HIERARCHY_ONLY != 0U) {
        if (run_tinyml_hierarchy_demo() != XST_SUCCESS) {
            xil_printf("FAIL bare-metal observer-v2 TinyML hierarchy replay\r\n");
            return XST_FAILURE;
        }
        xil_printf("PASS bare-metal observer-v2 TinyML hierarchy plus bounded search\r\n");
        return XST_SUCCESS;
    }

    if (CAL_SAFETY_SEED_POLICY_ONLY != 0U) {
        if (run_safety_seed_policy_demo() != XST_SUCCESS) {
            xil_printf("FAIL bare-metal test-only safety seed policy replay\r\n");
            return XST_FAILURE;
        }
        xil_printf("PASS bare-metal test-only safety seed plus bounded search\r\n");
        return XST_SUCCESS;
    }

    if (CAL_TRACE_POLICY_ONLY != 0U) {
        if (run_trace_policy_demo() != XST_SUCCESS) {
            xil_printf("FAIL bare-metal trace policy replay\r\n");
            return XST_FAILURE;
        }
        xil_printf("\r\nPASS ZU15EG DSM DPD trace policy replay completed\r\n");
        return XST_SUCCESS;
    }

    if (run_calibration_demo() != XST_SUCCESS) {
        xil_printf("FAIL bare-metal calibration demo\r\n");
        return XST_FAILURE;
    }

    xil_printf("\r\nPASS ZU15EG DSM DPD bare-metal calibration demo completed\r\n");
    return XST_SUCCESS;
}
