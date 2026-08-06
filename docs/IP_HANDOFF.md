# IP 交接说明

## 1. 交付对象

顶层模块：`rtl/axi/dsm_ip_axi_top.v`，模块名 `dsm_ip_axi_top`。

它包含 AXI-Lite 控制/状态接口、TX AXI4-Stream、可选反馈 AXI4-Stream、DPD 前端、插值、DSM/IF 输出和监控统计。推荐 `aclk=100 MHz`，`aresetn` 为低有效异步复位。

## 2. TX 数据通道

每个 32 bit AXI-Stream word 是一个复数 Q1.15 样本：

```text
tdata[15:0]  = signed I
tdata[31:16] = signed Q
```

传输条件是 `tvalid && tready` 在 `aclk` 上升沿同时为 1。`tlast` 是帧尾标志，`tuser[0]` 非零表示上游错误。发送端在 `tvalid=1,tready=0` 时必须保持 `tdata/tlast/tuser` 不变。

推荐 ZU15EG 路径：

```text
PS DDR TxBuffer -> AXI DMA MM2S -> M_AXIS_MM2S -> dsm_ip_axi_top.s_axis
```

AXI-Lite 仅用于低速配置和读状态，不应发送每个 IQ 样本。

## 3. 反馈通道

```text
obs_tdata[15:0]  = observed I，signed Q1.15
obs_tdata[31:16] = observed Q，signed Q1.15
```

反馈应位于 DPA/PA 输出经过输出滤波、耦合衰减、下变频和 ADC/接收机之后的复数观测面。它不是 DPD 输入，也不是未经滤波的一位 DSM bitstream。

反馈需要与 `aclk` 同时钟；异步 ADC 必须经过 AXI-Stream clock converter/FIFO。观测窗口出现 drop 或 overflow 时，软件必须丢弃该窗口。

## 4. 两种 SKU

模拟 IQ SKU：`DUC_MODE=2`。输出 `i_bit/q_bit`，`rf_valid=0`，后接外部重构 LPF 和模拟 IQ Mixer。

BP EFDSM2 SKU：`ALGORITHM=3, DUC_MODE=3, INTERP_MODE=4`。路径为 `DPD -> x32 插值 -> 全精度 Fs/4 IF -> 一位 BP EFDSM2`，使用 `rf_valid/rf_bit/rf_signed`。此模式下 `i_bit/q_bit/i_yout/q_yout` 只是兼容性输出。

## 5. 软件启动顺序

1. 释放 `aresetn`，确认 `VERSION` 和 `CAPABILITY`。
2. 读取 `ALGORITHM/DUC_MODE/INTERP_MODE`，确认与软件 build manifest 一致。
3. 配置 DPD 系数、tap 数和安全控制。
4. 对 memory-polynomial 写 inactive bank，等待安全边界后写 `MP_COMMIT`。
5. 配置 observer delay、复增益、窗口和 condition metadata。
6. 写 `CTRL.bit0=1` 使能 core。
7. 启动 DMA，发送 AXI-Stream TX 帧。
8. 读取计数器、错误状态和 observer 结果。

## 6. 安全规则

`DPD_CTRL.bit8` 开启系数安全检查，`bit9` 写 1 清 saturation fallback。超过 Q2.14 工程幅度限制的系数会使 shadow package 无效，commit 被拒绝。DPD saturation fault 会使后续样本回退 bypass，软件必须清 fault 并重新加载安全 package。

## 7. 责任边界

PL 负责确定性的定点 datapath、流控、统计、bank 和安全；PS/PC 负责 PA 识别、系数拟合、候选搜索和量化；RF 负责重构、Mixer、DPA/PA、耦合器和接收机。AXI 通道验证不等于真实 RF 闭环验证。
