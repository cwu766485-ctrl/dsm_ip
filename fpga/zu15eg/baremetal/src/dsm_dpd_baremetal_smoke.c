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

#define DPD_MODE_BYPASS 0U
#define DPD_MODE_POLY   1U
#define DPD_MODE_LUT    2U

#define CAL_PENALTY_SATURATION 1000000U
#define CAL_PENALTY_ERROR      1000000U
#define CAL_PENALTY_STALL      100000U
#define CAL_PENALTY_CLIP       1000000U
#define CAL_EVM_PROXY_SHIFT    8U
#define CAL_ACPR_PROXY_SHIFT   10U
#define CAL_SPEC_ADJ_SHIFT     10U

#define CAL_SEARCH_STEP_Q214   64
#define CAL_SEARCH_MAX_ROUNDS  1U

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

static XAxiDma AxiDma;
static u32 TxBuffer[DMA_WORDS] __attribute__((aligned(64)));

static inline u32 dsm_read(u32 offset)
{
    return Xil_In32(DSM_BASEADDR + offset);
}

static inline void dsm_write(u32 offset, u32 value)
{
    Xil_Out32(DSM_BASEADDR + offset, value);
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
    return proxy_evm_ppm +
           (saturation_count * CAL_PENALTY_SATURATION) +
           (clip_count * CAL_PENALTY_CLIP) +
           (error_status * CAL_PENALTY_ERROR) +
           (stall_count * CAL_PENALTY_STALL) +
           (evm_proxy >> CAL_EVM_PROXY_SHIFT) +
           (acpr_proxy >> CAL_ACPR_PROXY_SHIFT) +
           (spec_adj_proxy >> CAL_SPEC_ADJ_SHIFT);
}

static int check_counters(void)
{
    int status = XST_SUCCESS;
    status |= expect_eq("INPUT_SAMPLE_COUNT", dsm_read(DSM_INPUT_SAMPLE_COUNT), DMA_WORDS);
    status |= expect_eq("FRONTEND_SAMPLE_COUNT", dsm_read(DSM_FRONTEND_SAMPLE_COUNT), DMA_WORDS);
    status |= expect_eq("DPD_SAMPLE_COUNT", dsm_read(DSM_DPD_SAMPLE_COUNT), DMA_WORDS);
    status |= expect_eq("OUTPUT_SAMPLE_COUNT", dsm_read(DSM_OUTPUT_SAMPLE_COUNT), DMA_WORDS);
    status |= expect_eq("INPUT_STALL_COUNT", dsm_read(DSM_INPUT_STALL_COUNT), 0U);
    status |= expect_eq("ERROR_STATUS", dsm_read(DSM_ERROR_STATUS), 0U);
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

static int run_one_mode(u32 mode, u32 package_idx, CalibrationResult *result)
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
    if (check_counters() != XST_SUCCESS) {
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

    xil_printf("PASS selected DPD package is retained in PL registers\r\n");
    return XST_SUCCESS;
}

static int run_poly_search_loop(const CalibrationResult *seed,
                                CalibrationResult *best)
{
    CalibrationResult trial;
    u32 coeff_words[3];

    if (seed->mode != DPD_MODE_POLY || seed->package_idx >= DSM_DPD_NUM_PACKAGES) {
        xil_printf("\r\n=== PS coefficient search skipped: no polynomial seed ===\r\n");
        return XST_SUCCESS;
    }

    xil_printf("\r\n=== PS-side polynomial coefficient search ===\r\n");
    xil_printf("SEARCH seed package=%d step=%d rounds=%d\r\n",
               (int)seed->package_idx, CAL_SEARCH_STEP_Q214,
               (int)CAL_SEARCH_MAX_ROUNDS);

    coeff_words[0] = seed->c1_word;
    coeff_words[1] = seed->c3_word;
    coeff_words[2] = seed->c5_word;

    for (u32 round = 0; round < CAL_SEARCH_MAX_ROUNDS; round++) {
        for (u32 coeff = 0; coeff < 3U; coeff++) {
            for (u32 part = 0; part < 2U; part++) {
                for (u32 dir_idx = 0; dir_idx < 2U; dir_idx++) {
                    int delta = (dir_idx == 0U) ? -CAL_SEARCH_STEP_Q214 : CAL_SEARCH_STEP_Q214;
                    u32 cand[3];
                    cand[0] = coeff_words[0];
                    cand[1] = coeff_words[1];
                    cand[2] = coeff_words[2];
                    cand[coeff] = perturb_coeff_word(cand[coeff], part, delta);

                    if (run_one_poly_candidate(seed->package_idx, cand[0], cand[1], cand[2], &trial) != XST_SUCCESS) {
                        return XST_FAILURE;
                    }
                    if (trial.cost < best->cost) {
                        xil_printf("SEARCH_ACCEPT coeff=%d part=%d delta=%d old_cost=%d new_cost=%d\r\n",
                                   (int)coeff, (int)part, delta,
                                   (int)best->cost, (int)trial.cost);
                        copy_result(best, &trial);
                        coeff_words[0] = trial.c1_word;
                        coeff_words[1] = trial.c3_word;
                        coeff_words[2] = trial.c5_word;
                    }
                }
            }
        }
    }

    return XST_SUCCESS;
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

    for (u32 pkg = 0; pkg < DSM_DPD_NUM_PACKAGES; pkg++) {
        if (run_one_mode(DPD_MODE_POLY, pkg, &trial) != XST_SUCCESS) {
            return XST_FAILURE;
        }
        if (trial.cost < best.cost) {
            copy_result(&best, &trial);
        }
        if (trial.cost < best_poly.cost) {
            copy_result(&best_poly, &trial);
        }
    }

    for (u32 pkg = 0; pkg < DSM_DPD_NUM_PACKAGES; pkg++) {
        if (run_one_mode(DPD_MODE_LUT, pkg, &trial) != XST_SUCCESS) {
            return XST_FAILURE;
        }
        if (trial.cost < best.cost) {
            copy_result(&best, &trial);
        }
    }

    if (run_poly_search_loop(&best_poly, &best) != XST_SUCCESS) {
        return XST_FAILURE;
    }

    return apply_selected_package(&best);
}

int main(void)
{
    xil_printf("\r\nZU15EG DSM DPD bare-metal smoke\r\n");
    xil_printf("DSM_BASEADDR = 0x%08x\r\n", (u32)DSM_BASEADDR);
    xil_printf("DMA_DEV_ID   = %d\r\n", DMA_DEV_ID);

    if (setup_dma() != XST_SUCCESS) {
        xil_printf("FAIL DMA setup\r\n");
        return XST_FAILURE;
    }

    if (run_calibration_demo() != XST_SUCCESS) {
        xil_printf("FAIL bare-metal calibration demo\r\n");
        return XST_FAILURE;
    }

    xil_printf("\r\nPASS ZU15EG DSM DPD bare-metal calibration demo completed\r\n");
    return XST_SUCCESS;
}
