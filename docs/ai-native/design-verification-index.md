<!-- organize-chip-project:generated-file -->
# Design and verification index

This index separates design, verification, flow, and protected boundaries so an agent can choose the correct evidence.

## Design

- `fpga/hardware/xczu15eg/xczu9eg-2ffvb1156.v`
- `fpga/zu15eg/rtl/ti64_raw_gt14_dual_sfp_link.sv`
- `fpga/zu15eg/rtl/ti64_raw_gt14_dual_sfp_loopback_top.sv`
- `fpga/zu15eg/rtl/ti64_raw_gt14_sfp0_bert_top.sv`
- `fpga/zu15eg/rtl/ti64_raw_gt14_sfp0_link.sv`
- `fpga/zu15eg/rtl/ti64_raw_gt14_sfp0_loopback_top.sv`
- `fpga/zu15eg/rtl/ti64_raw_gt14_sfp0_x4_top.sv`
- `fpga/zu15eg/rtl/tid32_cartesian_gt14_dual_sfp_payload_top.sv`
- `fpga/zu15eg/rtl/tid32_thermo3_gt14_dual_sfp_payload_top.sv`
- `rtl/axi/dsm_ip_axi_read_mux.v`
- `rtl/axi/dsm_ip_axi_top.v`
- `rtl/axis/axis_skid_buffer.sv`
- `rtl/axis/dsm_async_fifo.sv`
- `rtl/axis/dsm_axis14_to_core8_cdc.sv`
- `rtl/axis/dsm_reset_sync.sv`
- `rtl/axis/dsm_xpm_async_fifo.sv`
- `rtl/dpd/dpd_frontend.v`
- `rtl/dpd/dpd_lut.v`
- `rtl/dpd/dpd_memory_poly.v`
- `rtl/dpd/dpd_observer.v`
- `rtl/dpd/dpd_observer_async_bridge.v`
- `rtl/dpd/dpd_poly.v`
- `rtl/dpd/dpd_seed_predictor.v`
- `rtl/dpd/dpd_tinyml_tree.v`
- `rtl/dpd/dpd_vector16_frontend.sv`
- `rtl/dpd/dpd_vector16_memory_poly.sv`
- `rtl/dpd/dpd_vector_elastic_buffer.sv`
- `rtl/dsm/multibit/dsm_core_multibit.sv`
- `rtl/dsm/multibit/dsm_core_multibit_ef1.sv`
- `rtl/dsm/multibit/dsm_core_multibit_ef2.sv`
- `rtl/dsm/multibit/dsm_core_multibit_lp1.sv`
- `rtl/dsm/multibit/dsm_core_multibit_lp2.sv`
- `rtl/dsm/multibit/dsm_core_multibit_mash11.sv`
- `rtl/dsm/multibit/dsm_core_multibit_mash111.sv`
- `rtl/dsm/multibit/dsm_core_multibit_mash22.sv`
- `rtl/dsm/singlebit/dsm_core.sv`
- `rtl/dsm/singlebit/dsm_core_dsm2.sv`
- `rtl/dsm/singlebit/dsm_core_ef1.sv`
- `rtl/dsm/singlebit/dsm_core_ef2.sv`
- `rtl/dsm/singlebit/dsm_core_mash11.sv`

## Verification

- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/doc/程序使用说明.docx`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/design_1_wrapper.xsa`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.xpr`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/0/b/0ba3e663c17e5170/0ba3e663c17e5170.xci`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/0/b/0ba3e663c17e5170/design_1_rst_ps8_0_99M_0.dcp`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/0/b/0ba3e663c17e5170/design_1_rst_ps8_0_99M_0_sim_netlist.v`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/0/b/0ba3e663c17e5170/design_1_rst_ps8_0_99M_0_sim_netlist.vhdl`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/0/b/0ba3e663c17e5170/design_1_rst_ps8_0_99M_0_stub.v`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/0/b/0ba3e663c17e5170/design_1_rst_ps8_0_99M_0_stub.vhdl`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/1/a/1af780878607ef4e/1af780878607ef4e.xci`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/1/a/1af780878607ef4e/design_1_ddr4_0_0_stub.v`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/1/a/1af780878607ef4e/design_1_ddr4_0_0_stub.vhdl`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/2/7/27712de96a99b355/27712de96a99b355.xci`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/2/7/27712de96a99b355/design_1_axi_smc_0_stub.v`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/2/7/27712de96a99b355/design_1_axi_smc_0_stub.vhdl`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/4/9/49d902d71e44ca6c/49d902d71e44ca6c.xci`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/7/d/7d5b22a7f819819c/7d5b22a7f819819c.xci`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/7/d/7d5b22a7f819819c/design_1_ila_0_2.dcp`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/7/d/7d5b22a7f819819c/design_1_ila_0_2_sim_netlist.v`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/7/d/7d5b22a7f819819c/design_1_ila_0_2_stub.v`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/7/d/7d5b22a7f819819c/design_1_ila_0_2_stub.vhdl`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/9/6/96dc4ce98e7f8ca2/96dc4ce98e7f8ca2.xci`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/9/6/96dc4ce98e7f8ca2/design_1_zynq_ultra_ps_e_0_0.dcp`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/9/6/96dc4ce98e7f8ca2/design_1_zynq_ultra_ps_e_0_0_sim_netlist.v`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/9/6/96dc4ce98e7f8ca2/design_1_zynq_ultra_ps_e_0_0_sim_netlist.vhdl`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/9/6/96dc4ce98e7f8ca2/design_1_zynq_ultra_ps_e_0_0_stub.v`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/9/6/96dc4ce98e7f8ca2/design_1_zynq_ultra_ps_e_0_0_stub.vhdl`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/9/8/9883a444b8b11083/9883a444b8b11083.xci`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/9/8/9883a444b8b11083/dbg_hub.dcp`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/9/8/9883a444b8b11083/dbg_hub_sim_netlist.v`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/9/8/9883a444b8b11083/dbg_hub_sim_netlist.vhdl`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/9/8/9883a444b8b11083/dbg_hub_stub.v`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/9/8/9883a444b8b11083/dbg_hub_stub.vhdl`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/e/a/eabbb6c08829bb2a/design_1_rst_ddr4_0_333M_1.dcp`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/e/a/eabbb6c08829bb2a/design_1_rst_ddr4_0_333M_1_sim_netlist.v`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/e/a/eabbb6c08829bb2a/design_1_rst_ddr4_0_333M_1_sim_netlist.vhdl`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/e/a/eabbb6c08829bb2a/design_1_rst_ddr4_0_333M_1_stub.v`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/e/a/eabbb6c08829bb2a/design_1_rst_ddr4_0_333M_1_stub.vhdl`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/ip/2022.1/e/a/eabbb6c08829bb2a/eabbb6c08829bb2a.xci`
- `fpga/hardware/xczu15eg/15eg_demo/1.mem_test/prj/mem_test/mem_test.cache/wt/project.wpc`

## Constraints and flow

- `fpga/hardware/rfsoc4x2/4x2_PL_FULL_CONSTRAINTS.zip`
- `fpga/hardware/rfsoc4x2/4x2_PL_FULL_CONSTRAINTS/4x2_1PPS.xdc`
- `fpga/hardware/rfsoc4x2/4x2_PL_FULL_CONSTRAINTS/4x2_LED_PB__SW.xdc`
- `fpga/hardware/rfsoc4x2/4x2_PL_FULL_CONSTRAINTS/4x2_PL_DDR4.xdc`
- `fpga/hardware/rfsoc4x2/4x2_PL_FULL_CONSTRAINTS/4x2_PMOD.xdc`
- `fpga/hardware/rfsoc4x2/4x2_PL_FULL_CONSTRAINTS/4x2_QSFP.xdc`
- `fpga/hardware/rfsoc4x2/4x2_PL_FULL_CONSTRAINTS/4x2_SYZYGY.xdc`
- `fpga/zu15eg/constraints/ti64_raw_gt14_dual_sfp_loopback.xdc`
- `fpga/zu15eg/constraints/ti64_raw_gt14_sfp0_loopback.xdc`
- `fpga/zu15eg/constraints/tid32_thermo3_gt14_dual_sfp.xdc`
- `syn/asic/thermo_frontend_dc.sdc`
- `syn/constraints/.gitkeep`
- `syn/constraints/p0_ooc_100mhz.xdc`
- `syn/reports/asic_bp_ef2_stdcell_28nm_100mhz_20260923_205358/reports/constraints.rpt`
- `syn/reports/asic_thermo3_tsmc28_20260923_213351/reports/constraints.rpt`
- `syn/reports/asic_thermo5_tsmc28_20260923_213427/reports/constraints.rpt`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_smoke.tcl`
- `fpga/zu15eg/baremetal/scripts/run_baremetal_smoke.tcl`
- `fpga/zu15eg/scripts/build_ti64_raw_gt14_dual_sfp_loopback.tcl`
- `fpga/zu15eg/scripts/build_ti64_raw_gt14_sfp0_bert.tcl`
- `fpga/zu15eg/scripts/build_ti64_raw_gt14_sfp0_loopback.tcl`
- `fpga/zu15eg/scripts/build_ti64_raw_gt14_sfp0_x4.tcl`
- `fpga/zu15eg/scripts/build_tid32_cartesian_gt14_dual_sfp_payload.tcl`
- `fpga/zu15eg/scripts/build_tid32_cartesian_gt14_dual_sfp_sta.tcl`
- `fpga/zu15eg/scripts/build_tid32_thermo3_gt14_dual_sfp_sta.tcl`
- `fpga/zu15eg/scripts/capture_calibration_trace.tcl`
- `fpga/zu15eg/scripts/capture_dsm_replay_counters.tcl`
- `fpga/zu15eg/scripts/capture_ila_golden.tcl`
- `fpga/zu15eg/scripts/create_dsm_dma_ila_bd.tcl`
- `fpga/zu15eg/scripts/export_hw_platform.tcl`
- `fpga/zu15eg/scripts/generate_ti64_raw_gt14_dual_ip.tcl`
- `fpga/zu15eg/scripts/generate_ti64_raw_gt14_ip.tcl`
- `fpga/zu15eg/scripts/implement_full_tx.tcl`
- `fpga/zu15eg/scripts/program_bitstream_vivado.tcl`
- `fpga/zu15eg/scripts/query_gtwizard_config.tcl`
- `fpga/zu15eg/scripts/read_dsm_counters.tcl`
- `fpga/zu15eg/scripts/rebuild_dsm_board_bitstream.tcl`
- `fpga/zu15eg/scripts/report_bd_addresses.tcl`
- `fpga/zu15eg/scripts/report_ps_uart_config.tcl`
- `fpga/zu15eg/scripts/run_ti64_raw_gt14_bert_sim.tcl`

## Heuristic HDL tops

- `decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_cdc_sync`, `decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_cdc_sync_0`, `decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix`, `decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_lpf`, `decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_proc_sys_reset`, `decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_sequence_psr`, `decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_upcnt_n`, `glbl`, `interface`, `with`, `decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_zynq_ultra_ps_e_v3_4_0_zynq_ultra_ps_e`, `design_1_wrapper`, `design_1_axi_smc_0`, `bd_afc3_wrapper`, `bd_afc3_one_0`, `bd_afc3_sawn_0`, `bd_afc3_swn_0`, `bd_afc3_sbn_0`, `bd_afc3_m00s2a_0`, `bd_afc3_m00e_0`, `bd_afc3_s00mmu_0`, `bd_afc3_s00tr_0`, `bd_afc3_s00sic_0`, `bd_afc3_s00a2s_0`, `bd_afc3_sarn_0`, `bd_afc3_srn_0`, `bd_afc3`, `clk_map_imp_5Y9LOC`, `m00_exit_pipeline_imp_1TZX5BB`, `s00_entry_pipeline_imp_USCCV8` — verify against source ordering/filelists before compiling.

## Missing evidence to resolve

- Exact top/configuration, clock/reset assumptions, test selection, coverage/signoff criteria, and generated-source provenance are not inferred unless documented above.
