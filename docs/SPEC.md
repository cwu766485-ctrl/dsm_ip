# DSM/DPD 数字发射机 IP 详细规格

文档版本：1.0

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
| `aclk` | I | 1 | 主时钟 |
| `aresetn` | I | 1 | 低有效异步复位 |

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
