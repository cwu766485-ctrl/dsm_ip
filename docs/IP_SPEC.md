# DSM + DPD 数字发射机 IP 规格

## 1. 文档范围

本文档定义当前可复用数字发射机 IP 的 RTL 接口、数据通路、可编译
SKU、控制行为以及已完成的验证和实现边界。Vivado 打包顶层为：

```text
rtl/axi/dsm_ip_axi_top.v
```

不含 AXI 的可复用流式数据通路为：

```text
rtl/ip/dsm_ip_top.v
rtl/ip/dsm_ip_core.sv
```

本文档中的时序、资源和功耗数据必须结合其工具、器件和约束范围理解；
它们不是 ASIC 签核或物理 RF 指标。

## 2. 当前主推 SKU

当前完成 FPGA 路由并适合作为集成/作品集演示的 Performance SKU 如下。

| 项目 | 编译期配置 |
|---|---|
| DSM | `ALGORITHM=2`，一位 EFDSM |
| 插值 | `INTERP_MODE=4`，x32 前端 |
| 上变频 | `DUC_MODE=0`，固定 Fs/4 |
| DPD 阶数 | `DPD_POLY_ORDER=5` |
| Memory-Poly 深度 | `DPD_MP_MAX_TAPS=4` |
| 独立多项式 DPD | `ENABLE_DPD_POLY=0` |
| LUT DPD | `ENABLE_DPD_LUT=0` |
| Memory-Poly DPD | `ENABLE_DPD_MEMORY=1` |
| 主时钟 | 100 MHz |
| 基带采样率 | 3.125 MHz |
| 标称信号带宽 | 2.539062 MHz |
| 标称中频 | 25 MHz（100 MHz 的 Fs/4） |

该 SKU 保留 AXI-Lite 控制、AXI-Stream 输入、DPD 系数双 bank 安全切换、
反馈 observer 和运行状态/计数器。独立多项式和 LUT DPD 在综合时被裁剪，
因此不构成该 SKU 的硬件资源。

## 3. 顶层架构

```text
                       AXI-Lite 控制/状态/系数寄存器
                                      │
TX AXI-Stream IQ ──> skid buffer ──> DPD 前端 ──> 插值 ──> DSM ──> Fs/4 DUC ──> RF/IF
                                      │
观测 AXI-Stream IQ ───────────────> observer ──> 误差、削顶、频谱代理、IRQ
```

主 TX 数据通路中的处理顺序为：

1. 接收 Q1.15 复数基带 I/Q；
2. 使用一项 skid buffer 处理合法反压；
3. 使用当前启用的 DPD 路径生成预失真 I/Q；
4. 将低速基带 I/Q 插值到 DSM 时钟速率；
5. 由 I、Q 两个 DSM 核产生量化输出；
6. 使用固定 Fs/4 的 I/Q 合成生成单路实数 RF/IF 输出。

observer 是并行反馈支路：它以接受的原始 TX I/Q 为参考，和
`s_axis_obs_*` 反馈流进行可编程延迟与复数增益对齐。observer 不会反压
TX 输入流。

## 4. 时钟和复位

| 信号 | 方向 | 说明 |
|---|---|---|
| `aclk` | 输入 | IP、AXI-Lite、TX 流和 observer 的主时钟 |
| `aresetn` | 输入 | 异步低有效复位 |

- 当前完整 TX 集成使用一个 100 MHz `pl_clk0` 时钟域。
- `CTRL.soft_reset` 会产生数据通路软复位脉冲，并清除 skid buffer；复位
  边界上的未完成样本会被丢弃，不会重放。
- `s_axis_obs_*` 必须与 `aclk` 同步。若反馈 ADC/RF 接收机使用其他时钟，
  必须在 IP 外部插入 AXI-Stream Clock Converter 或异步 FIFO。

## 5. 外部接口

### 5.1 AXI-Lite 控制接口 `s_axi`

默认地址宽度为 9 bit，数据宽度为 32 bit。写通道支持 AW 和 W 独立到达：
顶层分别暂存地址和数据，二者齐备后执行写事务。

| 通道 | 主机到 IP | IP 到主机 |
|---|---|---|
| 写地址 | `s_axi_awaddr`、`s_axi_awvalid` | `s_axi_awready` |
| 写数据 | `s_axi_wdata`、`s_axi_wstrb`、`s_axi_wvalid` | `s_axi_wready` |
| 写响应 | `s_axi_bready` | `s_axi_bresp`、`s_axi_bvalid` |
| 读地址 | `s_axi_araddr`、`s_axi_arvalid` | `s_axi_arready` |
| 读数据 | `s_axi_rready` | `s_axi_rdata`、`s_axi_rresp`、`s_axi_rvalid` |

### 5.2 TX AXI-Stream 输入 `s_axis`

| 信号 | 方向 | 说明 |
|---|---|---|
| `s_axis_tdata[31:0]` | 输入 | `tdata[15:0]` 为 signed Q1.15 I；`tdata[31:16]` 为 signed Q1.15 Q |
| `s_axis_tvalid` | 输入 | 上游数据有效 |
| `s_axis_tready` | 输出 | IP 可以接收数据 |
| `s_axis_tlast` | 输入 | 可选帧标志；用于帧计数 |
| `s_axis_tuser[0]` | 输入 | 上游错误/标签；非零被记录为 sticky error 和计数 |

一个 TX 样本仅在 `s_axis_tvalid && s_axis_tready` 时被接受。`tready` 会在
IP 未使能、复位、内部反压或 Memory-Poly bank 提交窗口中撤销。

### 5.3 观测 AXI-Stream 输入 `s_axis_obs`

`s_axis_obs_tdata` 采用与 TX 输入相同的 Q1.15 I/Q 打包。`tlast` 标记观测
窗口/帧结束，`tuser[0]=1` 表示该反馈样本无效。

| 信号 | 方向 | 说明 |
|---|---|---|
| `s_axis_obs_tdata[31:0]` | 输入 | 观测 I/Q，Q1.15 |
| `s_axis_obs_tvalid` | 输入 | 观测样本有效 |
| `s_axis_obs_tready` | 输出 | 仅在显式启动的 observer 窗口中接收 |
| `s_axis_obs_tlast` | 输入 | 观测窗口/帧结束标记 |
| `s_axis_obs_tuser[0]` | 输入 | 无效观测样本标志 |
| `obs_irq` | 输出 | observer 完成窗口时的可选电平中断 |

### 5.4 DSM 与 RF/IF 输出

| 信号 | 说明 |
|---|---|
| `dsm_valid` | DSM I/Q 输出有效 |
| `i_bit`、`q_bit` | 一位 DSM 输出；1 表示正满幅，0 表示负满幅 |
| `i_yout`、`q_yout` | 有符号 DSM 调试/多位输出 |
| `rf_valid` | 单路 RF/IF 输出有效 |
| `rf_bit` | 一位 RF/IF 输出 |
| `rf_signed[15:0]` | 有符号实数 RF/IF 输出 |
| `phase_acc_dbg[23:0]` | Fs/4 相位或 NCO 相位累加器调试输出 |

## 6. 可编译结构参数

下列结构由参数在综合/实现前决定，运行时不能通过 AXI-Lite 切换：

| 参数 | 可选值/含义 |
|---|---|
| `ALGORITHM` | 0 LPDSM，1 LPDSM2，2 EFDSM，3 EFDSM2，4 MASH11，5 MASH111，6 MASH22；另有探索性多位模式 |
| `INTERP_MODE` | 0 bypass，1 x4，2 x8，3 x16，4 x32 |
| `DUC_MODE` | 0 固定 Fs/4，1 可配置 NCO |
| `DPD_POLY_ORDER` | Memoryless 多项式的 3、5 或 7 阶配置；Memory-Poly 使用 C1/C3/C5 |
| `DPD_MP_MAX_TAPS` | 1、2、4 或 6 tap 的编译期最大深度 |
| `ENABLE_DPD_*` | 是否保留多项式、LUT、Memory-Poly DPD 分支 |

`ALGORITHM`、`DUC_MODE`、`INTERP_MODE` 和 DPD capability 的只读寄存器仅报告
当前编译的硬件，不会选择运行时大 mux。

## 7. DPD 前端

DPD 输入输出均为 signed Q1.15 复数 I/Q，系数和 LUT 增益为 signed Q2.14
复数数值。

运行时 `DPD_CTRL[1:0]` 请求的模式为：

| 值 | 模式 |
|---:|---|
| 0 | bypass |
| 1 | 无记忆多项式 DPD |
| 2 | 按幅度索引的 LUT DPD |
| 3 | Memory-Polynomial DPD |

请求模式若已被编译期裁剪，或安全机制触发 fallback，`EFFECTIVE_STATUS` 会报告
实际有效模式；软件不能只根据请求值假设 DPD 已生效。

Memory-Polynomial 的五阶形式为：

```text
y[n] = Σm x[n-m] · (C1[m] + C3[m]·|x[n-m]|² + C5[m]·|x[n-m]|⁴)
```

系数按 tap 与阶数写入 inactive bank。提交时，顶层先撤销 TX `tready`，等待
已接受数据和 DPD 十级流水排空，在安全边界切换 active bank，然后置位
`MP_COMMIT_STATUS.commit_ack` 并递增 `commit_epoch`。因此该接口支持有界窗口
更新，而不是无缝的逐样本在线系数替换。

DPD 前端将 bypass、LUT、多项式与 Memory-Poly 的输出对齐；在连续无反压条件下，
当前 Memory-Poly 路径固定为十个时钟周期的前端延迟。安全检查可拒绝超出系数幅度
范围的写入或提交，并上报 sticky 状态。

## 8. 插值、DSM 和 DUC

### 8.1 x32 插值

`INTERP_MODE=4` 由两个 x2 halfband 级、一个 x8 固定系数插值 FIR 和一个
补偿 FIR 组成，总插值倍数为 x32。基带 3.125 MHz 输入因此生成 100 MHz 的 DSM
输入序列。插值器通过 `in_valid/in_ready` 接收低速基带样本，并产生高速有效样本。

### 8.2 EFDSM

当前主 SKU 使用一阶一位 error-feedback DSM。I、Q 各使用一个独立核心：

```text
y[n] = x[n] + e[n-1]
q[n] = sign(y[n])
e[n] = y[n] - q[n]
```

量化输出 `q[n]` 为正满幅或负满幅。可运行时配置的 `DSM_CTRL[3:0]` 只对 DPD
输出施加有符号右移，作为数字 backoff；它不会改变 DSM 阶数、插值模式或 DUC 结构。

### 8.3 固定 Fs/4 DUC

在 `DUC_MODE=0` 时，DUC 使用两位相位计数器依次选择：

| 相位 | RF/IF 输出 |
|---:|---|
| 0 | `+I` |
| 1 | `+Q` |
| 2 | `-I` |
| 3 | `-Q` |

该实现不需要 NCO 查表或复数乘法。在 100 MHz 时钟下，标称载波为 25 MHz。

`DUC_MODE=1` 是用于非 Fs/4 实验的可选 NCO 路径，频率由
`cfg_phase_inc / 2^PHASE_W × f_clk` 决定。它不在当前主 SKU 中综合；若用于
ASIC，正余弦查表初始化必须替换为工艺适配的 ROM 或 CORDIC 实现。

## 9. observer 与运行监控

observer 使用 32 样本参考环形缓冲区。`OBS_CTRL.delay=0` 表示与同周期参考样本
配对，`delay=N` 表示选择 N 个已接受参考样本之前的参考值。观测 IQ 先进行可编程
Q2.14 复数增益校正，再计算并导出：

- 有效配对数和丢弃数；
- 64 bit 对齐 L1 误差累加；
- 参考/观测幅度、峰值、削顶和饱和计数；
- 复数一阶差分 slew 代理；
- DC、Fs/4、Fs/2 固定频点频谱代理和相邻频段代理；
- 启动时锁存的 Q8.8 温度。

这些指标用于软件校准、调试和候选 DPD 包排序；它们不是具有完整接收机重构链路的
正式 EVM、ACLR、ACPR 或 SNDR 签核测量。

## 10. 关键寄存器组

完整寄存器含义见 `docs/IP_HANDOFF.md`。常用地址如下：

| 地址 | 名称 | 主要用途 |
|---:|---|---|
| `0x00` | `CTRL` | enable、软复位、清计数/状态 |
| `0x08` | `CFG_PHASE_INC` | NCO 模式下的相位增量 |
| `0x40` | `DPD_CTRL` | DPD 请求模式与安全控制 |
| `0x44`/`0x48`/`0x4C` | `DPD_C1/C3/C5` | 无记忆多项式系数 |
| `0x90`/`0x94` | `MP_SELECT/MP_DATA` | inactive Memory-Poly bank 的 tap/阶数选择和系数写入 |
| `0x98` | `MP_COMMIT` | 请求安全 bank 切换 |
| `0x9C` 至 `0xFC` | `OBS_*` | observer 窗口、对齐、统计和频谱代理 |
| `0x100` | `DPD_C7` | 七阶无记忆多项式系数 |
| `0x104` | `DSM_CTRL` | DSM 输入右移 backoff |
| `0x108`/`0x10C` | `CAPABILITY/EFFECTIVE_STATUS` | 已编译 capability 和实际 DPD 状态 |
| `0x110` | `MP_COMMIT_STATUS` | 提交确认、pending/inflight/failed 和 epoch |
| `0x114` 至 `0x11C` | `OBS_SNAPSHOT*` | 原子读取 64 bit observer 误差快照 |

推荐的软件启动顺序为：复位释放后清状态；写入并提交 DPD inactive bank 系数；确认
commit acknowledge；设置需要的 DPD mode；最后置 `CTRL.enable` 并启动 DMA。若要
软复位，软件应先停止 DMA，再等待复位释放后重新清状态并使能数据流。

## 11. 已完成验证与实现

- 七条保留 DSM 路径已完成 MATLAB/RTL bit-true 对比，65536 样本向量无 mismatch。
- XSim 七路径回归和 IP smoke 已通过；IP smoke 覆盖流式顶层、NCO 路径和 AXI
  包装器握手。
- DPD 的 3/5/7 阶、1/2/4/6 tap 配置矩阵，以及协议、backpressure、安全 bank
  提交和 observer 场景已完成 RTL/XSim 验证。
- Vivado IP 打包已生成 `dsm_ip_axi_top` 的 IP-XACT 组件。
- 当前 Performance SKU 已在 `xczu15eg-ffvb1156-2-i` 完成 100 MHz 布局布线、
  bitstream 和 XSA 导出：WNS +2.314 ns、TNS 0、16,296 LUT、20,763 FF、3.0 BRAM、
  266 DSP48E2。该结果是 FPGA 集成证据，不代表物理 PA 线性化或板级 RF 指标。

## 12. 28 nm 预综合边界

同一完整 Performance SKU 曾在 28 nm RVT、SS、0.72 V、125 C 单角逻辑综合中，
以 100 MHz、0.2 ns clock uncertainty、1 ns 最大输入/输出延迟约束得到 +1.22 ns
setup slack。固定映射与约束下的零 setup slack 估算约为 113.9 MHz，标准单元面积
约 120,392 um^2。

这不是 ASIC 签核结果：该次 run 仍有最差 -0.11 ns hold 违例、20,802 条 hold
违例和一个最大 transition 违例，且没有布局布线 RC、CTS、DFT、SRAM/IO 或多角多
模式分析。因此可以表述为“100 MHz 通过预布局 setup 检查，约 114 MHz 是预布局
setup 估算”，不可表述为“114 MHz 已完成 ASIC 时序闭合”。

## 13. 当前限制

- observer 多时钟 CDC 不在 `dsm_ip_axi_top` 内部实现；异步反馈必须使用外部桥接。
- observer 监控量是低成本代理指标，不替代正式 RF 性能测量。
- 当前 AI/安全策略的板级部署仍保持保守的有界搜索；不应将离线行为模型结果表述为
  已验证的物理 PA 自适应闭环。
- NCO 是可选实验路径，主 SKU 使用固定 Fs/4 以获得更小且确定的硬件实现。
- 28 nm 结果等待可用的 Design Compiler license 后，仍需以正确的 setup/hold PVT
  组合和后端实现重新评估。

## 14. 相关文件

| 文件 | 内容 |
|---|---|
| `rtl/axi/dsm_ip_axi_top.v` | 完整 AXI 顶层、DPD/observer/监控集成 |
| `rtl/dpd/dpd_frontend.v` | DPD 模式、十级对齐流水和系数 bank 管理 |
| `rtl/dpd/dpd_memory_poly.v` | Memory-Polynomial 数据通路 |
| `rtl/interp/dsm_interp_frontend.sv` | bypass/x4/x8/x16/x32 插值选择 |
| `rtl/ip/dsm_ip_top.v` | 流式插值、DSM 和 DUC 连接 |
| `rtl/ip/dsm_ip_core.sv` | DSM 与 DUC 的编译期选择 |
| `docs/IP_HANDOFF.md` | 完整寄存器表和软件/接口交接说明 |
| `docs/FULL_TX_IMPLEMENTATION.md` | 已完成 ZU15EG 集成与实现证据 |
| `docs/PORTFOLIO_SKU.md` | 面试演示 SKU 与 28 nm 预综合说明 |
