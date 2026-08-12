# Agent 层

`interfaces/` 保存直接连接 DUT 的事务级接口：

- `dsm_axi_lite_if.sv`：AXI4-Lite 控制接口；
- `dsm_axis_if.sv`：TX/feedback AXI4-Stream 接口；
- `dsm_rf_if.sv`：BP 输出和调试观测接口。

三类 agent 按协议独立组织：

- `axi_lite/`：item、sequencer、driver、monitor、agent 和寄存器协议 sequence；
- `axis/`：item、sequencer、driver、monitor、agent 和数据流协议 sequence；
- `rf/`：RF item、monitor 和 passive agent；
- `interfaces/`：三类 SystemVerilog virtual interface。

AXI-Lite 与 AXI-Stream agent 支持 `UVM_ACTIVE/UVM_PASSIVE`；当前 AXI-Lite、TX
和 OBS 为 active，RF 为 passive。TX 与 OBS 复用同一种 AXI-Stream agent
类型，但拥有独立实例和 virtual interface。RAL predictor 和完整协议 coverage
仍是后续工作。
