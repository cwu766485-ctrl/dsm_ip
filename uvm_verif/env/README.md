# Environment 层

`dsm_uvm_pkg.sv` 只负责 package 装配。核心文件为：

- `dsm_uvm_reg_map.svh`：冻结 byte-address register map；
- `dsm_uvm_config.svh`：主 SKU 与 latency contract；
- `dsm_virtual_sequencer.svh`：跨控制面、TX 和 OBS 的编排句柄；
- `dsm_virtual_sequences.svh`：跨 agent 的系统场景；
- `dsm_uvm_scoreboard.svh`：当前 RF smoke 检查；
- `dsm_uvm_env.svh`：agent、monitor、scoreboard 和 virtual sequencer 连接。

顶层连接关系：

```text
axi_lite_agent -> 控制寄存器
tx_axis_agent  -> s_axis_* TX 样本
obs_axis_agent -> s_axis_obs_* 反馈样本
rf_agent       -> rf_valid/rf_bit/rf_signed（passive）
virtual seqr   -> 控制三类主动 sequencer
scoreboard     -> RF 结果检查和基础 coverage
```

主 SKU DPD 固定流水为 10 cycle。x32 插值是弹性变速率结构，因此完整
scoreboard 必须按 transaction 对齐，不允许用固定端到端 cycle offset。

协议级 sequence 与 transaction 放在对应 `agent/<protocol>/` 中；environment
只保留跨协议编排。testcase 不直接操作 pin，也不直接构造底层 transaction。
