# Tests 层

`dsm_base_test.svh` 负责创建配置和 environment。`dsm_bp_test.svh` 只设置
测试策略、启动 `env/dsm_virtual_sequences.svh` 中的场景并管理 objection。
测试不会直接驱动 DUT pin 或底层 transaction。

当前 `dsm_bp_test` 会读回冻结 SKU、使能 DUT、发送短 IQ 波形，等待 BP
pipeline，并检查 RF bit 流和 signed 编码。

`dsm_axi_protocol_test` 会随机打散 AXI-Lite `AW/W`、延迟 AXI-Lite response
ready，并为 TX/OBS AXI-Stream 生成随机 valid gap。测试配置并启动 observer，
发送 64 个 TX/OBS transaction，等待链路 drain，并要求 x32 插值后恰好收到
2048 个 RF transaction。它用于协议与流控回归，不替代 MATLAB golden
逐样本 scoreboard。

`dsm_performance_bittrue_test` 是 Performance SKU 的确定性全链事务测试。它以
Python integer reference 生成的 CSV 为单一输入/输出契约，检查：

- 24 个 TX I/Q/`tlast` transaction 被 monitor 原样看到；
- x32 interpolation 后恰有 768 个 RF transaction；
- 每个 RF `rf_bit`、`rf_signed` 和 Fs/4 phase 与 Python expected 一致；
- expected queue 完整 drain。

该 testcase 使用 DPD runtime bypass；它不替代 memory DPD coefficient bank、commit
和 fallback 的专用 testcase。

`dsm_memory_dpd_bittrue_test` 使用同一份 Python 生成的 coefficient CSV 与 expected
RF CSV。testcase 写 inactive bank、确认 commit ack 和 effective memory mode，然后逐
transaction 比对完整 Memory-Poly5/4-tap TX 链路。

`dsm_memory_dpd_safety_test` 向 inactive bank 写入一个超限系数，要求 commit failed、
active bank 保持不变且 `ERROR.bit3` 置位。

后续测试文件放在本目录，例如：

- 更长 AXI backpressure、`tlast/tuser` 错误注入和 active-stream reset；
- observer pairing、drop、overflow、interrupt 测试；
- BP EFDSM2 bit-true reference scoreboard 测试。

`dsm_memory_dpd_bittrue_test` 和 `dsm_memory_dpd_safety_test` 已于 2026-08-12 在
当前 RTL 上用 VCS 执行通过；后续重点是多 seed、coverage closure 与更长的异常矩阵，
不是重复基础的 coefficient commit/safety directed testcase。
