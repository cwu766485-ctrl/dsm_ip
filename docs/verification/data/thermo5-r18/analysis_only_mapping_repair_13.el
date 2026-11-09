// ANALYSIS_ONLY: 13 repaired native mappings; not an approved official exclusion.
CHECKSUM: "1467091198 3627519779"
// ANNOTATION: "ModuleName: dsm_axis14_to_core8_cdc"
INSTANCE: thermo5_sku_uvm_tb.dut.u_cdc
Branch 0 "1959897721" "(!c_rst_n)" (13) "(!c_rst_n) 0,-,1,-,-,0 2 4 6 ,1,-,1,1,-,-"
Branch 0 "1959897721" "(!c_rst_n)" (20) "(!c_rst_n) 0,-,1,-,-,default,-,-,-,-,-,-"

CHECKSUM: "2176286378 461185685"
// ANNOTATION: "ModuleName: dsm_frame_gain_vector"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_frame_gain
Branch 0 "2242509409" "(!rst_n)" (2) "(!rst_n) 0,1,0,-,-,-,-,-,-,-,-"

CHECKSUM: "2611591664 1177502884"
// ANNOTATION: "ModuleName: dsm_interp_x2_centered_cubic_vector"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1
Block 73 "2770546180" "$error(\"centered cubic interpolator requires LANES >= 2\");"
Block 76 "2677840523" "$error(\"centered cubic coefficients require Q14\");"

CHECKSUM: "2611591664 1177502884"
// ANNOTATION: "ModuleName: dsm_interp_x2_centered_cubic_vector"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2
Block 73 "2770546180" "$error(\"centered cubic interpolator requires LANES >= 2\");"
Block 76 "2677840523" "$error(\"centered cubic coefficients require Q14\");"

CHECKSUM: "2611591664 791396721"
// ANNOTATION: "ModuleName: dsm_interp_x2_centered_cubic_vector"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1
Branch 1 "2959318469" "(!rst_n)" (2) "(!rst_n) 0,1,0,-,-,-,-,-,-,-,-,-,-"
Branch 1 "2959318469" "(!rst_n)" (8) "(!rst_n) 0,0,-,-,-,-,1,-,-,-,-,-,-"

CHECKSUM: "2611591664 791396721"
// ANNOTATION: "ModuleName: dsm_interp_x2_centered_cubic_vector"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2
Branch 0 "3836088345" "tail_output" (0) "tail_output 1,-"
Branch 1 "2959318469" "(!rst_n)" (2) "(!rst_n) 0,1,0,-,-,-,-,-,-,-,-,-,-"
Branch 1 "2959318469" "(!rst_n)" (3) "(!rst_n) 0,0,-,1,-,-,-,-,-,-,-,-,-"
Branch 1 "2959318469" "(!rst_n)" (5) "(!rst_n) 0,0,-,-,1,1,-,-,-,-,-,-,-"
