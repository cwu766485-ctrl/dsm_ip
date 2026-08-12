# Formal 层

`dsm_axi_protocol_sva.sv` 是可选的断言模块，当前包含：

- TX AXI 在 `valid=1、ready=0` 时保持 payload、`tuser` 和 `tlast`；
- `rf_valid` 时 `rf_signed` 和 `rf_bit` 保持 BP 极性一致。

该模块目前还没有 bind 到 DUT，也没有运行 formal 工具。后续需要使用和
DC/Vivado 相同的 BP 参数绑定到 `dsm_ip_axi_top`。
