# BP 主 SKU Lint 审计与精简决策

更新时间：2026-08-09

## 1. 审计配置

```text
top                 = dsm_ip_axi_top
ALGORITHM           = 3
DUC_MODE            = 3
INTERP_MODE         = 4
INTERP_IMPL         = 0
DPD_POLY_ORDER      = 5
DPD_MP_MAX_TAPS     = 4
ENABLE_DPD_POLY     = 0
ENABLE_DPD_LUT      = 0
ENABLE_DPD_MEMORY   = 1
```

主要证据：`syn/reports/lint_bp_ef2_axi_20260806_214119/`

DC 已完成 analyze、elaborate、link、check_design 和 check_timing，Error/Fatal 为 0。SpyGlass 未在当前环境执行，因此不能宣称 SpyGlass 通过。

## 2. 警告清单

| 项目 | 数量 | 判断 |
|---|---:|---|
| `LINT-28` 未连接端口 | 226 | 混合了地址位、disabled feature 和兼容端口 |
| `LINT-31` 输出短接 | 73 | 包含状态别名和编译期裁剪后的常量输出 |
| `LINT-52` 常量输出 | 74 | 多为 disabled LUT 和 BP 兼容输出 |
| `LINT-1` cell 未驱动 | 101 | 必须结合源代码检查，不能盲目 waiver |
| `LINT-2` 未加载网络 | 80 | 部分可删，部分属于调试/状态 |
| `LINT-32` 电源/地连接 | 2 | 插值实例中的常量控制 |
| `LINT-33` 同一网络连接多个 pin | 5 | 需排除错误 alias |
| `VER-318` signedness | 129 | 功能风险，必须用 bit-true 证明 |
| `HDL-193` 宽度/表达式 | 15 | 功能风险，需对照定点参考 |
| `ELAB-311` 不可达 default | 1 | 低风险，需记录配置假设 |

报告计数是结构项数量，不一定对应独立 RTL 行。

## 3. 风险分类

### 3.1 暂不允许 waiver

- DPD、observer、插值和 DSM 算术中的 signed/unsigned 转换；
- 位宽、算术右移、截断和饱和相关警告；
- AXI handshake、reset、`rf_valid/rf_bit/rf_signed`；
- memory-poly 输出和系数 commit；
- `LINT-33` 多 pin alias。

只有完成逐样本 bit-true、协议断言和边界测试后才能决定修复或 waiver。

### 3.2 BP 兼容输出

`DUC_MODE=3` 使用 `rf_valid/rf_bit/rf_signed`，旧 `i_bit/q_bit/i_yout/q_yout` 在该模式下为兼容端口。完整兼容 SKU 保留这些端口；新的 BP-lite 顶层可以删除，但必须同步 IP 包、软件、testbench 和约束。

### 3.3 编译期裁剪

主 SKU 已禁用 memoryless polynomial 和 LUT 分支。相关常量/未连接警告是 BP-lite 最明确的精简候选。

可在独立 `BP_EF2_LITE_TX` SKU 中删除：

- polynomial datapath 和 C1/C3/C5/C7 runtime 寄存器；
- LUT datapath、bank 和寄存器；
- transmit-only 版本中的 observer、seed predictor 和反馈窗口；
- 新非兼容顶层中的 Cartesian 输出。

现有 `dsm_ip_axi_top` 仍保持完整兼容，不能直接删除这些能力。

## 4. BP-lite 必须保留

- AXI4-Lite 和 TX AXI4-Stream；
- x32 插值、Fs/4 mixer、BP EFDSM2；
- `rf_valid/rf_bit/rf_signed`；
- Memory-Poly5 4-tap DPD；
- shadow bank、safe commit、系数范围、saturation fallback；
- reset、backpressure、tlast/tuser；
- 必要的 sample/frame/stall/error 和 sticky status。

## 5. 精简验证门槛

独立 BP-lite SKU 必须完成：

1. DC lint，具备环境后补 SpyGlass；
2. 与完整 SKU 的逐样本等价；
3. XSim/UVM reset、backpressure 和 safety 回归；
4. ZU15EG OOC/routed PPA 对比；
5. AXI-Lite register map 和 PS 软件编译检查。

全部通过前，完整 `dsm_ip_axi_top` 仍是 source of truth。

## 6. 当前结论

当前 lint 流程结构完整但并不干净。可以删除工具生成物，不能为了减少警告盲删 RTL。最合理的产品化方式是保留完整开发 SKU，并新增经过等价和 PPA 验证的 BP-lite compile-time SKU。
