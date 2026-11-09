// ANALYSIS_ONLY: not an official approved exclusion.
CHECKSUM: "1491642939 4234966567"
// ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[0].g_order2.u_tid
Branch 0 "1027625233" "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0))" (0) "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0)) 1"
Branch 1 "4262564349" "PAIR_LOOKAHEAD" (0) "PAIR_LOOKAHEAD 1"
Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))" (0) "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw}))) 1"
Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))" (1) "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw}))) 0"
Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))" (0) "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)) 1"
Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))" (1) "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)) 0"
Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))" (0) "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1"
Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))" (1) "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 0"
Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))" (0) "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1"
Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))" (1) "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 0"
Branch 4 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
Branch 4 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
Branch 5 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
Branch 5 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
Branch 6 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
Branch 6 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
Branch 7 "3538857052" "result.q1_positive" (0) "result.q1_positive 1"
Branch 7 "3538857052" "result.q1_positive" (1) "result.q1_positive 0"
Branch 8 "3292009172" "(u0_check > 0)" (0) "(u0_check > 0) 1"
Branch 8 "3292009172" "(u0_check > 0)" (1) "(u0_check > 0) 0"
Branch 9 "2944370531" "(u1_check > 0)" (0) "(u1_check > 0) 1"
Branch 9 "2944370531" "(u1_check > 0)" (1) "(u1_check > 0) 0"

CHECKSUM: "1491642939 4234966567"
// ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[1].g_order2.u_tid
Branch 0 "1027625233" "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0))" (0) "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0)) 1"
Branch 1 "4262564349" "PAIR_LOOKAHEAD" (0) "PAIR_LOOKAHEAD 1"
Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))" (0) "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw}))) 1"
Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))" (1) "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw}))) 0"
Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))" (0) "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)) 1"
Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))" (1) "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)) 0"
Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))" (0) "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1"
Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))" (1) "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 0"
Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))" (0) "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1"
Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))" (1) "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 0"
Branch 4 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
Branch 4 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
Branch 5 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
Branch 5 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
Branch 6 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
Branch 6 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
Branch 7 "3538857052" "result.q1_positive" (0) "result.q1_positive 1"
Branch 7 "3538857052" "result.q1_positive" (1) "result.q1_positive 0"
Branch 8 "3292009172" "(u0_check > 0)" (0) "(u0_check > 0) 1"
Branch 8 "3292009172" "(u0_check > 0)" (1) "(u0_check > 0) 0"
Branch 9 "2944370531" "(u1_check > 0)" (0) "(u1_check > 0) 1"
Branch 9 "2944370531" "(u1_check > 0)" (1) "(u1_check > 0) 0"

CHECKSUM: "1491642939 4234966567"
// ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[2].g_order2.u_tid
Branch 0 "1027625233" "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0))" (0) "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0)) 1"
Branch 1 "4262564349" "PAIR_LOOKAHEAD" (0) "PAIR_LOOKAHEAD 1"
Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))" (0) "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw}))) 1"
Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))" (1) "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw}))) 0"
Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))" (0) "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)) 1"
Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))" (1) "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)) 0"
Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))" (0) "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1"
Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))" (1) "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 0"
Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))" (0) "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1"
Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))" (1) "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 0"
Branch 4 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
Branch 4 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
Branch 5 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
Branch 5 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
Branch 6 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
Branch 6 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
Branch 7 "3538857052" "result.q1_positive" (0) "result.q1_positive 1"
Branch 7 "3538857052" "result.q1_positive" (1) "result.q1_positive 0"
Branch 8 "3292009172" "(u0_check > 0)" (0) "(u0_check > 0) 1"
Branch 8 "3292009172" "(u0_check > 0)" (1) "(u0_check > 0) 0"
Branch 9 "2944370531" "(u1_check > 0)" (0) "(u1_check > 0) 1"
Branch 9 "2944370531" "(u1_check > 0)" (1) "(u1_check > 0) 0"

CHECKSUM: "1491642939 4234966567"
// ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[3].g_order2.u_tid
Branch 0 "1027625233" "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0))" (0) "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0)) 1"
Branch 1 "4262564349" "PAIR_LOOKAHEAD" (0) "PAIR_LOOKAHEAD 1"
Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))" (0) "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw}))) 1"
Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))" (1) "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw}))) 0"
Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))" (0) "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)) 1"
Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))" (1) "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)) 0"
Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))" (0) "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1"
Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))" (1) "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 0"
Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))" (0) "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1"
Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))" (1) "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 0"
Branch 4 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
Branch 4 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
Branch 5 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
Branch 5 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
Branch 6 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
Branch 6 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
Branch 7 "3538857052" "result.q1_positive" (0) "result.q1_positive 1"
Branch 7 "3538857052" "result.q1_positive" (1) "result.q1_positive 0"
Branch 8 "3292009172" "(u0_check > 0)" (0) "(u0_check > 0) 1"
Branch 8 "3292009172" "(u0_check > 0)" (1) "(u0_check > 0) 0"
Branch 9 "2944370531" "(u1_check > 0)" (0) "(u1_check > 0) 1"
Branch 9 "2944370531" "(u1_check > 0)" (1) "(u1_check > 0) 0"

CHECKSUM: "1491642939 475307837"
// ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[0].g_order2.u_tid
Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1" (1 "0")
Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1" (2 "1")
Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1" (1 "0")
Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1" (2 "1")
Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1" (1 "0")
Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1" (2 "1")
Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1" (1 "0")
Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1" (2 "1")
Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1" (1 "0")
Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1" (2 "1")
Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1" (1 "0")
Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1" (2 "1")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (1 "00000000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (2 "00000001")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (3 "00000010")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (4 "00000100")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (5 "00001000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (6 "00010000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (7 "00100000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (8 "01000000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (9 "10000000")
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (1 "00")
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (2 "01")
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (3 "10")
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (1 "00")
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (2 "01")
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (3 "10")

CHECKSUM: "1491642939 475307837"
// ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[1].g_order2.u_tid
Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1" (1 "0")
Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1" (2 "1")
Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1" (1 "0")
Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1" (2 "1")
Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1" (1 "0")
Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1" (2 "1")
Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1" (1 "0")
Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1" (2 "1")
Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1" (1 "0")
Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1" (2 "1")
Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1" (1 "0")
Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1" (2 "1")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (1 "00000000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (2 "00000001")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (3 "00000010")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (4 "00000100")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (5 "00001000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (6 "00010000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (7 "00100000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (8 "01000000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (9 "10000000")
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (1 "00")
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (2 "01")
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (3 "10")
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (1 "00")
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (2 "01")
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (3 "10")

CHECKSUM: "1491642939 475307837"
// ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[2].g_order2.u_tid
Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1" (1 "0")
Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1" (2 "1")
Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1" (1 "0")
Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1" (2 "1")
Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1" (1 "0")
Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1" (2 "1")
Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1" (1 "0")
Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1" (2 "1")
Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1" (1 "0")
Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1" (2 "1")
Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1" (1 "0")
Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1" (2 "1")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (1 "00000000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (2 "00000001")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (3 "00000010")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (4 "00000100")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (5 "00001000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (6 "00010000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (7 "00100000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (8 "01000000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (9 "10000000")
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (1 "00")
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (2 "01")
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (3 "10")
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (1 "00")
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (2 "01")
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (3 "10")

CHECKSUM: "1491642939 475307837"
// ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[3].g_order2.u_tid
Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1" (1 "0")
Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1" (2 "1")
Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1" (1 "0")
Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1" (2 "1")
Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1" (1 "0")
Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1" (2 "1")
Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1" (1 "0")
Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1" (2 "1")
Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1" (1 "0")
Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1" (2 "1")
Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1" (1 "0")
Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1" (2 "1")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (1 "00000000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (2 "00000001")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (3 "00000010")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (4 "00000100")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (5 "00001000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (6 "00010000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (7 "00100000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (8 "01000000")
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (9 "10000000")
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (1 "00")
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (2 "01")
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (3 "10")
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (1 "00")
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (2 "01")
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (3 "10")

CHECKSUM: "1491642939 3816297385"
// ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[0].g_order2.u_tid
Block 10 "1823560241" "result.no_wrap = 1'b0;"
Block 12 "3963672532" "if (((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)))"
Block 13 "166068688" "result.in_bounds = 1'b0;"
Block 15 "2688762522" "if (((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)))"
Block 16 "2928090559" "result.clamp_positive = 1'b1;"
Block 18 "2067348821" "if (((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)))"
Block 19 "2096939491" "result.clamp_negative = 1'b1;"
Block 2 "1438331943" "$error(\"EF2 TID requires W >= 2 and an even CHANNELS >= 2\");"
Block 21 "1987362058" "ef2_pair_lookahead = result;"
Block 23 "1348277332" "for (lane = 0; (lane < CHANNELS); lane = (lane + 2))"
Block 24 "3373271100" "pair_i = ef2_pair_lookahead(in_i_poly_vec[(lane * W)+:W], in_i_poly_vec[((lane + 1) * W)+:W], work_err1_i, work_err2_i);"
Block 25 "1569554602" "arithmetic_no_wrap_comb = 1'b0;"
Block 27 "1798126418" "if (((!pair_i.in_bounds) || (!pair_q.in_bounds)))"
Block 28 "798455005" "arithmetic_bounds_comb = 1'b0;"
Block 30 "3374411478" "if ((pair_i.clamp_positive || pair_q.clamp_positive))"
Block 31 "532586829" "clamp_positive_comb = 1'b1;"
Block 33 "1302622107" "if ((pair_i.clamp_negative || pair_q.clamp_negative))"
Block 34 "3113880436" "clamp_negative_comb = 1'b1;"
Block 36 "1801196460" "raw_word_comb[(2 * lane)] = pair_i.q0_positive;"
Block 39 "2530053887" "arithmetic_bounds_comb = 1'b0;"
Block 42 "844472052" "arithmetic_no_wrap_comb = 1'b0;"
Block 9 "2541824417" "result = '0;"

CHECKSUM: "1491642939 3816297385"
// ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[1].g_order2.u_tid
Block 10 "1823560241" "result.no_wrap = 1'b0;"
Block 12 "3963672532" "if (((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)))"
Block 13 "166068688" "result.in_bounds = 1'b0;"
Block 15 "2688762522" "if (((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)))"
Block 16 "2928090559" "result.clamp_positive = 1'b1;"
Block 18 "2067348821" "if (((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)))"
Block 19 "2096939491" "result.clamp_negative = 1'b1;"
Block 2 "1438331943" "$error(\"EF2 TID requires W >= 2 and an even CHANNELS >= 2\");"
Block 21 "1987362058" "ef2_pair_lookahead = result;"
Block 23 "1348277332" "for (lane = 0; (lane < CHANNELS); lane = (lane + 2))"
Block 24 "3373271100" "pair_i = ef2_pair_lookahead(in_i_poly_vec[(lane * W)+:W], in_i_poly_vec[((lane + 1) * W)+:W], work_err1_i, work_err2_i);"
Block 25 "1569554602" "arithmetic_no_wrap_comb = 1'b0;"
Block 27 "1798126418" "if (((!pair_i.in_bounds) || (!pair_q.in_bounds)))"
Block 28 "798455005" "arithmetic_bounds_comb = 1'b0;"
Block 30 "3374411478" "if ((pair_i.clamp_positive || pair_q.clamp_positive))"
Block 31 "532586829" "clamp_positive_comb = 1'b1;"
Block 33 "1302622107" "if ((pair_i.clamp_negative || pair_q.clamp_negative))"
Block 34 "3113880436" "clamp_negative_comb = 1'b1;"
Block 36 "1801196460" "raw_word_comb[(2 * lane)] = pair_i.q0_positive;"
Block 39 "2530053887" "arithmetic_bounds_comb = 1'b0;"
Block 42 "844472052" "arithmetic_no_wrap_comb = 1'b0;"
Block 9 "2541824417" "result = '0;"

CHECKSUM: "1491642939 3816297385"
// ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[2].g_order2.u_tid
Block 10 "1823560241" "result.no_wrap = 1'b0;"
Block 12 "3963672532" "if (((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)))"
Block 13 "166068688" "result.in_bounds = 1'b0;"
Block 15 "2688762522" "if (((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)))"
Block 16 "2928090559" "result.clamp_positive = 1'b1;"
Block 18 "2067348821" "if (((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)))"
Block 19 "2096939491" "result.clamp_negative = 1'b1;"
Block 2 "1438331943" "$error(\"EF2 TID requires W >= 2 and an even CHANNELS >= 2\");"
Block 21 "1987362058" "ef2_pair_lookahead = result;"
Block 23 "1348277332" "for (lane = 0; (lane < CHANNELS); lane = (lane + 2))"
Block 24 "3373271100" "pair_i = ef2_pair_lookahead(in_i_poly_vec[(lane * W)+:W], in_i_poly_vec[((lane + 1) * W)+:W], work_err1_i, work_err2_i);"
Block 25 "1569554602" "arithmetic_no_wrap_comb = 1'b0;"
Block 27 "1798126418" "if (((!pair_i.in_bounds) || (!pair_q.in_bounds)))"
Block 28 "798455005" "arithmetic_bounds_comb = 1'b0;"
Block 30 "3374411478" "if ((pair_i.clamp_positive || pair_q.clamp_positive))"
Block 31 "532586829" "clamp_positive_comb = 1'b1;"
Block 33 "1302622107" "if ((pair_i.clamp_negative || pair_q.clamp_negative))"
Block 34 "3113880436" "clamp_negative_comb = 1'b1;"
Block 36 "1801196460" "raw_word_comb[(2 * lane)] = pair_i.q0_positive;"
Block 39 "2530053887" "arithmetic_bounds_comb = 1'b0;"
Block 42 "844472052" "arithmetic_no_wrap_comb = 1'b0;"
Block 9 "2541824417" "result = '0;"

CHECKSUM: "1491642939 3816297385"
// ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[3].g_order2.u_tid
Block 10 "1823560241" "result.no_wrap = 1'b0;"
Block 12 "3963672532" "if (((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)))"
Block 13 "166068688" "result.in_bounds = 1'b0;"
Block 15 "2688762522" "if (((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)))"
Block 16 "2928090559" "result.clamp_positive = 1'b1;"
Block 18 "2067348821" "if (((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)))"
Block 19 "2096939491" "result.clamp_negative = 1'b1;"
Block 2 "1438331943" "$error(\"EF2 TID requires W >= 2 and an even CHANNELS >= 2\");"
Block 21 "1987362058" "ef2_pair_lookahead = result;"
Block 23 "1348277332" "for (lane = 0; (lane < CHANNELS); lane = (lane + 2))"
Block 24 "3373271100" "pair_i = ef2_pair_lookahead(in_i_poly_vec[(lane * W)+:W], in_i_poly_vec[((lane + 1) * W)+:W], work_err1_i, work_err2_i);"
Block 25 "1569554602" "arithmetic_no_wrap_comb = 1'b0;"
Block 27 "1798126418" "if (((!pair_i.in_bounds) || (!pair_q.in_bounds)))"
Block 28 "798455005" "arithmetic_bounds_comb = 1'b0;"
Block 30 "3374411478" "if ((pair_i.clamp_positive || pair_q.clamp_positive))"
Block 31 "532586829" "clamp_positive_comb = 1'b1;"
Block 33 "1302622107" "if ((pair_i.clamp_negative || pair_q.clamp_negative))"
Block 34 "3113880436" "clamp_negative_comb = 1'b1;"
Block 36 "1801196460" "raw_word_comb[(2 * lane)] = pair_i.q0_positive;"
Block 39 "2530053887" "arithmetic_bounds_comb = 1'b0;"
Block 42 "844472052" "arithmetic_no_wrap_comb = 1'b0;"
Block 9 "2541824417" "result = '0;"
