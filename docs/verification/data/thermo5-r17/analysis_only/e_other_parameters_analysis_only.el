// ANALYSIS_ONLY: not an official approved exclusion.
CHECKSUM: "2004831198 3139732564"
// ANNOTATION: "ModuleName: thermo5_dpd_axi_lite_cfg"
INSTANCE: thermo5_sku_uvm_tb.dut.u_cfg
Branch 8 "2041485635" "((MAX_TAPS < 1) || (MAX_TAPS > 4))" (0) "((MAX_TAPS < 1) || (MAX_TAPS > 4)) 1"

CHECKSUM: "2408948792 3072091210"
// ANNOTATION: "ModuleName: gt_tx_user_bridge"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[0].g_order2.u_tid.u_raw_boundary.u_bridge
Branch 0 "3365410206" "(PARALLEL_W != GT_USER_W)" (0) "(PARALLEL_W != GT_USER_W) 1"

CHECKSUM: "2408948792 3072091210"
// ANNOTATION: "ModuleName: gt_tx_user_bridge"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[1].g_order2.u_tid.u_raw_boundary.u_bridge
Branch 0 "3365410206" "(PARALLEL_W != GT_USER_W)" (0) "(PARALLEL_W != GT_USER_W) 1"

CHECKSUM: "2408948792 3072091210"
// ANNOTATION: "ModuleName: gt_tx_user_bridge"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[2].g_order2.u_tid.u_raw_boundary.u_bridge
Branch 0 "3365410206" "(PARALLEL_W != GT_USER_W)" (0) "(PARALLEL_W != GT_USER_W) 1"

CHECKSUM: "2408948792 3072091210"
// ANNOTATION: "ModuleName: gt_tx_user_bridge"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[3].g_order2.u_tid.u_raw_boundary.u_bridge
Branch 0 "3365410206" "(PARALLEL_W != GT_USER_W)" (0) "(PARALLEL_W != GT_USER_W) 1"

CHECKSUM: "2611591664 791396721"
// ANNOTATION: "ModuleName: dsm_interp_x2_centered_cubic_vector"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1
Branch 2 "3213471300" "(LANES < 2)" (0) "(LANES < 2) 1"
Branch 3 "2475905803" "(COEFF_FRAC != 14)" (0) "(COEFF_FRAC != 14) 1"

CHECKSUM: "2611591664 791396721"
// ANNOTATION: "ModuleName: dsm_interp_x2_centered_cubic_vector"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2
Branch 2 "3213471300" "(LANES < 2)" (0) "(LANES < 2) 1"
Branch 3 "2475905803" "(COEFF_FRAC != 14)" (0) "(COEFF_FRAC != 14) 1"

CHECKSUM: "3956776050 240787270"
// ANNOTATION: "ModuleName: tid32_thermo5_axi_lite_axis_frontend_tx"
INSTANCE: thermo5_sku_uvm_tb.dut
Branch 4 "483805220" "((DPD_MAX_TAPS < 1) || (DPD_MAX_TAPS > 4))" (0) "((DPD_MAX_TAPS < 1) || (DPD_MAX_TAPS > 4)) 1"

CHECKSUM: "2004831198 3476809210"
// ANNOTATION: "ModuleName: thermo5_dpd_axi_lite_cfg"
INSTANCE: thermo5_sku_uvm_tb.dut.u_cfg
Block 102 "1801152156" "$error(\"MAX_TAPS must be in [1,4]; got %0d\", MAX_TAPS);"

CHECKSUM: "2408948792 3793036546"
// ANNOTATION: "ModuleName: gt_tx_user_bridge"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[0].g_order2.u_tid.u_raw_boundary.u_bridge
Block 2 "1714829022" "$error(\"Current bridge requires PARALLEL_W == GT_USER_W; use a dedicated gearbox otherwise\");"

CHECKSUM: "2408948792 3793036546"
// ANNOTATION: "ModuleName: gt_tx_user_bridge"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[1].g_order2.u_tid.u_raw_boundary.u_bridge
Block 2 "1714829022" "$error(\"Current bridge requires PARALLEL_W == GT_USER_W; use a dedicated gearbox otherwise\");"

CHECKSUM: "2408948792 3793036546"
// ANNOTATION: "ModuleName: gt_tx_user_bridge"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[2].g_order2.u_tid.u_raw_boundary.u_bridge
Block 2 "1714829022" "$error(\"Current bridge requires PARALLEL_W == GT_USER_W; use a dedicated gearbox otherwise\");"

CHECKSUM: "2408948792 3793036546"
// ANNOTATION: "ModuleName: gt_tx_user_bridge"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[3].g_order2.u_tid.u_raw_boundary.u_bridge
Block 2 "1714829022" "$error(\"Current bridge requires PARALLEL_W == GT_USER_W; use a dedicated gearbox otherwise\");"

CHECKSUM: "2611591664 1177502884"
// ANNOTATION: "ModuleName: dsm_interp_x2_centered_cubic_vector"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2
Block 11 "533302283" "out_i_vec[W+:W] = cubic_midpoint(tail_sample_i_q, '0, '0, '0);"

CHECKSUM: "3956776050 3099917648"
// ANNOTATION: "ModuleName: tid32_thermo5_axi_lite_axis_frontend_tx"
INSTANCE: thermo5_sku_uvm_tb.dut
Block 44 "3804099319" "$error(\"DPD_MAX_TAPS must be in [1,4]; got %0d\", DPD_MAX_TAPS);"
