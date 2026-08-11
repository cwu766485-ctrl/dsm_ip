# DSM/DPD 数字发射机 IP 详细规格

文档版本：1.1
更新时间：2026-08-09

适用顶层：`rtl/axi/dsm_ip_axi_top.v`

适用主验证 SKU：`ALGORITHM=3, DUC_MODE=3, INTERP_MODE=4, INTERP_IMPL=0`

状态：工程交付规格。RF/硅后指标除非特别注明均不属于本规格保证值。

## 0. 主验证对象

本项目的主验证不是所有 DSM 和所有 DPD 分支的混合比较，而是下面这一条固定链路：

```text
Q1.15 complex IQ
  -> 针对 behavioral DPA 训练/量化的 DPD
  -> x32 interpolation
  -> full-precision Fs/4 real-IF mixer
  -> one-bit BP EFDSM2
  -> rf_bit/rf_signed
  -> behavioral DPA + output BPF
  -> complex observation/receiver
  -> EVM/SNDR/ACLR proxy
```

### 0.1 DSM 主验证对象：BP EFDSM2

主验证 DSM 是**二阶一位带通误差反馈 DSM（BP EFDSM2）**。它不是旧的低通 LPDSM2，也不是把低通 I/Q 一位输出做 `[+I,+Q,-I,-Q]` 合路的旧 DUC。

BP EFDSM2 的 RTL 实现链为：

- `rtl/tx_bandpass_if/bp_fs4_iq_mixer.sv`：将复数 I/Q 变成全精度实数 Fs/4 IF；
- `rtl/tx_bandpass_if/dsm_core_bp_ef2.sv`：BP EF2 一位量化器封装；
- `rtl/tx_bandpass_if/tx_bp_if_top.sv`：Mixer 与 BP EF2 的连接；
- `rtl/ip/dsm_ip_top.v`：`DUC_MODE=3` 生成 BP 路径；
- `rtl/axi/dsm_ip_axi_top.v`：AXI 交付顶层。

`dsm_core_bp_ef2` 复用通用 `dsm_core_ef2`，固定 `B1=0`、`B2=-1`，用于 Fs/4 中心附近的带通噪声整形。`ALGORITHM=3` 是 AXI/综合 SKU 的 build identity；当 `DUC_MODE=3` 时，`dsm_ip_top` 不进入 Cartesian `dsm_ip_core` 的 EF2 分支，而是固定实例化 `BP_ALGORITHM=1`，即 `dsm_core_bp_ef2`。

### 0.2 DPD 主验证对象：针对 behavioral DPA

DPD 的被测对象是 MATLAB behavioral DPA 模型。该模型受控地产生 AM/AM、AM/PM、记忆、压缩、噪声、温漂和观测反馈。DPD 验证必须在同一 behavioral DPA、同一波形、同一接收机和 held-out 数据上比较：

1. no-DPD；
2. memoryless DPD；
3. memory-polynomial DPD；
4. AI/LUT seed 加确定性 bounded local search。

主 SKU 的 RTL DPD 是 Q2.14、C1/C3/C5、4-tap、5th-order memory-polynomial，用于承接针对 behavioral DPA 拟合、量化并通过安全检查的系数。memoryless DPD 和其他模型是验证对照，不是当前主 SKU 的综合配置。

这里的 behavioral DPA 不是 ADS 电路，也不是实测 PA。ADS/PDK-MOS 结果必须单独标注来源，不能直接作为本 DPD 训练结果。

### 0.3 RTL 与 behavioral DPA 的关系

RTL 实现确定性的 DPD、插值、BP EFDSM2、监控和安全逻辑；behavioral DPA 位于 MATLAB 闭环的 RTL 输出之后。系数先针对 behavioral DPA 训练和 held-out 验证，再量化为 RTL 使用的 Q2.14 常量。RTL 本身不包含模拟 DPA。

## 1. 目的与范围

本 IP 将复数基带 I/Q 样本转换为确定性的定点 DSM 发射数据。交付验证以 BP EFDSM2 主链路为准，同时保留若干兼容和研究分支。IP 包含：

- AXI4-Lite 控制和状态寄存器；
- TX AXI4-Stream 复数样本输入；
- 可选反馈 AXI4-Stream 和 DPD observer；
- bypass、memoryless polynomial、LUT、memory-polynomial DPD 分支；
- x4/x8/x16/x32 插值前端；
- 低通 Cartesian DSM 兼容路径；
- 全精度 Fs/4 IF Mixer 与一位 BP EFDSM2 主验证路径；
- 监控量、错误计数、安全回退和系数 bank commit。

本 IP 不包含：

- 模拟重构滤波器；
- 模拟 IQ Mixer、LO、PA/DPA、输出 BPF；
- ADC、反馈接收机或物理耦合器；
- PA 识别训练服务器；
- 高速神经网络推理单元；
- layout、CTS、寄生提取和 silicon signoff。

## 2. 系统边界

### 2.1 数字主链路

```text
PS/DDR -> AXI DMA MM2S -> AXI4-Stream Q1.15 I/Q
       -> DPD -> 插值 -> DSM/IF -> 输出 bitstream
```

### 2.2 模拟 IQ 路线（次要集成路线）

```text
DPD -> 插值 -> 低通一位 I/Q DSM
     -> 外部重构 LPF -> 模拟 IQ Mixer/LO -> PA
```

使用 `DUC_MODE=2`。输出 `i_bit/q_bit` 有效；`rf_valid=0`。该路线用于外部模拟 IQ 上变频集成，不是当前 BP EFDSM2 + behavioral DPA 主验证对象。

### 2.3 数字 IF 路线（主验证路线）

```text
DPD -> x32 插值 -> 全精度 Fs/4 IF Mixer
     -> BP EFDSM2 -> rf_bit -> 外部 DPA/BPF
```

使用 `DUC_MODE=3`。这是当前 BP EFDSM2 AXI 主验证 SKU。BP IF 算法 RTL 位于 `rtl/tx_bandpass_if/`，由 `rtl/ip/dsm_ip_top.v` 实例化，再由 AXI 顶层连接；其输出再接 behavioral DPA 和统一接收机模型完成 DPD 指标测量。

## 3. 编译期配置

### 3.1 主 SKU 参数

| 参数 | 值 | 含义 |
|---|---:|---|
| `W` | 16 | I/Q 主数据位宽 |
| `DSM_OUT_W` | 8 | Cartesian DSM 输出位宽 |
| `RF_W` | 16 | `rf_signed` 位宽 |
| `PHASE_W` | 24 | 相位/调谐字位宽 |
| `DPD_LUT_AW` | 4 | LUT 地址位宽 |
| `DPD_MP_MAX_TAPS` | 4 | memory-polynomial 最大 tap 数 |
| `DPD_POLY_ORDER` | 5 | 最高奇次阶数 |
| `ENABLE_DPD_POLY` | 0 | 主 SKU 不综合 memoryless polynomial 分支 |
| `ENABLE_DPD_LUT` | 0 | 主 SKU 不综合 LUT 分支 |
| `ENABLE_DPD_MEMORY` | 1 | 综合 memory-polynomial 分支 |
| `ALGORITHM` | 3 | EFDSM2 build identity；BP 分支固定 BP EF2 |
| `DUC_MODE` | 3 | 全精度 IF 后 BP DSM |
| `INTERP_MODE` | 4 | x32 插值 |
| `INTERP_IMPL` | 0 | 默认实现 |
| `CLK_FREQ_HZ` | 100000000 | 时钟元数据 |
| `BB_SAMPLE_RATE_HZ` | 3125000 | 输入采样率元数据 |
| `SIGNAL_BW_HZ` | 2539062 | 信号带宽元数据 |

### 3.2 运行时不可切换项

`ALGORITHM`、`DUC_MODE`、`INTERP_MODE`、`INTERP_IMPL`、DPD 分支 enable 和最大 tap 数均为编译期参数。寄存器中的 build identity 只能读取，不能把一个已综合的 SKU 动态变成另一个 SKU。

## 4. 时钟、复位与吞吐

- 所有顶层 AXI、DPD、插值和 DSM 逻辑使用 `aclk`。
- `aresetn` 为低有效异步复位。
- 释放复位后先完成配置，再设置 `CTRL.bit0=1`。
- 输入数据仅在 `s_axis_tvalid && s_axis_tready` 时被接受。
- 发送端在 backpressure 期间必须保持 payload 和 sideband。
- skid buffer 保留一个输入样本及其 `tlast/tuser`。
- x32 前端把基带输入速率提升到内部 DSM 时钟率；主配置下 3.125 MS/s 对应 100 MHz。
- DPD memory branch 有内部流水线，`out_valid` 可能晚于输入多个周期；软件和 testbench 应使用握手，不得假定零延迟。
- 单个 AXI-Stream 数据通道是单样本/周期上限；实际吞吐受 `tready` 和流水线空闲状态限制。
- `INPUT_STALL_COUNT` 记录 `tvalid=1` 而 `tready=0` 的周期。

## 5. 顶层端口

### 5.1 时钟复位

| 端口 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| `aclk` | Input | 1 | 主时钟 |
| `aresetn` | Input | 1 | 低有效异步复位 |

### 5.2 AXI-Lite

默认 `C_S_AXI_ADDR_WIDTH=9`、`C_S_AXI_DATA_WIDTH=32`。包含 AW、W、B、AR、R 五个标准通道。AW 和 W 可以独立到达，IP 内部保持地址/数据直到组成一次写事务。

写响应和读响应均为 `OKAY`，软件必须遵守 `valid/ready` 握手，不能依赖固定响应周期。

### 5.3 TX AXI-Stream

默认 `C_S_AXIS_TDATA_WIDTH=32`、`C_S_AXIS_TUSER_WIDTH=1`。

```text
tdata[15:0]  = I，signed Q1.15
tdata[31:16] = Q，signed Q1.15
tlast        = 帧尾
tuser[0]     = 上游错误/无效标记
```

### 5.4 反馈 AXI-Stream

默认 `C_S_AXIS_OBS_TDATA_WIDTH=32`、`C_S_AXIS_OBS_TUSER_WIDTH=1`，数据打包与 TX 相同。反馈应是经过接收机处理后的复数 PA/DPA 观测。

### 5.5 输出

| 端口 | 说明 |
|---|---|
| `dsm_valid` | Cartesian DSM 输出有效；BP 模式表示 IF quantizer 输出有效 |
| `i_bit/q_bit` | 低通 Cartesian 路线的一位 I/Q；BP 模式为兼容性零值 |
| `i_yout/q_yout` | Cartesian 多位/诊断输出；BP 模式为零值 |
| `rf_valid` | `rf_bit/rf_signed` 有效标志 |
| `rf_bit` | BP 一位 RF/IF 输出 |
| `rf_signed` | BP 输出的 signed full-scale 编码 |
| `phase_acc_dbg` | DUC/BP 相位调试输出；BP 模式低位携带 2 bit IF phase |
| `obs_irq` | observer 完成且 IRQ enable 时拉高 |

BP 模式中 `rf_bit=1` 对应正的 `rf_signed`，`rf_bit=0` 对应负的 `rf_signed`。具体 full-scale 数值必须以 `RF_W` 和 RTL 为准。

## 6. DPD 规格

### 6.1 模式编码

| `DPD_CTRL[1:0]` | 模式 |
|---:|---|
| 0 | bypass |
| 1 | memoryless polynomial |
| 2 | LUT |
| 3 | memory-polynomial |

若请求的模式在编译期未启用，实际模式自动回退 bypass；软件应读取 `EFFECTIVE_STATUS`。

### 6.2 定点格式

- 输入 I/Q：signed Q1.15。
- DPD 系数：signed 16 bit Q2.14。
- 系数安全默认绝对值上限：24576，即约 1.5 的 Q2.14 表示。
- 主 memory-polynomial 使用 C1/C3/C5 和 4 个 memory taps。
- C7 寄存器保留给可选 polynomial 分支，主 BP SKU 不综合该分支。

### 6.3 Bank commit

软件写 inactive bank 的 tap/order/实部/虚部，然后写 `MP_COMMIT.bit0`。RTL 等待 `!dpd_busy && !axis_buf_valid && !frontend_fire` 的安全边界再交换 active bank。软件轮询 `MP_COMMIT_STATUS`，确认 ack 或 failed。

安全检查失败时不会替换 active bank。saturation fault 发生后，DPD 后续输出回退 bypass，直到软件清 fault 并重新配置安全系数。

## 7. Observer 规格

observer 对 reference 和反馈进行延迟、复增益校正，并统计：

- paired/drop count；
- 64 bit error accumulator；
- reference/output magnitude accumulator；
- peak、clip、saturation；
- slew；
- 固定 bin 频谱 proxy；
- temperature snapshot；
- overflow flags。

观测有效条件：`done=1`、`last_seen=1`、drop count=0、overflow flags=0。任一条件不满足，PS 不得把窗口用于系数拟合或 AI 训练。

## 8. AXI-Lite 寄存器定义

地址为 byte offset，寄存器宽度 32 bit。

| Offset | 名称 | 读写 | 主要字段 |
|---:|---|---|---|
| `0x00` | CTRL | RW | bit0 enable，bit1 soft reset，bit2 clear status |
| `0x04` | STATUS | R | bit0 enable，bit1 soft reset，bit2 DSM valid，bit3 RF valid，bit4 input ready，bit5 error，bit6 skid full |
| `0x08` | PHASE_INC | RW | 相位增量 |
| `0x0C` | ALGORITHM | R | 编译期标识 |
| `0x10` | DUC_MODE | R | 编译期标识 |
| `0x14` | VERSION | R | `0x00010005` |
| `0x18` | IN_COUNT | R | 输入 transfer 数 |
| `0x1C` | OUT_COUNT | R | 输出 transfer 数 |
| `0x20` | RESET_COUNT | R | 软件复位计数 |
| `0x24` | ERROR | RW1C | 错误状态 |
| `0x28` | FRONT_COUNT | R | DPD 前端输出计数 |
| `0x2C` | STALL_COUNT | R | 输入 stall 周期 |
| `0x30` | INTERP_MODE | R | 编译期插值标识 |
| `0x34` | FRAME_COUNT | R | `tlast` 计数 |
| `0x38` | LAST_TUSER | R | 最近 `tuser` |
| `0x3C` | USER_ERROR_COUNT | R | 非零 tuser 计数 |
| `0x40` | DPD_CTRL | RW | mode、safety enable、clear fault |
| `0x44/48/4C/100` | DPD_C1/C3/C5/C7 | RW | `{imag,real}` Q2.14 |
| `0x50/54` | DPD_COUNT/SAT_COUNT | R | DPD 统计 |
| `0x58/5C/60` | LUT | RW | address/data/commit |
| `0x64-0x8C` | MON | R | power、peak、avg、EVM/ACPR、spec proxy |
| `0x90/94/98` | MP | RW | select/data/commit |
| `0x9C/A0/A4` | OBS control | RW | control/gain/window |
| `0xA8-B8` | OBS status | R | done、drop、error、magnitude、peak |
| `0xBC-FC` | condition/observer | RW/R | QAM、BW、backoff、environment、spectrum |
| `0x104` | DSM_CTRL | RW | input right shift `bits[3:0]` |
| `0x108` | CAPABILITY | R | 编译能力 bitmap |
| `0x10C` | EFFECTIVE_STATUS | R | effective mode、bank、fallback、commit state |
| `0x110` | MP_COMMIT_STATUS | RW/R | ack、pending、inflight、failed、epoch |
| `0x114-0x11C` | OBS snapshot | RW/R | error snapshot |

完整字段拼接以 `rtl/axi/dsm_ip_axi_top.v` 为最终 source of truth；软件不得自行推断保留位。

## 9. 错误处理

建议软件在每个校准窗口结束后检查：

1. `ERROR`；
2. `STALL_COUNT`、`USER_ERROR_COUNT`；
3. DPD saturation/fallback；
4. commit failed；
5. observer drop/overflow；
6. `EFFECTIVE_STATUS` 和 build identity。

任何错误、drop、overflow、saturation 或 unknown condition 都应触发回退到安全搜索或丢弃当前校准结果。

## 10. 验证要求

RTL 变更至少运行 XSim P0 和 IP smoke；MATLAB 变更运行 bit-true check；封装变更运行 Vivado packaging；综合变更运行 OOC。Linux 环境可运行 DC lint。所有结果写入 `docs/UPDATE_LOG.md`，并记录工具是否实际可用。

## 11. 性能与合规边界

当前 28 nm DC 数字结果见 `PPA_VERIFICATION_RELEASE.md`，是 pre-layout estimate。EVM/SNDR/ACLR 必须注明数据来源。MATLAB behavioral DPA 不能写成 ADS 或实测 RF；没有真实反馈接收机时，不能宣称物理 PA DPD 已闭环。

## 12. 交付检查表

- [ ] 顶层、参数和 RTL filelist 与综合 manifest 一致。
- [ ] AXI Stream 打包、backpressure 和 `tlast/tuser` 已验证。
- [ ] AXI-Lite 读写、复位、错误清除已验证。
- [ ] DPD coefficient bank commit 和安全回退已验证。
- [ ] observer 窗口 zero-drop/zero-overflow 已验证。
- [ ] MATLAB/RTL bit-true 结果已归档。
- [ ] IP-XACT `component.xml` 已生成。
- [ ] FPGA OOC 报告真实存在并满足目标，或明确记录工具阻塞。
- [ ] DC 预布局 PPA 报告真实存在并标注 PVT。
- [ ] RF 指标来源和限制已经写清楚。

## 13. 需求编号与可追溯性

| 编号 | 需求 | 验证方法 |
|---|---|---|
| `DSM-FUNC-001` | `DUC_MODE=3` 使用全精度 Fs/4 IF Mixer 后的一位 BP EFDSM2，不复用旧低通一位 DUC | RTL review、VCS/XSim、bit-true |
| `DSM-FUNC-002` | BP EFDSM2 固定 `B1=0,B2=-1`，输出为 `+Y_POS/-Y_POS` | 参数检查、逐样本比较 |
| `DSM-FUNC-003` | `rf_valid` 与 BP 量化输出时序对齐 | RTL scoreboard |
| `DSM-FLOW-001` | AXI-Stream 只在 `valid && ready` 接收，backpressure 不丢失或重排 | AXI 随机 stall |
| `DSM-FLOW-002` | stall 期间 `tdata/tlast/tuser` 保持稳定 | protocol checker |
| `DPD-FUNC-001` | 主 SKU 支持 Q1.15 输入到 Q2.14 memory-polynomial 输出 | MATLAB/RTL bit-true |
| `DPD-FUNC-002` | DPD 针对同一 behavioral DPA、同一 waveform 和 held-out 数据验证 | DPA/DPD matrix |
| `DPD-SAFE-001` | 非法系数不得替换 active bank | RTL negative test |
| `DPD-SAFE-002` | saturation fault 后进入 bypass fallback | fault injection |
| `DPD-SAFE-003` | AI 不得绕过确定性安全搜索 | policy replay |
| `OBS-FUNC-001` | feedback 支持 delay、complex gain、paired/error/power/peak 统计 | observer unit |
| `OBS-SAFE-001` | drop/overflow 窗口不得用于拟合或 AI 训练 | negative test |
| `CFG-FUNC-001` | `ALGORITHM/DUC_MODE/INTERP_MODE` 作为只读 build identity | AXI register test |
| `RESET-001` | 异步复位清除 valid、计数器、状态和 observer | reset test |
| `PPA-001` | PPA 报告非零 mapped，记录工具、PVT、参数和路径 | DC/Vivado review |

## 14. 数值与定点契约

输入 I/Q 为 signed Q1.15、16 bit 二补码。BP `rf_signed` 默认 16 bit，正量化值为 `+32767`，负量化值为 `-32767`。`rf_bit=1` 对应正 `rf_signed`，`rf_bit=0` 对应负 `rf_signed`。MATLAB reference 必须显式模拟 RTL 的 signed 运算、舍入、截位、饱和和更新顺序。

BP EFDSM2 的操作顺序是：先执行 `x_shifted = x_in >>> IN_SHIFT`，再计算 `y_raw = x_shifted + B1*e1 + B2*e2`；根据 `SATURATE` 把 `y_raw` 饱和或截断为 `y_state`；用 `y_state >= 0` 得到 bit 并生成 `q`；计算 `e0 = y_state - q`；最后执行 `e2=e1,e1=e0`。主 BP 配置为 `B1=0,B2=-1`。复位时 `e1/e2=0`，输出寄存器初始化为正量化值。`SATURATE=1` 时状态饱和到 `V_MAX/V_MIN`，参考模型不得替换为 wrap。

插值器可能产生流水延迟和 backpressure。验证必须比较带 valid 的样本序列，不得假设固定 cycle 位置。BP 路径的 `if_valid` 是 Mixer 注册输出有效，`rf_valid` 与 BP 输出注册边界对齐。

## 15. 时序与延迟契约

- 顶层时钟目标为 100 MHz，周期 10 ns。
- `s_axis_tready` 可因 skid buffer、DPD pipeline 或下游状态而拉低。
- 上游不得假设固定 input-to-output latency，必须以 `valid/ready` 对齐。
- 端到端 latency 每次 RTL/综合变更后重新测量，不写死为软件协议。
- AXI-Lite 写响应等待 AW/W 地址和数据均捕获，软件不得依赖 AW/W 同周期。
- MP commit 只在 `!dpd_busy && !axis_buf_valid && !frontend_fire` 的安全边界发生。
- observer `done` 仅表示窗口处理结束，不表示系数已拟合或质量已达标。

## 16. behavioral DPA 与性能指标

behavioral DPA profile 至少声明增益、压缩点、AM/AM、AM/PM、memory taps、noise、temperature drift、BPF 和 receiver。training/validation/test profile 必须隔离，blind profile 永久不得参与模型和阈值选择。

- EVM：CP/FFT、对齐及必要的复增益/相位校正后计算。
- SNDR：目标信号功率与带内失真/噪声功率之比。
- ACLR/OOB：按报告定义的邻道/带外 power proxy，注明采样率、带宽和滤波器。
- RTL `MON_*` 是有限位宽 proxy，不等价于仪器 EVM/ACLR。
- Pout/Pdc/efficiency 必须独立注明 Python、ADS、behavioral 或实测来源。

no-DPD、memoryless 和 memory-polynomial 必须使用同一输入 waveform、同一 behavioral DPA、同一 BPF、同一 receiver 和同一 held-out 划分。不得比较不同 impairment 或不同数据集的结果。

## 17. PS 运行状态

建议 PS 使用：`RESET -> DISCOVER -> CONFIGURE -> IDLE -> RUN -> OBSERVE -> FIT -> STAGE_SHADOW -> COMMIT_WAIT -> REPLAY -> ACCEPT/FALLBACK`。

- `DISCOVER` 读取 VERSION/CAPABILITY/build identity。
- `CONFIGURE` 加载 DPD、observer 和 condition metadata。
- `RUN` 发送 TX AXI-Stream。
- `OBSERVE` 收集 zero-drop/zero-overflow feedback window。
- `FIT` 在 PS/PC/MATLAB 侧拟合 DPD，不能在高速 RTL 中训练。
- `COMMIT_WAIT` 等待安全边界并检查 commit status。
- `REPLAY` 固定 waveform 重放并读取质量/安全计数。
- `FALLBACK` 在错误、drop、saturation、overflow 或 unknown condition 时执行保守 package/局部搜索。

## 18. 故障优先级

从高到低：clock/reset/AXI protocol fault；DPD safety fault、非法 commit、saturation；observer drop/overflow/invalid feedback；unknown condition 或 AI 低置信度；预测成本偏差和质量退化；候选数和收敛速度优化。高优先级故障未清除时，不得为降低候选数而放宽安全策略。

## 19. 工具与证据要求

每份结果必须记录日期、工具版本、top、source list、参数、时钟、PVT/part、命令、返回码、报告目录和 warning。发布证据使用 `docs/evidence/` 的精简摘要；原始大型波形、工具 cache、license 和本机私有路径不作为交付文件。

## 20. 规格变更流程

任何改变位宽、signedness、舍入、饱和、更新顺序、valid latency、寄存器语义、默认系数或安全行为的修改，必须更新 SPEC、MATLAB reference、RTL/testbench 和受影响回归，并在 `UPDATE_LOG.md` 记录兼容性影响。

## 21. 术语和主链路速查

### 21.0 用户最容易混淆的五个概念

#### DPD 是否针对 DPA

是。主 SKU 的 memory-polynomial DPD 用于补偿同一 behavioral DPA 的逆特性，
包括 AM/AM、AM/PM 和记忆效应。它不是一个脱离被测功放的通用固定公式：换 DPA
模型、中心频率、带宽、backoff 或反馈链路后，系数必须重新识别和验证。
当前 `C1/C3/C5 + 4 taps` 是可综合的 DPA-DPD 载体，不代表已经用真实 PA 反馈
完成现场校准。MATLAB behavioral DPA 是当前主要 DPD 证据来源。

#### SKU 是什么

SKU 是 **Stock Keeping Unit** 的缩写，在这里表示一个固定的硬件产品配置/构建
变体。它由 top、参数、启用的 generate 分支、接口和约束共同决定。例如主 SKU
是 `dsm_ip_axi_top` 的 BP EFDSM2 配置；改变 `DUC_MODE` 或 `INTERP_MODE` 后，
应视为另一个需要独立综合和回归的 SKU，而不是运行时切换。

#### VERSION 和 CAPABILITY

- `VERSION` 是 RTL core 的版本标识。本版本由 `CORE_VERSION=32'h0001_0005`
  驱动，用于 PS 在启动时确认寄存器协议和软件兼容性；它不是 FPGA bitstream
  的 Vivado 版本，也不是 DPD 模型版本。
- `CAPABILITY` 是当前综合配置能做什么的能力 bitmap。它编码 DPD polynomial/LUT/
  memory 是否编译、最大 tap 数、最高阶数、DSM build identity、插值配置、以及
  safe commit 和异步 feedback companion 是否存在。它不是运行状态；运行状态应
  读取 `STATUS`、`EFFECTIVE_STATUS` 和 observer 状态寄存器。

#### 编译期参数和运行期寄存器

`ALGORITHM`、`DUC_MODE`、`INTERP_MODE`、`INTERP_IMPL`、
`ENABLE_DPD_POLY/LUT/MEMORY`、`DPD_MP_MAX_TAPS` 和 `DPD_POLY_ORDER` 都是
**编译期参数**。它们在 elaboration/synthesis 时决定 generate 分支和面积，软件
不能通过 AXI-Lite 把已经综合的 SKU 改成另一种结构。AXI-Lite 只能读取这些 build
identity/capability，或者设置运行期可调参数。

运行期可写内容包括：`CTRL`、`DPD_CTRL`、DPD 系数、MP inactive bank、active tap
数、LUT 内容、observer 控制/增益/窗口、condition metadata、temperature 和
`DSM_CTRL` 的输入右移。运行期 DPD mode 请求如果对应分支没有编译，
`EFFECTIVE_STATUS` 必须显示实际回退到 bypass。

#### feedback AXI-Stream 和 observer 的关系

`s_axis_obs_*` 是**进入 PL/IP 的反馈输入**，不是 `rf_bit` 直接输出给 PS 的通道。
典型物理闭环为：

```text
rf_bit -> 外部 1-bit DPA/PA + BPF -> 耦合器/接收机/ADC -> 复数 Q1.15
       -> feedback AXI-Stream -> s_axis_obs_* -> dpd_observer
```

`dpd_observer` 是 PL 内的同步统计模块，不是 PS 上运行的训练器，也不是自动更新
DPD 系数的神经网络。它把 TX reference 与 feedback 按 delay 和 complex gain 对齐，
统计 paired/error/power/peak/clip/saturation/spectrum/temperature 等结果。PS
通过 AXI-Lite 读取这些统计寄存器，再在 PS/PC/MATLAB 侧拟合系数并提交 inactive
bank。若要让 PS 保存原始 feedback，必须另设 ADC-to-DDR/AXI DMA 通路；当前
`s_axis_obs` 主要被 observer 消费。

### 21.1 `INTERP_IMPL=0` 的含义

`INTERP_MODE` 决定插值倍率，`INTERP_IMPL` 只决定某些倍率的硬件实现方式。两者不是同一个概念。

主 SKU 使用 `INTERP_MODE=4`，表示 x32 插值；`INTERP_IMPL=0` 表示采用 I0 实现：两级 x2 halfband、固定系数 8 倍 FIR/CIC-equivalent stage 和最后的 compensation FIR。它仍然执行 x32 插值，并不是关闭插值。

当 `INTERP_MODE=4` 时，当前 RTL 支持的实现分支是：

| `INTERP_IMPL` | x32 实现 | 说明 |
|---:|---|---|
| 0 | I0 | 两级 halfband + fixed FIR 的 CIC-equivalent + compensation FIR；当前主 SKU |
| 1 | I1 | 两级 halfband + direct CIC + compensation FIR |
| 2 | I2 | monolithic x32 polyphase FIR |
| 3 | I3 | 两级 halfband + polyphase 8x FIR + compensation FIR |

当 `INTERP_MODE=0/1/2/3` 时，`INTERP_IMPL` 不改变这些模式的基本倍率；它主要是 x32 模式的实现选择。选择实现时需要同时比较 bit-true 结果、资源、时序、功耗和延迟。

### 21.2 `DUC_MODE` 的含义

当前顶层演进出了 4 条模式。主项目只把 mode 3 作为 BP EFDSM2 主验证对象，其余是历史兼容或其他集成边界：

| `DUC_MODE` | 数据路径 | 输出含义 |
|---:|---|---|
| 0 | Cartesian DSM -> 固定 Fs/4 一位/有符号 DUC | 传统数字 Fs/4 real output |
| 1 | Cartesian DSM -> NCO 数字混频 | `cfg_phase_inc` 控制数字载波 |
| 2 | Cartesian DSM -> 低通 I/Q 一位输出 | `i_bit/q_bit` 给外部重构 LPF + 模拟 IQ Mixer |
| 3 | 全精度插值 I/Q -> Fs/4 IF Mixer -> BP EFDSM2 | `rf_bit/rf_signed` 给 BP/DPA 路线 |

你记得“以前只有一个 mode”是因为早期项目只验证过一条固定 DUC 路线。随着项目增加 NCO、模拟 IQ 和 BP EFDSM2，代码把它们保留成编译期 SKU。实际一个已经综合的 IP 仍然只有一个固定 mode；软件不能在运行时把 mode 0 改成 mode 3。

### 21.3 图示语句的真实含义

`dsm_core_bp_ef2` 是一个很薄的专用封装，它复用通用 `dsm_core_ef2` 的寄存器、误差反馈和量化逻辑，但把系数固定成 `B1=0,B2=-1`。这样可以避免复制一份 EF2 算术 RTL，同时保证 BP EFDSM2 的参数不会被软件随意改掉。

`ALGORITHM=3` 是 AXI/Synthesis SKU 的 build identity。`dsm_ip_top` 的 generate 判断先检查 `DUC_MODE==3`，因此 mode 3 时直接实例化 `tx_bp_if_top` 和 `BP_ALGORITHM=1`；不会继续进入 `dsm_ip_core` 的 Cartesian `ALGORITHM=3` 分支。这是“顶层 SKU 编号”和“BP 专用内部核选择”两个不同层次，二者并不矛盾。

### 21.4 主链路是不是第三种 DPD

从 DPD mode 编码看，是的，主 SKU 的高速 DPD 选择是 `DPD_CTRL[1:0]=3`，即 memory-polynomial DPD。它必须满足：

1. 编译时 `ENABLE_DPD_MEMORY=1`；
2. 软件加载合法的 4-tap/5th-order C1/C3/C5 系数；
3. 软件完成 inactive bank commit；
4. `EFFECTIVE_STATUS` 显示实际 mode=3，且没有 fallback/safety fault。

但注意：RTL 复位后 `dpd_ctrl_reg=0`，所以默认运行状态是 bypass。主 SKU 是“编译进第三种 DPD 能力”，不是“上电后自动使用第三种 DPD”。列表中的第 4 项 AI/LUT seed 是校准策略，不是第四种高速 DPD 数学模型；它负责给 memory-polynomial 搜索提供起点。

### 21.5 Q1.15 和 Q2.14

`Qm.n` 表示定点数总共使用 `m+n` 个 bit，其中 `n` 个 bit 表示小数位，剩余 bit 包含符号位和整数位。

| 格式 | 总位数 | 小数位 | 典型范围 | 例子 |
|---|---:|---:|---|---|
| Q1.15 | 16 | 15 | `-1` 到 `0.999969` | `0x4000=0.5`，`0x7fff≈1.0` |
| Q2.14 | 16 | 14 | `-2` 到 `1.999939` | `0x4000=1.0`，`0x6000=1.5` |

计算方法是：有符号整数 code 除以 `2^小数位`。因此输入 `Q1.15` 的 `0x4000` 是 `16384/32768=0.5`；DPD 系数 Q2.14 的 `16384` 是 `16384/16384=1.0`。Q2.14 比 Q1.15 多一个整数位，适合表达可能大于 1 的 DPD 增益/系数。当前 safety limit `24576` 表示 Q2.14 的 `1.5`。

### 21.6 feedback AXI-Stream 的方向

`s_axis_obs_*` 是**进入 PL/IP 的输入**，不是 IP 输出给 PS 的端口。推荐方向是：

```text
PA/DPA 输出 -> BPF/耦合器 -> 下变频/ADC/receiver
            -> 复数 Q1.15 feedback AXI-Stream
            -> dsm_ip_axi_top.s_axis_obs
```

PS 如果需要原始 feedback 数据，必须另设 ADC-to-DDR/AXI DMA 通道；当前 `s_axis_obs` 进入 IP 后主要被 observer 消费，PS 通过 AXI-Lite 读取统计结果和状态，而不是从 `s_axis_obs` 直接读数据。

当前板级模板可能把该端口零连接，以便先验证 TX/控制/统计接口。这不是真实 PA 反馈，不能用于物理 DPD 闭环结论。

### 21.7 顶层输出信号逐个解释

| 信号 | 主 BP SKU 中的含义 | 其他路线 |
|---|---|---|
| `dsm_valid` | Mixer 已产生一个有效的 real-IF sample，表示 BP quantizer 输入边界有效；它通常早于 `rf_valid` 一个注册边界 | Cartesian DSM 输出有效 |
| `i_bit` | BP mode 固定为 0，不是有效的 I lane | 低通 Cartesian 一位 I 输出 |
| `q_bit` | BP mode 固定为 0，不是有效的 Q lane | 低通 Cartesian 一位 Q 输出 |
| `i_yout` | BP mode 固定为 0 | Cartesian signed DSM code |
| `q_yout` | BP mode 固定为 0 | Cartesian signed DSM code |
| `rf_valid` | `rf_bit/rf_signed` 当前拍有效 | DUC0/1 的 real output valid；DUC2 固定为 0 |
| `rf_bit` | BP 一位 real IF/DPA 驱动 bit | DUC0/1 的 real digital output bit |
| `rf_signed` | `rf_bit` 的 signed full-scale 表示，通常为 `+32767/-32767`；便于仿真、统计和后续模块使用 | DUC0/1 的 signed real output |
| `phase_acc_dbg` | BP mode 低 2 bit 携带 Mixer phase；其余位零扩展，不是 NCO accumulator | DUC1 是 NCO phase accumulator，其他模式是相位/调试编码 |
| `obs_irq` | observer 完成且 `obs_irq_enable_reg=1` 时通知 PS 的中断线 | observer 未启用时保持低 |

`dsm_valid` 和 `rf_valid` 不应混为一个信号：前者描述 BP IF quantizer 输入/DSM 边界，后者描述最终一位 real output。软件和 testbench 采集 `rf_bit` 时必须使用 `rf_valid`。

### 21.8 observer 是什么

observer 不是 PA，也不是 DPD 系数训练器。它是 PL 内的**反馈观测与误差统计模块**：

```text
原始 TX reference（进入 DPD 前）
        + 延迟/环形缓存
反馈 feedback（DPA/PA 接收机后）
        + 复增益校正
        -> error/power/peak/clip/slew/spectrum statistics
```

在当前 RTL 中，`ref_i/ref_q` 来自 AXI skid buffer 中的原始输入 IQ；`obs_i/obs_q` 来自 `s_axis_obs_tdata`。observer 根据 `delay_samples` 从 reference ring buffer 取对齐样本，用 `gain_re/gain_im` 校正 feedback，然后统计误差和 monitor state。它不自动求解 memory-polynomial 系数，系数拟合在 MATLAB/PS/PC 侧完成。

### 21.9 为什么 AXI-Lite 寄存器比较多

寄存器不是“每个都参与主 BP 数学运算”，而是把控制、DPD 校准、反馈观测、AI 条件和调试状态放在同一个可复用 IP 边界：

| 分组 | 主要用途 | 主 BP 是否必需 |
|---|---|---|
| `0x00-0x3c` core/status/counters | enable、复位、握手和错误 | 必需 |
| `0x40-0x54` DPD polynomial/control | 兼容和对照模型 | 主 memory DPD 不需要 polynomial 系数 |
| `0x58-0x60` LUT | LUT 对照/历史 SKU | 当前主 SKU 不综合 LUT datapath |
| `0x64-0x8c` monitor proxy | 性能监控、AI 输入、调试 | 推荐保留 |
| `0x90-0x98` memory-polynomial bank | 主 DPD 系数选择、写入、commit | 必需 |
| `0x9c-0xbc` observer | feedback 校准和统计 | behavioral/真实闭环时必需；无 feedback 时可选 |
| `0xbc-0x10c` condition/seed/capability | AI 条件、fallback、build identity | AI 校准时需要；纯固定 DPD 可裁剪 |
| `0x110-0x11c` commit/snapshot | 原子提交和错误快照 | 推荐保留 |

### 21.10 哪些可以删

当前不建议直接从已交付顶层删除端口或地址，因为 PS 驱动、Vivado packaging、testbench 和既有软件接口可能依赖它们。可以考虑建立一个新的 `BP_EF2_LITE` 编译 SKU：

- 保留 core enable/reset/status/counters；
- 保留 memory-polynomial MP select/data/commit、安全和 effective status；
- 保留 `rf_valid/rf_bit/rf_signed`；
- 删除或隐藏 polynomial C1/C3/C5/C7、LUT 写入、未使用的 Cartesian 输出和 AI predictor metadata；
- 如果没有反馈接收机，再把 observer/feedback AXI 作为独立可选 wrapper，而不是从主顶层偷偷删除。

这个裁剪必须先做接口使用审计，再跑 SpyGlass 的 undriven/unloaded/constant/shorted output 检查和 VCS/XSim 回归。当前 DC lint 中的 226 unconnected ports、73 shorted outputs、80 unloaded nets 说明有清理空间，但不能把所有 warning 直接等同于“无用信号”。

## 22. 当前实现状态与规格边界

### 22.1 已实现的规格

- 主 SKU 的 AXI4-Lite、TX AXI4-Stream 和一位 BP EFDSM2 数据通路；
- Memory-Poly5 4-tap DPD、双 bank、原子 commit 和安全回退；
- x32 插值、Fs/4 全精度 IF、`rf_bit/rf_signed` 输出；
- observer、monitor、spectral proxy 和异步反馈 bridge 接口；
- PS bare-metal DMA/寄存器/候选搜索框架；
- MATLAB 定点模型、behavioral DPA 和分层指标流程。

### 22.2 尚未签核的规格

- 当前 BP SKU 的 ZU15EG full-TX routed/bitstream；
- 完整 UVM protocol、safety、observer 和 monitor 覆盖；
- 真实 DPA/PA、接收机和 ADC feedback；
- ADS/PDK 电路 PVT、layout 和实测 RF；
- post-layout ASIC 时序、功耗、IR drop、EM 和硅后指标。

### 22.3 历史证据限制

仓库中的 ZU15EG full-TX bitstream 摘要属于旧 `DUC_MODE=0` Cartesian EFDSM/Fs4 路线。它不得作为本规格主 `DUC_MODE=3` BP EFDSM2 SKU 的实现签核证据。当前 BP SKU 的 28 nm DC 结果仅为 pre-layout 估计。
