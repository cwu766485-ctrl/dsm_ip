# IP 交接说明

更新时间：2026-08-09

## 1. 交付顶层

文件：`rtl/axi/dsm_ip_axi_top.v`
模块：`dsm_ip_axi_top`
推荐时钟：`aclk = 100 MHz`
复位：`aresetn` 低有效

顶层包含 AXI4-Lite 控制面、TX AXI4-Stream、可选 observer AXI4-Stream、DPD、插值、DSM/IF 输出和 monitor。

## 2. 主 SKU

```text
ALGORITHM=3
DUC_MODE=3
INTERP_MODE=4
INTERP_IMPL=0
ENABLE_DPD_MEMORY=1
ENABLE_DPD_POLY=0
ENABLE_DPD_LUT=0
DPD_POLY_ORDER=5
DPD_MP_MAX_TAPS=4
```

这是 compile-time 产品配置。软件只能配置已综合进硬件的 mode 和系数。

## 3. TX AXI4-Stream

```text
tdata[15:0]  = signed I, Q1.15
tdata[31:16] = signed Q, Q1.15
```

传输发生在 `tvalid && tready`。stall 时 `tdata/tlast/tuser` 必须稳定。`tlast` 标记帧尾，`tuser[0]` 表示上游错误。

推荐 ZU15EG 连接：

```text
PS DDR -> AXI DMA MM2S -> dsm_ip_axi_top.s_axis
PS master -> AXI interconnect -> dsm_ip_axi_top.s_axi
```

AXI-Lite 不用于逐样本传输。

## 4. 输出

主 BP SKU 使用：

- `rf_valid`：RF 输出有效；
- `rf_bit`：一位编码；
- `rf_signed`：与 bit 对应的有符号电平。

`i_bit/q_bit/i_yout/q_yout` 是低通 Cartesian 兼容输出，在 BP SKU 中不作为有效数据面。

## 5. 反馈 AXI4-Stream

```text
obs_tdata[15:0]  = observed I, signed Q1.15
obs_tdata[31:16] = observed Q, signed Q1.15
```

反馈应来自 DPA/PA 输出经 BPF、耦合器、下变频和 ADC 后的复数观测面，而不是未经恢复的一位 bitstream。异步 ADC 必须先经过 `dpd_observer_async_bridge` 或 AXI Stream Clock Converter。

当前板级模板没有物理 PA/ADC feedback，因此 observer 只具备数字 replay 接口能力。

## 6. DPD 系数流程

1. 读取 `VERSION`、`CAPABILITY` 和 build identity；
2. 向 inactive shadow bank 写 C1/C3/C5 与各 tap；
3. 检查系数范围和 shadow package 状态；
4. 请求 `MP_COMMIT`；
5. 等待 safe-boundary ack，确认 active bank 已切换；
6. 若 commit failed 或 saturation fault，保持/回退 bypass 或上一组安全 bank。

禁止在 active stream 中直接逐寄存器修改 active 系数。

## 7. 软件启动顺序

1. 复位并确认错误计数为零；
2. 检查硬件版本和编译配置；
3. 配置 DPD、observer、monitor window 和安全策略；
4. 写入并提交系数；
5. 使能 core；
6. 启动 DMA；
7. 等待 frame/window 完成；
8. 读取 sample/frame/stall/error、observer 和 monitor；
9. 只有在窗口有效且无 overflow/drop/saturation 时才评估候选；
10. 退化或错误时回退安全配置。

## 8. 责任边界

- PL/ASIC：定点数据通路、握手、状态、统计、bank 和安全回退；
- PS/PC：PA 识别、系数拟合、候选搜索、量化和策略；
- RF：DPA/PA、滤波、匹配、耦合器、接收机和 ADC；
- UVM：验证 RTL/DUT，不验证 PS 算法和 RF 模型；
- MATLAB/Python：验证算法和 behavioral RF，不替代板级实测。

## 9. 交付限制

当前可以交付数字 IP 源码和接口，但主 BP SKU 仍需新的 ZU15EG routed/bitstream、完整 UVM signoff 和真实反馈验证。使用方不得将历史 `DUC_MODE=0` bitstream 证据当成当前 BP SKU 证据。
