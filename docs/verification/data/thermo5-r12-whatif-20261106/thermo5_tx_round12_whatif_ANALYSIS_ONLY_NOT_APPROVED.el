// ANALYSIS ONLY — Round 12 what-if; NOT APPROVED; NOT OFFICIAL SIGNOFF.
CHECKSUM: "1491642939 3816297385"
//
ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[0].g_order2.u_tid
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 96"
// Block 1 "4179345703" "if ((((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 97"
// Block 2 "1438331943" "$error(\"EF2 TID requires W >= 2 and an even CHANNELS >= 2\");"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 104"
// Block 4 "1253481452" "if ((value > STATE_MAX))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 105"
// Block 5 "3204619702" "sat_error = STATE_MAX[(STATE_W - 1):0];"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 106"
// Block 6 "1460796149" "if ((value < STATE_MIN))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 107"
// Block 7 "821581261" "sat_error = STATE_MIN[(STATE_W - 1):0];"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 109"
// Block 8 "869581897" "sat_error = value[(STATE_W - 1):0];"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 135"
// ANALYSIS CANDIDATE IDS: W-d9827c096f29d49db7c8,W-1f9a5f4a25a2d836899f,W-a72f204869a2ee9ddf56,W-42e2e69bfe78d6951cff,W-cc5e71e53ff7e83ee8fa,W-6394ea062435c9c9fe06,W-ee81b55b6181ff10766c,W-7a670d2946f401122c59,W-07a0f27c32de88f046a9,W-229ee8acfdcd67e212ec,W-04d1bf092963b5bad001,W-9dfa47ebe611de76ddb0,W-917acd07fb6f5a877d37,W-8dfb55cb55ccf08c708b,W-5ddcb60b84d6c659e7ff,W-55c5bf4f473a270b1f6c,W-1213640b63216b99704a,W-7b4624534ab79eb36d4a,W-0752954f1eee4d6ec53d,W-10d821a34b17579f02c3,W-4e22726ff0f040c0ab7b,W-8d3291b73eea098de233,W-49022008a08659bc5d6b,W-6aa2d5373d632c446038,W-8a3e2c0352fdfe07e9ea,W-5e8ff1cbfa1fe95f6f80,W-fa86d062e9f95919aa8a,W-50ae5c7f8ae8b3f4cfad,W-b0d10d557c0477382f1c,W-fc04b58d353bd3465043
// RAW BIN IDS: d9827c096f29d49db7c8,1f9a5f4a25a2d836899f,a72f204869a2ee9ddf56,42e2e69bfe78d6951cff,cc5e71e53ff7e83ee8fa,6394ea062435c9c9fe06,ee81b55b6181ff10766c,7a670d2946f401122c59,07a0f27c32de88f046a9,229ee8acfdcd67e212ec,04d1bf092963b5bad001,9dfa47ebe611de76ddb0,917acd07fb6f5a877d37,8dfb55cb55ccf08c708b,5ddcb60b84d6c659e7ff,55c5bf4f473a270b1f6c,1213640b63216b99704a,7b4624534ab79eb36d4a,0752954f1eee4d6ec53d,10d821a34b17579f02c3,4e22726ff0f040c0ab7b,8d3291b73eea098de233,49022008a08659bc5d6b,6aa2d5373d632c446038,8a3e2c0352fdfe07e9ea,5e8ff1cbfa1fe95f6f80,fa86d062e9f95919aa8a,50ae5c7f8ae8b3f4cfad,b0d10d557c0477382f1c,fc04b58d353bd3465043
Block 9 "2541824417" "result = '0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 179"
// ANALYSIS CANDIDATE IDS: W-5b6b0577cfedb2ad1a8d
// RAW BIN IDS: 5b6b0577cfedb2ad1a8d
Block 10 "1823560241" "result.no_wrap = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 180"
// ANALYSIS CANDIDATE IDS: W-575f7510735d3fdc19dc
// RAW BIN IDS: 575f7510735d3fdc19dc
Block 12 "3963672532" "if (((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 186"
// ANALYSIS CANDIDATE IDS: W-c72cc2e47b2d5358cb87
// RAW BIN IDS: c72cc2e47b2d5358cb87
Block 13 "166068688" "result.in_bounds = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 187"
// ANALYSIS CANDIDATE IDS: W-8b112ab1a89543e44b24
// RAW BIN IDS: 8b112ab1a89543e44b24
Block 15 "2688762522" "if (((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 188"
// ANALYSIS CANDIDATE IDS: W-b6289fa920a0d74f0fc6
// RAW BIN IDS: b6289fa920a0d74f0fc6
Block 16 "2928090559" "result.clamp_positive = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 189"
// ANALYSIS CANDIDATE IDS: W-71ba1c444f2383a13ca4
// RAW BIN IDS: 71ba1c444f2383a13ca4
Block 18 "2067348821" "if (((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 190"
// ANALYSIS CANDIDATE IDS: W-9277c2bd0c3da2989dcd
// RAW BIN IDS: 9277c2bd0c3da2989dcd
Block 19 "2096939491" "result.clamp_negative = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 191"
// ANALYSIS CANDIDATE IDS: W-3fd72975fb57e53a02ea
// RAW BIN IDS: 3fd72975fb57e53a02ea
Block 21 "1987362058" "ef2_pair_lookahead = result;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 196"
// Block 22 "3465493753" "work_err1_i = err1_i_q;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 232"
// Block 23 "1348277332" "for (lane = 0; (lane < CHANNELS); lane = (lane + 2))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 233"
// Block 24 "3373271100" "pair_i = ef2_pair_lookahead(in_i_poly_vec[(lane * W)+:W], in_i_poly_vec[((lane + 1) * W)+:W], work_err1_i, work_err2_i);"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 240"
// Block 25 "1569554602" "arithmetic_no_wrap_comb = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 241"
// Block 27 "1798126418" "if (((!pair_i.in_bounds) || (!pair_q.in_bounds)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 242"
// Block 28 "798455005" "arithmetic_bounds_comb = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 243"
// Block 30 "3374411478" "if ((pair_i.clamp_positive || pair_q.clamp_positive))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 244"
// Block 31 "532586829" "clamp_positive_comb = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 245"
// Block 33 "1302622107" "if ((pair_i.clamp_negative || pair_q.clamp_negative))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 246"
// Block 34 "3113880436" "clamp_negative_comb = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 249"
// Block 36 "1801196460" "raw_word_comb[(2 * lane)] = pair_i.q0_positive;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 259"
// Block 37 "2725469672" "for (lane = 0; (lane < CHANNELS); lane = (lane + 1))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 260"
// Block 38 "924583898" "x_i_wide = {{(ACC_W - W) {in_i_poly_vec[(((lane * W) + W) - 1)]}}, in_i_poly_vec[(lane * W)+:W]};"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 290"
// Block 39 "2530053887" "arithmetic_bounds_comb = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 292"
// Block 41 "3213577612" "y_i_positive = (u_i > 0);"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 300"
// Block 42 "844472052" "arithmetic_no_wrap_comb = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 301"
// Block 44 "1128344301" "if (((e_i_raw > STATE_MAX) || (e_q_raw > STATE_MAX)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 302"
// Block 45 "1595302431" "clamp_positive_comb = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 303"
// Block 47 "307680839" "if (((e_i_raw < STATE_MIN) || (e_q_raw < STATE_MIN)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 304"
// Block 48 "1827407716" "clamp_negative_comb = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 307"
// Block 50 "4262396638" "if (((lane % 2) == 0))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 308"
// Block 51 "340702176" "raw_word_comb[(2 * lane)] = y_i_positive;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 311"
// Block 52 "1683336911" "raw_word_comb[(2 * lane)] = (!y_i_positive);"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 315"
// Block 53 "2603064589" "work_err2_i = work_err1_i;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 322"
// Block 54 "3848387695" "err1_i_next = work_err1_i;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 332"
// Block 55 "1335899302" "if ((!rst_n))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 333"
// Block 56 "1109412139" "err1_i_q <= '0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 339"
// Block 57 "1164260594" "if (tid_ready)"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 340"
// Block 58 "2261620474" "tid_valid_q <= accept_word;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 342"
// Block 59 "604718672" "err1_i_q <= err1_i_next;"



CHECKSUM: "1491642939 3816297385"
//
ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[1].g_order2.u_tid
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 96"
// Block 1 "4179345703" "if ((((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 97"
// Block 2 "1438331943" "$error(\"EF2 TID requires W >= 2 and an even CHANNELS >= 2\");"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 104"
// Block 4 "1253481452" "if ((value > STATE_MAX))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 105"
// Block 5 "3204619702" "sat_error = STATE_MAX[(STATE_W - 1):0];"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 106"
// Block 6 "1460796149" "if ((value < STATE_MIN))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 107"
// Block 7 "821581261" "sat_error = STATE_MIN[(STATE_W - 1):0];"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 109"
// Block 8 "869581897" "sat_error = value[(STATE_W - 1):0];"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 135"
// ANALYSIS CANDIDATE IDS: W-c5834ccdd5cff37277c5,W-211603c470ec8c01a0a5,W-6d201e709a75c380766a,W-79c87e7f9c72245df01e,W-3781264a66aa190092ba,W-fa175c42bd5dea653671,W-8cf671fc3af746a6d1b7,W-46a304310d8a8a2cf170,W-0874983a5e4252f31393,W-94f2f1abac837f5439f7,W-01e283b31014a0da780a,W-2cf1ba300c49f1d7844a,W-f6786ca1b98331be3ba5,W-58bfddd08af67747467b,W-a6eee56c2c2d19105aef,W-7e4ceeaaa5571127d817,W-60ec329e121876849da9,W-7b7e806cac2f0fcf0e83,W-2f0da7e898bb4762253b,W-a18b9ff39e6b91f3f454,W-ff6944f5e9982e46af04,W-feca8c3eba1ec76b21aa,W-9c143b4d24f05c2dcc7a,W-1bfe670a18aa509bac73,W-cb3eea4a51691c1a4a18,W-a8c66d70ef7e512e4b47,W-cf58c6da539de6a90bed,W-7d1d4a682a8d997443e5,W-6b9b9edd4bc973c237a3,W-4c035a7df8801a81e4ab
// RAW BIN IDS: c5834ccdd5cff37277c5,211603c470ec8c01a0a5,6d201e709a75c380766a,79c87e7f9c72245df01e,3781264a66aa190092ba,fa175c42bd5dea653671,8cf671fc3af746a6d1b7,46a304310d8a8a2cf170,0874983a5e4252f31393,94f2f1abac837f5439f7,01e283b31014a0da780a,2cf1ba300c49f1d7844a,f6786ca1b98331be3ba5,58bfddd08af67747467b,a6eee56c2c2d19105aef,7e4ceeaaa5571127d817,60ec329e121876849da9,7b7e806cac2f0fcf0e83,2f0da7e898bb4762253b,a18b9ff39e6b91f3f454,ff6944f5e9982e46af04,feca8c3eba1ec76b21aa,9c143b4d24f05c2dcc7a,1bfe670a18aa509bac73,cb3eea4a51691c1a4a18,a8c66d70ef7e512e4b47,cf58c6da539de6a90bed,7d1d4a682a8d997443e5,6b9b9edd4bc973c237a3,4c035a7df8801a81e4ab
Block 9 "2541824417" "result = '0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 179"
// ANALYSIS CANDIDATE IDS: W-30c88abe7026d4074eda
// RAW BIN IDS: 30c88abe7026d4074eda
Block 10 "1823560241" "result.no_wrap = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 180"
// ANALYSIS CANDIDATE IDS: W-03d87a386dc82a6750f9
// RAW BIN IDS: 03d87a386dc82a6750f9
Block 12 "3963672532" "if (((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 186"
// ANALYSIS CANDIDATE IDS: W-6a141dbb7b22ee6e1812
// RAW BIN IDS: 6a141dbb7b22ee6e1812
Block 13 "166068688" "result.in_bounds = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 187"
// ANALYSIS CANDIDATE IDS: W-cfab3c0ed579a6b379ea
// RAW BIN IDS: cfab3c0ed579a6b379ea
Block 15 "2688762522" "if (((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 188"
// ANALYSIS CANDIDATE IDS: W-80cd257ac24f1a3badb1
// RAW BIN IDS: 80cd257ac24f1a3badb1
Block 16 "2928090559" "result.clamp_positive = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 189"
// ANALYSIS CANDIDATE IDS: W-912dfaff98d46eab12b7
// RAW BIN IDS: 912dfaff98d46eab12b7
Block 18 "2067348821" "if (((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 190"
// ANALYSIS CANDIDATE IDS: W-9318a4b71f586335a2e7
// RAW BIN IDS: 9318a4b71f586335a2e7
Block 19 "2096939491" "result.clamp_negative = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 191"
// ANALYSIS CANDIDATE IDS: W-b08b4be248eeb0c4dfba
// RAW BIN IDS: b08b4be248eeb0c4dfba
Block 21 "1987362058" "ef2_pair_lookahead = result;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 196"
// Block 22 "3465493753" "work_err1_i = err1_i_q;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 232"
// Block 23 "1348277332" "for (lane = 0; (lane < CHANNELS); lane = (lane + 2))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 233"
// Block 24 "3373271100" "pair_i = ef2_pair_lookahead(in_i_poly_vec[(lane * W)+:W], in_i_poly_vec[((lane + 1) * W)+:W], work_err1_i, work_err2_i);"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 240"
// Block 25 "1569554602" "arithmetic_no_wrap_comb = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 241"
// Block 27 "1798126418" "if (((!pair_i.in_bounds) || (!pair_q.in_bounds)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 242"
// Block 28 "798455005" "arithmetic_bounds_comb = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 243"
// Block 30 "3374411478" "if ((pair_i.clamp_positive || pair_q.clamp_positive))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 244"
// Block 31 "532586829" "clamp_positive_comb = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 245"
// Block 33 "1302622107" "if ((pair_i.clamp_negative || pair_q.clamp_negative))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 246"
// Block 34 "3113880436" "clamp_negative_comb = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 249"
// Block 36 "1801196460" "raw_word_comb[(2 * lane)] = pair_i.q0_positive;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 259"
// Block 37 "2725469672" "for (lane = 0; (lane < CHANNELS); lane = (lane + 1))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 260"
// Block 38 "924583898" "x_i_wide = {{(ACC_W - W) {in_i_poly_vec[(((lane * W) + W) - 1)]}}, in_i_poly_vec[(lane * W)+:W]};"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 290"
// Block 39 "2530053887" "arithmetic_bounds_comb = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 292"
// Block 41 "3213577612" "y_i_positive = (u_i > 0);"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 300"
// Block 42 "844472052" "arithmetic_no_wrap_comb = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 301"
// Block 44 "1128344301" "if (((e_i_raw > STATE_MAX) || (e_q_raw > STATE_MAX)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 302"
// Block 45 "1595302431" "clamp_positive_comb = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 303"
// Block 47 "307680839" "if (((e_i_raw < STATE_MIN) || (e_q_raw < STATE_MIN)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 304"
// Block 48 "1827407716" "clamp_negative_comb = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 307"
// Block 50 "4262396638" "if (((lane % 2) == 0))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 308"
// Block 51 "340702176" "raw_word_comb[(2 * lane)] = y_i_positive;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 311"
// Block 52 "1683336911" "raw_word_comb[(2 * lane)] = (!y_i_positive);"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 315"
// Block 53 "2603064589" "work_err2_i = work_err1_i;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 322"
// Block 54 "3848387695" "err1_i_next = work_err1_i;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 332"
// Block 55 "1335899302" "if ((!rst_n))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 333"
// Block 56 "1109412139" "err1_i_q <= '0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 339"
// Block 57 "1164260594" "if (tid_ready)"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 340"
// Block 58 "2261620474" "tid_valid_q <= accept_word;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 342"
// Block 59 "604718672" "err1_i_q <= err1_i_next;"



CHECKSUM: "1491642939 3816297385"
//
ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[2].g_order2.u_tid
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 96"
// Block 1 "4179345703" "if ((((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 97"
// Block 2 "1438331943" "$error(\"EF2 TID requires W >= 2 and an even CHANNELS >= 2\");"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 104"
// Block 4 "1253481452" "if ((value > STATE_MAX))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 105"
// Block 5 "3204619702" "sat_error = STATE_MAX[(STATE_W - 1):0];"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 106"
// Block 6 "1460796149" "if ((value < STATE_MIN))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 107"
// Block 7 "821581261" "sat_error = STATE_MIN[(STATE_W - 1):0];"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 109"
// Block 8 "869581897" "sat_error = value[(STATE_W - 1):0];"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 135"
// ANALYSIS CANDIDATE IDS: W-f746d64415647ff81144,W-639907b7d92c38d05e63,W-70ed622485a3aaf5494f,W-d63a9940f336816acd4e,W-cb57496cb010643b8f10,W-a475f151d1437657d9f2,W-e3dfdf8edff28a99f745,W-32667f514183eee6bde4,W-9c5123c9133c520a52a2,W-83b6dd045e6be4de355e,W-018e67bb3a526947f1a2,W-069a6dd7ec35d2ee57cd,W-4476fbeccaa2afafe670,W-2af4a5f19130e24028b3,W-4865c010e3e69ee45319,W-565adf76c103434f7edd,W-33b97c7d860548d583e0,W-61675fb8dfe421df185b,W-d081fd979754f84086ae,W-39f520f45a8f6fc3eed7,W-0ead5797759f150747f2,W-ca57bcdb25b67316f037,W-04b84c45b7c8689a4753,W-3e9ec6f1e620f2acbcb9,W-9b78b59eda9b607d32ff,W-06714201acf9b54c6aa4,W-4f2ce53b49ed0c668569,W-4cac609b67249f9f36dc,W-c2399d9b3bf054bf1d61,W-a7dbfd9393104c0c70a0
// RAW BIN IDS: f746d64415647ff81144,639907b7d92c38d05e63,70ed622485a3aaf5494f,d63a9940f336816acd4e,cb57496cb010643b8f10,a475f151d1437657d9f2,e3dfdf8edff28a99f745,32667f514183eee6bde4,9c5123c9133c520a52a2,83b6dd045e6be4de355e,018e67bb3a526947f1a2,069a6dd7ec35d2ee57cd,4476fbeccaa2afafe670,2af4a5f19130e24028b3,4865c010e3e69ee45319,565adf76c103434f7edd,33b97c7d860548d583e0,61675fb8dfe421df185b,d081fd979754f84086ae,39f520f45a8f6fc3eed7,0ead5797759f150747f2,ca57bcdb25b67316f037,04b84c45b7c8689a4753,3e9ec6f1e620f2acbcb9,9b78b59eda9b607d32ff,06714201acf9b54c6aa4,4f2ce53b49ed0c668569,4cac609b67249f9f36dc,c2399d9b3bf054bf1d61,a7dbfd9393104c0c70a0
Block 9 "2541824417" "result = '0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 179"
// ANALYSIS CANDIDATE IDS: W-d18bc73740ad60830f8d
// RAW BIN IDS: d18bc73740ad60830f8d
Block 10 "1823560241" "result.no_wrap = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 180"
// ANALYSIS CANDIDATE IDS: W-cae348b8e78df8780cfa
// RAW BIN IDS: cae348b8e78df8780cfa
Block 12 "3963672532" "if (((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 186"
// ANALYSIS CANDIDATE IDS: W-5d45ff4b703c83faa7ab
// RAW BIN IDS: 5d45ff4b703c83faa7ab
Block 13 "166068688" "result.in_bounds = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 187"
// ANALYSIS CANDIDATE IDS: W-d788ad798fb3aef5f334
// RAW BIN IDS: d788ad798fb3aef5f334
Block 15 "2688762522" "if (((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 188"
// ANALYSIS CANDIDATE IDS: W-421b52ed6d8e9279fa9f
// RAW BIN IDS: 421b52ed6d8e9279fa9f
Block 16 "2928090559" "result.clamp_positive = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 189"
// ANALYSIS CANDIDATE IDS: W-bb469cc42312fb31b5e6
// RAW BIN IDS: bb469cc42312fb31b5e6
Block 18 "2067348821" "if (((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 190"
// ANALYSIS CANDIDATE IDS: W-b5827eddbde5473e62fa
// RAW BIN IDS: b5827eddbde5473e62fa
Block 19 "2096939491" "result.clamp_negative = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 191"
// ANALYSIS CANDIDATE IDS: W-3ce33116eb059bf50aa9
// RAW BIN IDS: 3ce33116eb059bf50aa9
Block 21 "1987362058" "ef2_pair_lookahead = result;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 196"
// Block 22 "3465493753" "work_err1_i = err1_i_q;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 232"
// Block 23 "1348277332" "for (lane = 0; (lane < CHANNELS); lane = (lane + 2))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 233"
// Block 24 "3373271100" "pair_i = ef2_pair_lookahead(in_i_poly_vec[(lane * W)+:W], in_i_poly_vec[((lane + 1) * W)+:W], work_err1_i, work_err2_i);"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 240"
// Block 25 "1569554602" "arithmetic_no_wrap_comb = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 241"
// Block 27 "1798126418" "if (((!pair_i.in_bounds) || (!pair_q.in_bounds)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 242"
// Block 28 "798455005" "arithmetic_bounds_comb = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 243"
// Block 30 "3374411478" "if ((pair_i.clamp_positive || pair_q.clamp_positive))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 244"
// Block 31 "532586829" "clamp_positive_comb = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 245"
// Block 33 "1302622107" "if ((pair_i.clamp_negative || pair_q.clamp_negative))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 246"
// Block 34 "3113880436" "clamp_negative_comb = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 249"
// Block 36 "1801196460" "raw_word_comb[(2 * lane)] = pair_i.q0_positive;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 259"
// Block 37 "2725469672" "for (lane = 0; (lane < CHANNELS); lane = (lane + 1))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 260"
// Block 38 "924583898" "x_i_wide = {{(ACC_W - W) {in_i_poly_vec[(((lane * W) + W) - 1)]}}, in_i_poly_vec[(lane * W)+:W]};"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 290"
// Block 39 "2530053887" "arithmetic_bounds_comb = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 292"
// Block 41 "3213577612" "y_i_positive = (u_i > 0);"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 300"
// Block 42 "844472052" "arithmetic_no_wrap_comb = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 301"
// Block 44 "1128344301" "if (((e_i_raw > STATE_MAX) || (e_q_raw > STATE_MAX)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 302"
// Block 45 "1595302431" "clamp_positive_comb = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 303"
// Block 47 "307680839" "if (((e_i_raw < STATE_MIN) || (e_q_raw < STATE_MIN)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 304"
// Block 48 "1827407716" "clamp_negative_comb = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 307"
// Block 50 "4262396638" "if (((lane % 2) == 0))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 308"
// Block 51 "340702176" "raw_word_comb[(2 * lane)] = y_i_positive;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 311"
// Block 52 "1683336911" "raw_word_comb[(2 * lane)] = (!y_i_positive);"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 315"
// Block 53 "2603064589" "work_err2_i = work_err1_i;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 322"
// Block 54 "3848387695" "err1_i_next = work_err1_i;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 332"
// Block 55 "1335899302" "if ((!rst_n))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 333"
// Block 56 "1109412139" "err1_i_q <= '0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 339"
// Block 57 "1164260594" "if (tid_ready)"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 340"
// Block 58 "2261620474" "tid_valid_q <= accept_word;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 342"
// Block 59 "604718672" "err1_i_q <= err1_i_next;"



CHECKSUM: "1491642939 3816297385"
//
ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[3].g_order2.u_tid
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 96"
// Block 1 "4179345703" "if ((((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 97"
// Block 2 "1438331943" "$error(\"EF2 TID requires W >= 2 and an even CHANNELS >= 2\");"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 104"
// Block 4 "1253481452" "if ((value > STATE_MAX))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 105"
// Block 5 "3204619702" "sat_error = STATE_MAX[(STATE_W - 1):0];"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 106"
// Block 6 "1460796149" "if ((value < STATE_MIN))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 107"
// Block 7 "821581261" "sat_error = STATE_MIN[(STATE_W - 1):0];"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 109"
// Block 8 "869581897" "sat_error = value[(STATE_W - 1):0];"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 135"
// ANALYSIS CANDIDATE IDS: W-80998368f07359600a84,W-96f2d0034ed51c250d83,W-cda883afe234e8f822a3,W-eed94a8668502bd855de,W-c6e6863b80ea6144953b,W-65133d2a2412f073a55f,W-0e4e61eade6d5fc8f778,W-4429ba1b6df975d84eee,W-bd49225411e046dfaf4e,W-74b29699001fa5fcaae5,W-2dc1ed313e9c91659f08,W-7d0be07beccceebe5e6e,W-3ee08b65e0330090e26b,W-7715dd9499f7cd42aa9e,W-f598e593057ab744c462,W-27032a5628d59311b90f,W-e1850fe459283d93759d,W-ef89c0d0bd0df8676384,W-745a30920dc647d90486,W-3f393872b97a7f048840,W-f1b587a3cdfff4004602,W-89e891414f18f74138ea,W-b82c1607c70f32ad723b,W-49aa2cbab1132b04cf9c,W-d5222a0dff5bbc10059c,W-3885a36cf695f9b81d31,W-59585c7a23b6b6f1bf81,W-f02ff52e3f8ce04329f7,W-bfa2e332f8808dce21c0,W-10b2b030970d4ec1813e
// RAW BIN IDS: 80998368f07359600a84,96f2d0034ed51c250d83,cda883afe234e8f822a3,eed94a8668502bd855de,c6e6863b80ea6144953b,65133d2a2412f073a55f,0e4e61eade6d5fc8f778,4429ba1b6df975d84eee,bd49225411e046dfaf4e,74b29699001fa5fcaae5,2dc1ed313e9c91659f08,7d0be07beccceebe5e6e,3ee08b65e0330090e26b,7715dd9499f7cd42aa9e,f598e593057ab744c462,27032a5628d59311b90f,e1850fe459283d93759d,ef89c0d0bd0df8676384,745a30920dc647d90486,3f393872b97a7f048840,f1b587a3cdfff4004602,89e891414f18f74138ea,b82c1607c70f32ad723b,49aa2cbab1132b04cf9c,d5222a0dff5bbc10059c,3885a36cf695f9b81d31,59585c7a23b6b6f1bf81,f02ff52e3f8ce04329f7,bfa2e332f8808dce21c0,10b2b030970d4ec1813e
Block 9 "2541824417" "result = '0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 179"
// ANALYSIS CANDIDATE IDS: W-1d75f3c484b3f6f4fcc1
// RAW BIN IDS: 1d75f3c484b3f6f4fcc1
Block 10 "1823560241" "result.no_wrap = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 180"
// ANALYSIS CANDIDATE IDS: W-bd0b6e2bf89ada85c584
// RAW BIN IDS: bd0b6e2bf89ada85c584
Block 12 "3963672532" "if (((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 186"
// ANALYSIS CANDIDATE IDS: W-6f8378c05c44a96e196d
// RAW BIN IDS: 6f8378c05c44a96e196d
Block 13 "166068688" "result.in_bounds = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 187"
// ANALYSIS CANDIDATE IDS: W-c54891de967ce10b2267
// RAW BIN IDS: c54891de967ce10b2267
Block 15 "2688762522" "if (((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 188"
// ANALYSIS CANDIDATE IDS: W-853c2361787e0620922a
// RAW BIN IDS: 853c2361787e0620922a
Block 16 "2928090559" "result.clamp_positive = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 189"
// ANALYSIS CANDIDATE IDS: W-4ff274ec0f33243cad22
// RAW BIN IDS: 4ff274ec0f33243cad22
Block 18 "2067348821" "if (((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 190"
// ANALYSIS CANDIDATE IDS: W-31551c438f3473e52403
// RAW BIN IDS: 31551c438f3473e52403
Block 19 "2096939491" "result.clamp_negative = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 191"
// ANALYSIS CANDIDATE IDS: W-e019893668b0d407016d
// RAW BIN IDS: e019893668b0d407016d
Block 21 "1987362058" "ef2_pair_lookahead = result;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 196"
// Block 22 "3465493753" "work_err1_i = err1_i_q;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 232"
// Block 23 "1348277332" "for (lane = 0; (lane < CHANNELS); lane = (lane + 2))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 233"
// Block 24 "3373271100" "pair_i = ef2_pair_lookahead(in_i_poly_vec[(lane * W)+:W], in_i_poly_vec[((lane + 1) * W)+:W], work_err1_i, work_err2_i);"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 240"
// Block 25 "1569554602" "arithmetic_no_wrap_comb = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 241"
// Block 27 "1798126418" "if (((!pair_i.in_bounds) || (!pair_q.in_bounds)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 242"
// Block 28 "798455005" "arithmetic_bounds_comb = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 243"
// Block 30 "3374411478" "if ((pair_i.clamp_positive || pair_q.clamp_positive))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 244"
// Block 31 "532586829" "clamp_positive_comb = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 245"
// Block 33 "1302622107" "if ((pair_i.clamp_negative || pair_q.clamp_negative))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 246"
// Block 34 "3113880436" "clamp_negative_comb = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 249"
// Block 36 "1801196460" "raw_word_comb[(2 * lane)] = pair_i.q0_positive;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 259"
// Block 37 "2725469672" "for (lane = 0; (lane < CHANNELS); lane = (lane + 1))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 260"
// Block 38 "924583898" "x_i_wide = {{(ACC_W - W) {in_i_poly_vec[(((lane * W) + W) - 1)]}}, in_i_poly_vec[(lane * W)+:W]};"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 290"
// Block 39 "2530053887" "arithmetic_bounds_comb = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 292"
// Block 41 "3213577612" "y_i_positive = (u_i > 0);"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 300"
// Block 42 "844472052" "arithmetic_no_wrap_comb = 1'b0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 301"
// Block 44 "1128344301" "if (((e_i_raw > STATE_MAX) || (e_q_raw > STATE_MAX)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 302"
// Block 45 "1595302431" "clamp_positive_comb = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 303"
// Block 47 "307680839" "if (((e_i_raw < STATE_MIN) || (e_q_raw < STATE_MIN)))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 304"
// Block 48 "1827407716" "clamp_negative_comb = 1'b1;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 307"
// Block 50 "4262396638" "if (((lane % 2) == 0))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 308"
// Block 51 "340702176" "raw_word_comb[(2 * lane)] = y_i_positive;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 311"
// Block 52 "1683336911" "raw_word_comb[(2 * lane)] = (!y_i_positive);"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 315"
// Block 53 "2603064589" "work_err2_i = work_err1_i;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 322"
// Block 54 "3848387695" "err1_i_next = work_err1_i;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 332"
// Block 55 "1335899302" "if ((!rst_n))"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 333"
// Block 56 "1109412139" "err1_i_q <= '0;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 339"
// Block 57 "1164260594" "if (tid_ready)"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 340"
// Block 58 "2261620474" "tid_valid_q <= accept_word;"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 342"
// Block 59 "604718672" "err1_i_q <= err1_i_next;"



CHECKSUM: "2611591664 791396721"
//
ANNOTATION: "ModuleName: dsm_interp_x2_centered_cubic_vector"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 129"
// Branch 0 "3836088345" "tail_output"
// Branch 0 "3836088345" "tail_output" (0) "tail_output 1,-"
// Branch 0 "3836088345" "tail_output" (1) "tail_output 0,1"
// Branch 0 "3836088345" "tail_output" (2) "tail_output 0,0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 182"
// Branch 1 "2959318469" "(!rst_n)"
// Branch 1 "2959318469" "(!rst_n)" (0) "(!rst_n) 1,-,-,-,-,-,-,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (1) "(!rst_n) 0,1,1,-,-,-,-,-,-,-,-,-,-"
// ANALYSIS CANDIDATE IDS: W-1e23fb57b68ef73f6869
// RAW BIN IDS: 1e23fb57b68ef73f6869
Branch 1 "2959318469" "(!rst_n)" (2) "(!rst_n) 0,1,0,-,-,-,-,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (3) "(!rst_n) 0,0,-,1,-,-,-,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (4) "(!rst_n) 0,0,-,0,-,-,-,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (5) "(!rst_n) 0,0,-,-,1,1,-,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (6) "(!rst_n) 0,0,-,-,1,0,-,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (7) "(!rst_n) 0,0,-,-,0,-,-,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (8) "(!rst_n) 0,0,-,-,-,-,1,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (9) "(!rst_n) 0,0,-,-,-,-,0,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (10) "(!rst_n) 0,0,-,-,-,-,-,1,1,1,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (11) "(!rst_n) 0,0,-,-,-,-,-,1,1,0,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (12) "(!rst_n) 0,0,-,-,-,-,-,1,0,-,1,-,-"
// Branch 1 "2959318469" "(!rst_n)" (13) "(!rst_n) 0,0,-,-,-,-,-,1,0,-,0,-,-"
// Branch 1 "2959318469" "(!rst_n)" (14) "(!rst_n) 0,0,-,-,-,-,-,0,-,-,-,1,1"
// Branch 1 "2959318469" "(!rst_n)" (15) "(!rst_n) 0,0,-,-,-,-,-,0,-,-,-,1,0"
// Branch 1 "2959318469" "(!rst_n)" (16) "(!rst_n) 0,0,-,-,-,-,-,0,-,-,-,0,-"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 294"
// Branch 2 "3213471300" "(LANES < 2)"
// ANALYSIS CANDIDATE IDS: W-f29c82353225befff4b5
// RAW BIN IDS: f29c82353225befff4b5
Branch 2 "3213471300" "(LANES < 2)" (0) "(LANES < 2) 1"
// Branch 2 "3213471300" "(LANES < 2)" (1) "(LANES < 2) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 295"
// Branch 3 "2475905803" "(COEFF_FRAC != 14)"
// ANALYSIS CANDIDATE IDS: W-6ea4d75eea9e8e7b03d4
// RAW BIN IDS: 6ea4d75eea9e8e7b03d4
Branch 3 "2475905803" "(COEFF_FRAC != 14)" (0) "(COEFF_FRAC != 14) 1"
// Branch 3 "2475905803" "(COEFF_FRAC != 14)" (1) "(COEFF_FRAC != 14) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 299"
// Branch 4 "152886533" "(!rst_n)"
// Branch 4 "152886533" "(!rst_n)" (0) "(!rst_n) 1"
// Branch 4 "152886533" "(!rst_n)" (1) "(!rst_n) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 304"
// Branch 5 "3770649421" "(rst_n && stalled_last)"
// Branch 5 "3770649421" "(rst_n && stalled_last)" (0) "(rst_n && stalled_last) 1"
// Branch 5 "3770649421" "(rst_n && stalled_last)" (1) "(rst_n && stalled_last) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 309"
// Branch 6 "1089443295" "(((rst_n && (q_count == 2'h2)) && q0_end) && (!q1_start))"
// Branch 6 "1089443295" "(((rst_n && (q_count == 2'h2)) && q0_end) && (!q1_start))" (0) "(((rst_n && (q_count == 2'h2)) && q0_end) && (!q1_start)) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 95"
// Branch 7 "190082960" "(value >= 0)"
// Branch 7 "190082960" "(value >= 0)" (0) "(value >= 0) 1"
// Branch 7 "190082960" "(value >= 0)" (1) "(value >= 0) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 101"
// Branch 8 "2420014021" "(rounded > maxv)"
// Branch 8 "2420014021" "(rounded > maxv)" (0) "(rounded > maxv) 1,-"
// Branch 8 "2420014021" "(rounded > maxv)" (1) "(rounded > maxv) 0,1"
// Branch 8 "2420014021" "(rounded > maxv)" (2) "(rounded > maxv) 0,0"



CHECKSUM: "2611591664 791396721"
//
ANNOTATION: "ModuleName: dsm_interp_x2_centered_cubic_vector"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 129"
// Branch 0 "3836088345" "tail_output"
// Branch 0 "3836088345" "tail_output" (0) "tail_output 1,-"
// Branch 0 "3836088345" "tail_output" (1) "tail_output 0,1"
// Branch 0 "3836088345" "tail_output" (2) "tail_output 0,0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 182"
// Branch 1 "2959318469" "(!rst_n)"
// Branch 1 "2959318469" "(!rst_n)" (0) "(!rst_n) 1,-,-,-,-,-,-,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (1) "(!rst_n) 0,1,1,-,-,-,-,-,-,-,-,-,-"
// ANALYSIS CANDIDATE IDS: W-1129900cf23695da581a
// RAW BIN IDS: 1129900cf23695da581a
Branch 1 "2959318469" "(!rst_n)" (2) "(!rst_n) 0,1,0,-,-,-,-,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (3) "(!rst_n) 0,0,-,1,-,-,-,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (4) "(!rst_n) 0,0,-,0,-,-,-,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (5) "(!rst_n) 0,0,-,-,1,1,-,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (6) "(!rst_n) 0,0,-,-,1,0,-,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (7) "(!rst_n) 0,0,-,-,0,-,-,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (8) "(!rst_n) 0,0,-,-,-,-,1,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (9) "(!rst_n) 0,0,-,-,-,-,0,-,-,-,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (10) "(!rst_n) 0,0,-,-,-,-,-,1,1,1,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (11) "(!rst_n) 0,0,-,-,-,-,-,1,1,0,-,-,-"
// Branch 1 "2959318469" "(!rst_n)" (12) "(!rst_n) 0,0,-,-,-,-,-,1,0,-,1,-,-"
// Branch 1 "2959318469" "(!rst_n)" (13) "(!rst_n) 0,0,-,-,-,-,-,1,0,-,0,-,-"
// Branch 1 "2959318469" "(!rst_n)" (14) "(!rst_n) 0,0,-,-,-,-,-,0,-,-,-,1,1"
// Branch 1 "2959318469" "(!rst_n)" (15) "(!rst_n) 0,0,-,-,-,-,-,0,-,-,-,1,0"
// Branch 1 "2959318469" "(!rst_n)" (16) "(!rst_n) 0,0,-,-,-,-,-,0,-,-,-,0,-"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 294"
// Branch 2 "3213471300" "(LANES < 2)"
// ANALYSIS CANDIDATE IDS: W-1c0b1f94a32c4fa9e2c2
// RAW BIN IDS: 1c0b1f94a32c4fa9e2c2
Branch 2 "3213471300" "(LANES < 2)" (0) "(LANES < 2) 1"
// Branch 2 "3213471300" "(LANES < 2)" (1) "(LANES < 2) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 295"
// Branch 3 "2475905803" "(COEFF_FRAC != 14)"
// ANALYSIS CANDIDATE IDS: W-bd2f276b5a949e6e4eb8
// RAW BIN IDS: bd2f276b5a949e6e4eb8
Branch 3 "2475905803" "(COEFF_FRAC != 14)" (0) "(COEFF_FRAC != 14) 1"
// Branch 3 "2475905803" "(COEFF_FRAC != 14)" (1) "(COEFF_FRAC != 14) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 299"
// Branch 4 "152886533" "(!rst_n)"
// Branch 4 "152886533" "(!rst_n)" (0) "(!rst_n) 1"
// Branch 4 "152886533" "(!rst_n)" (1) "(!rst_n) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 304"
// Branch 5 "3770649421" "(rst_n && stalled_last)"
// Branch 5 "3770649421" "(rst_n && stalled_last)" (0) "(rst_n && stalled_last) 1"
// Branch 5 "3770649421" "(rst_n && stalled_last)" (1) "(rst_n && stalled_last) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 309"
// Branch 6 "1089443295" "(((rst_n && (q_count == 2'h2)) && q0_end) && (!q1_start))"
// Branch 6 "1089443295" "(((rst_n && (q_count == 2'h2)) && q0_end) && (!q1_start))" (0) "(((rst_n && (q_count == 2'h2)) && q0_end) && (!q1_start)) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 95"
// Branch 7 "190082960" "(value >= 0)"
// Branch 7 "190082960" "(value >= 0)" (0) "(value >= 0) 1"
// Branch 7 "190082960" "(value >= 0)" (1) "(value >= 0) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv, LineNumber: 101"
// Branch 8 "2420014021" "(rounded > maxv)"
// Branch 8 "2420014021" "(rounded > maxv)" (0) "(rounded > maxv) 1,-"
// Branch 8 "2420014021" "(rounded > maxv)" (1) "(rounded > maxv) 0,1"
// Branch 8 "2420014021" "(rounded > maxv)" (2) "(rounded > maxv) 0,0"



CHECKSUM: "2176286378 461185685"
//
ANNOTATION: "ModuleName: dsm_frame_gain_vector"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_frame_gain
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/frontend/dsm_frame_gain_vector.sv, LineNumber: 71"
// Branch 0 "2242509409" "(!rst_n)"
// Branch 0 "2242509409" "(!rst_n)" (0) "(!rst_n) 1,-,-,-,-,-,-,-,-,-,-"
// Branch 0 "2242509409" "(!rst_n)" (1) "(!rst_n) 0,1,1,-,-,-,-,-,-,-,-"
// ANALYSIS CANDIDATE IDS: W-48945012f702b0a23803
// RAW BIN IDS: 48945012f702b0a23803
Branch 0 "2242509409" "(!rst_n)" (2) "(!rst_n) 0,1,0,-,-,-,-,-,-,-,-"
// Branch 0 "2242509409" "(!rst_n)" (3) "(!rst_n) 0,0,-,1,1,-,-,-,-,-,-"
// Branch 0 "2242509409" "(!rst_n)" (4) "(!rst_n) 0,0,-,1,0,-,-,-,-,-,-"
// Branch 0 "2242509409" "(!rst_n)" (5) "(!rst_n) 0,0,-,0,-,-,-,-,-,-,-"
// Branch 0 "2242509409" "(!rst_n)" (6) "(!rst_n) 0,0,-,-,-,1,1,-,-,-,-"
// Branch 0 "2242509409" "(!rst_n)" (7) "(!rst_n) 0,0,-,-,-,1,0,-,-,-,-"
// Branch 0 "2242509409" "(!rst_n)" (8) "(!rst_n) 0,0,-,-,-,0,-,-,-,-,-"
// Branch 0 "2242509409" "(!rst_n)" (9) "(!rst_n) 0,0,-,-,-,-,-,1,1,1,-"
// Branch 0 "2242509409" "(!rst_n)" (10) "(!rst_n) 0,0,-,-,-,-,-,1,1,0,-"
// Branch 0 "2242509409" "(!rst_n)" (11) "(!rst_n) 0,0,-,-,-,-,-,1,1,-,1"
// Branch 0 "2242509409" "(!rst_n)" (12) "(!rst_n) 0,0,-,-,-,-,-,1,1,-,0"
// Branch 0 "2242509409" "(!rst_n)" (13) "(!rst_n) 0,0,-,-,-,-,-,1,0,-,-"
// Branch 0 "2242509409" "(!rst_n)" (14) "(!rst_n) 0,0,-,-,-,-,-,0,-,-,-"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/frontend/dsm_frame_gain_vector.sv, LineNumber: 58"
// Branch 1 "190082960" "(value >= 0)"
// Branch 1 "190082960" "(value >= 0)" (0) "(value >= 0) 1"
// Branch 1 "190082960" "(value >= 0)" (1) "(value >= 0) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/frontend/dsm_frame_gain_vector.sv, LineNumber: 64"
// Branch 2 "2420014021" "(rounded > maxv)"
// Branch 2 "2420014021" "(rounded > maxv)" (0) "(rounded > maxv) 1,-"
// Branch 2 "2420014021" "(rounded > maxv)" (1) "(rounded > maxv) 0,1"
// Branch 2 "2420014021" "(rounded > maxv)" (2) "(rounded > maxv) 0,0"



CHECKSUM: "2408948792 3072091210"
//
ANNOTATION: "ModuleName: gt_tx_user_bridge"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[0].g_order2.u_tid.u_raw_boundary.u_bridge
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/gt/gt_tx_user_bridge.sv, LineNumber: 20"
// Branch 0 "3365410206" "(PARALLEL_W != GT_USER_W)"
// ANALYSIS CANDIDATE IDS: W-53f7fbb7804e68b87be5
// RAW BIN IDS: 53f7fbb7804e68b87be5
Branch 0 "3365410206" "(PARALLEL_W != GT_USER_W)" (0) "(PARALLEL_W != GT_USER_W) 1"
// Branch 0 "3365410206" "(PARALLEL_W != GT_USER_W)" (1) "(PARALLEL_W != GT_USER_W) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/gt/gt_tx_user_bridge.sv, LineNumber: 27"
// Branch 1 "3305092395" "(!rst_n)"
// Branch 1 "3305092395" "(!rst_n)" (0) "(!rst_n) 1,-,-"
// Branch 1 "3305092395" "(!rst_n)" (1) "(!rst_n) 0,1,1"
// Branch 1 "3305092395" "(!rst_n)" (2) "(!rst_n) 0,1,0"
// Branch 1 "3305092395" "(!rst_n)" (3) "(!rst_n) 0,0,-"



CHECKSUM: "2408948792 3072091210"
//
ANNOTATION: "ModuleName: gt_tx_user_bridge"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[1].g_order2.u_tid.u_raw_boundary.u_bridge
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/gt/gt_tx_user_bridge.sv, LineNumber: 20"
// Branch 0 "3365410206" "(PARALLEL_W != GT_USER_W)"
// ANALYSIS CANDIDATE IDS: W-d2b1f8b685f9c5174d22
// RAW BIN IDS: d2b1f8b685f9c5174d22
Branch 0 "3365410206" "(PARALLEL_W != GT_USER_W)" (0) "(PARALLEL_W != GT_USER_W) 1"
// Branch 0 "3365410206" "(PARALLEL_W != GT_USER_W)" (1) "(PARALLEL_W != GT_USER_W) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/gt/gt_tx_user_bridge.sv, LineNumber: 27"
// Branch 1 "3305092395" "(!rst_n)"
// Branch 1 "3305092395" "(!rst_n)" (0) "(!rst_n) 1,-,-"
// Branch 1 "3305092395" "(!rst_n)" (1) "(!rst_n) 0,1,1"
// Branch 1 "3305092395" "(!rst_n)" (2) "(!rst_n) 0,1,0"
// Branch 1 "3305092395" "(!rst_n)" (3) "(!rst_n) 0,0,-"



CHECKSUM: "2408948792 3072091210"
//
ANNOTATION: "ModuleName: gt_tx_user_bridge"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[2].g_order2.u_tid.u_raw_boundary.u_bridge
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/gt/gt_tx_user_bridge.sv, LineNumber: 20"
// Branch 0 "3365410206" "(PARALLEL_W != GT_USER_W)"
// ANALYSIS CANDIDATE IDS: W-32b2ff5223cbb168fc4e
// RAW BIN IDS: 32b2ff5223cbb168fc4e
Branch 0 "3365410206" "(PARALLEL_W != GT_USER_W)" (0) "(PARALLEL_W != GT_USER_W) 1"
// Branch 0 "3365410206" "(PARALLEL_W != GT_USER_W)" (1) "(PARALLEL_W != GT_USER_W) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/gt/gt_tx_user_bridge.sv, LineNumber: 27"
// Branch 1 "3305092395" "(!rst_n)"
// Branch 1 "3305092395" "(!rst_n)" (0) "(!rst_n) 1,-,-"
// Branch 1 "3305092395" "(!rst_n)" (1) "(!rst_n) 0,1,1"
// Branch 1 "3305092395" "(!rst_n)" (2) "(!rst_n) 0,1,0"
// Branch 1 "3305092395" "(!rst_n)" (3) "(!rst_n) 0,0,-"



CHECKSUM: "2408948792 3072091210"
//
ANNOTATION: "ModuleName: gt_tx_user_bridge"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[3].g_order2.u_tid.u_raw_boundary.u_bridge
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/gt/gt_tx_user_bridge.sv, LineNumber: 20"
// Branch 0 "3365410206" "(PARALLEL_W != GT_USER_W)"
// ANALYSIS CANDIDATE IDS: W-e71c2cbf3b0b6116ef2e
// RAW BIN IDS: e71c2cbf3b0b6116ef2e
Branch 0 "3365410206" "(PARALLEL_W != GT_USER_W)" (0) "(PARALLEL_W != GT_USER_W) 1"
// Branch 0 "3365410206" "(PARALLEL_W != GT_USER_W)" (1) "(PARALLEL_W != GT_USER_W) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/gt/gt_tx_user_bridge.sv, LineNumber: 27"
// Branch 1 "3305092395" "(!rst_n)"
// Branch 1 "3305092395" "(!rst_n)" (0) "(!rst_n) 1,-,-"
// Branch 1 "3305092395" "(!rst_n)" (1) "(!rst_n) 0,1,1"
// Branch 1 "3305092395" "(!rst_n)" (2) "(!rst_n) 0,1,0"
// Branch 1 "3305092395" "(!rst_n)" (3) "(!rst_n) 0,0,-"



CHECKSUM: "2004831198 3139732564"
//
ANNOTATION: "ModuleName: thermo5_dpd_axi_lite_cfg"
INSTANCE: thermo5_sku_uvm_tb.dut.u_cfg
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv, LineNumber: 90"
// Branch 0 "1198758961" "aw_pending"
// Branch 0 "1198758961" "aw_pending" (0) "aw_pending 1"
// Branch 0 "1198758961" "aw_pending" (1) "aw_pending 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv, LineNumber: 91"
// Branch 1 "4162794519" "w_pending"
// Branch 1 "4162794519" "w_pending" (0) "w_pending 1"
// Branch 1 "4162794519" "w_pending" (1) "w_pending 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv, LineNumber: 92"
// Branch 2 "4162794519" "w_pending"
// Branch 2 "4162794519" "w_pending" (0) "w_pending 1"
// Branch 2 "4162794519" "w_pending" (1) "w_pending 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv, LineNumber: 150"
// Branch 3 "1985417307" "(write_addr == REG_CONTROL)"
// Branch 3 "1985417307" "(write_addr == REG_CONTROL)" (0) "(write_addr == REG_CONTROL) 1,1,-"
// Branch 3 "1985417307" "(write_addr == REG_CONTROL)" (1) "(write_addr == REG_CONTROL) 1,0,-"
// Branch 3 "1985417307" "(write_addr == REG_CONTROL)" (2) "(write_addr == REG_CONTROL) 0,-,1"
// Branch 3 "1985417307" "(write_addr == REG_CONTROL)" (3) "(write_addr == REG_CONTROL) 0,-,0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv, LineNumber: 165"
// Branch 4 "81768304" "s_axil_araddr"
// Branch 4 "81768304" "s_axil_araddr" (0) "s_axil_araddr REG_CONTROL ,-"
// Branch 4 "81768304" "s_axil_araddr" (1) "s_axil_araddr REG_STATUS ,-"
// Branch 4 "81768304" "s_axil_araddr" (2) "s_axil_araddr REG_TAPS ,-"
// Branch 4 "81768304" "s_axil_araddr" (3) "s_axil_araddr REG_ID ,-"
// Branch 4 "81768304" "s_axil_araddr" (4) "s_axil_araddr default,1"
// Branch 4 "81768304" "s_axil_araddr" (5) "s_axil_araddr default,0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv, LineNumber: 190"
// Branch 5 "277962118" "(!s_axil_aresetn)"
// Branch 5 "277962118" "(!s_axil_aresetn)" (0) "(!s_axil_aresetn) 1,-,-,-,-,-,-,-,-,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (1) "(!s_axil_aresetn) 0,1,-,-,-,-,-,-,-,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (2) "(!s_axil_aresetn) 0,0,-,-,-,-,-,-,-,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (3) "(!s_axil_aresetn) 0,-,1,-,-,-,-,-,-,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (4) "(!s_axil_aresetn) 0,-,0,-,-,-,-,-,-,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (5) "(!s_axil_aresetn) 0,-,-,1,-,-,-,-,-,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (6) "(!s_axil_aresetn) 0,-,-,0,-,-,-,-,-,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (7) "(!s_axil_aresetn) 0,-,-,-,1,-,-,-,-,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (8) "(!s_axil_aresetn) 0,-,-,-,0,-,-,-,-,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (9) "(!s_axil_aresetn) 0,-,-,-,-,1,1,1,-,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (10) "(!s_axil_aresetn) 0,-,-,-,-,1,1,0,-,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (11) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,REG_CONTROL ,1,1,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (12) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,REG_CONTROL ,1,0,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (13) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,REG_CONTROL ,0,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (14) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,REG_STATUS ,-,-,1,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (15) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,REG_STATUS ,-,-,0,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (16) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,REG_STATUS ,-,-,-,1,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (17) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,REG_STATUS ,-,-,-,0,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (18) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,REG_TAPS ,-,-,-,-,1,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (19) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,REG_TAPS ,-,-,-,-,0,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (20) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,REG_C1_RE ,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (21) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,(REG_C1_RE + 8'h04) ,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (22) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,REG_C1_IM ,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (23) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,(REG_C1_IM + 8'h04) ,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (24) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,REG_C3_RE ,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (25) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,(REG_C3_RE + 8'h04) ,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (26) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,REG_C3_IM ,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (27) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,(REG_C3_IM + 8'h04) ,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (28) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,REG_C5_RE ,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (29) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,(REG_C5_RE + 8'h04) ,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (30) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,REG_C5_IM ,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (31) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,(REG_C5_IM + 8'h04) ,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (32) "(!s_axil_aresetn) 0,-,-,-,-,1,0,-,default,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (33) "(!s_axil_aresetn) 0,-,-,-,-,0,-,-,-,-,-,-,-,-,-,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (34) "(!s_axil_aresetn) 0,-,-,-,-,-,-,-,-,-,-,-,-,-,1,1,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (35) "(!s_axil_aresetn) 0,-,-,-,-,-,-,-,-,-,-,-,-,-,1,0,1,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (36) "(!s_axil_aresetn) 0,-,-,-,-,-,-,-,-,-,-,-,-,-,1,0,0,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (37) "(!s_axil_aresetn) 0,-,-,-,-,-,-,-,-,-,-,-,-,-,0,-,-,-"
// Branch 5 "277962118" "(!s_axil_aresetn)" (38) "(!s_axil_aresetn) 0,-,-,-,-,-,-,-,-,-,-,-,-,-,-,-,-,1"
// Branch 5 "277962118" "(!s_axil_aresetn)" (39) "(!s_axil_aresetn) 0,-,-,-,-,-,-,-,-,-,-,-,-,-,-,-,-,0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv, LineNumber: 310"
// Branch 6 "3385514408" "(!core_aresetn)"
// Branch 6 "3385514408" "(!core_aresetn)" (0) "(!core_aresetn) 1,-,-,-"
// Branch 6 "3385514408" "(!core_aresetn)" (1) "(!core_aresetn) 0,1,-,-"
// Branch 6 "3385514408" "(!core_aresetn)" (2) "(!core_aresetn) 0,0,1,-"
// Branch 6 "3385514408" "(!core_aresetn)" (3) "(!core_aresetn) 0,0,0,-"
// Branch 6 "3385514408" "(!core_aresetn)" (4) "(!core_aresetn) 0,-,-,1"
// Branch 6 "3385514408" "(!core_aresetn)" (5) "(!core_aresetn) 0,-,-,0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv, LineNumber: 342"
// Branch 7 "2935330723" "(cfg_pending_valid && dpd_config_boundary)"
// Branch 7 "2935330723" "(cfg_pending_valid && dpd_config_boundary)" (0) "(cfg_pending_valid && dpd_config_boundary) 1"
// Branch 7 "2935330723" "(cfg_pending_valid && dpd_config_boundary)" (1) "(cfg_pending_valid && dpd_config_boundary) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv, LineNumber: 348"
// Branch 8 "2041485635" "((MAX_TAPS < 1) || (MAX_TAPS > 4))"
// ANALYSIS CANDIDATE IDS: W-c6d4d2a2eb158a301df7
// RAW BIN IDS: c6d4d2a2eb158a301df7
Branch 8 "2041485635" "((MAX_TAPS < 1) || (MAX_TAPS > 4))" (0) "((MAX_TAPS < 1) || (MAX_TAPS > 4)) 1"
// Branch 8 "2041485635" "((MAX_TAPS < 1) || (MAX_TAPS > 4))" (1) "((MAX_TAPS < 1) || (MAX_TAPS > 4)) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv, LineNumber: 357"
// Branch 9 "179740297" "(!s_axil_aresetn)"
// Branch 9 "179740297" "(!s_axil_aresetn)" (0) "(!s_axil_aresetn) 1,-,-,-"
// Branch 9 "179740297" "(!s_axil_aresetn)" (1) "(!s_axil_aresetn) 0,1,-,-"
// Branch 9 "179740297" "(!s_axil_aresetn)" (2) "(!s_axil_aresetn) 0,0,1,-"
// Branch 9 "179740297" "(!s_axil_aresetn)" (3) "(!s_axil_aresetn) 0,0,0,1"
// Branch 9 "179740297" "(!s_axil_aresetn)" (4) "(!s_axil_aresetn) 0,0,0,0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv, LineNumber: 124"
// Branch 10 "1367136597" "addr"
// Branch 10 "1367136597" "addr" (0) "addr CASEITEM-1: 8'h10 8'h14 8'h18 8'h1c 8'h20 8'h24 8'h28 8'h2c 8'h30 8'h34 8'h38 8'h3c "
// Branch 10 "1367136597" "addr" (1) "addr default"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv, LineNumber: 135"
// Branch 11 "1439685947" "(addr & 8'hf8)"
// Branch 11 "1439685947" "(addr & 8'hf8)" (0) "(addr & 8'hf8) REG_C1_RE "
// Branch 11 "1439685947" "(addr & 8'hf8)" (1) "(addr & 8'hf8) REG_C1_IM "
// Branch 11 "1439685947" "(addr & 8'hf8)" (2) "(addr & 8'hf8) REG_C3_RE "
// Branch 11 "1439685947" "(addr & 8'hf8)" (3) "(addr & 8'hf8) REG_C3_IM "
// Branch 11 "1439685947" "(addr & 8'hf8)" (4) "(addr & 8'hf8) REG_C5_RE "
// Branch 11 "1439685947" "(addr & 8'hf8)" (5) "(addr & 8'hf8) REG_C5_IM "
// Branch 11 "1439685947" "(addr & 8'hf8)" (6) "(addr & 8'hf8) default"



CHECKSUM: "1491642939 4234966567"
//
ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[0].g_order2.u_tid
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 96"
// Branch 0 "1027625233" "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0))"
// ANALYSIS CANDIDATE IDS: W-fe314fbdc83c1d9d1546
// RAW BIN IDS: fe314fbdc83c1d9d1546
Branch 0 "1027625233" "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0))" (0) "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0)) 1"
// Branch 0 "1027625233" "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0))" (1) "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0)) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 231"
// Branch 1 "4262564349" "PAIR_LOOKAHEAD"
// ANALYSIS CANDIDATE IDS: W-8352e31d27f3b7336db2
// RAW BIN IDS: 8352e31d27f3b7336db2
Branch 1 "4262564349" "PAIR_LOOKAHEAD" (0) "PAIR_LOOKAHEAD 1"
// Branch 1 "4262564349" "PAIR_LOOKAHEAD" (1) "PAIR_LOOKAHEAD 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 332"
// Branch 2 "3880551804" "(!rst_n)"
// Branch 2 "3880551804" "(!rst_n)" (0) "(!rst_n) 1,-,-"
// Branch 2 "3880551804" "(!rst_n)" (1) "(!rst_n) 0,1,1"
// Branch 2 "3880551804" "(!rst_n)" (2) "(!rst_n) 0,1,0"
// Branch 2 "3880551804" "(!rst_n)" (3) "(!rst_n) 0,0,-"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 104"
// Branch 3 "3836319117" "(value > STATE_MAX)"
// Branch 3 "3836319117" "(value > STATE_MAX)" (0) "(value > STATE_MAX) 1,-"
// Branch 3 "3836319117" "(value > STATE_MAX)" (1) "(value > STATE_MAX) 0,1"
// Branch 3 "3836319117" "(value > STATE_MAX)" (2) "(value > STATE_MAX) 0,0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 144"
// Branch 4 "3640980630" "result.q0_positive"
// ANALYSIS CANDIDATE IDS: W-54f55e7fef1f0b2c80d1
// RAW BIN IDS: 54f55e7fef1f0b2c80d1
Branch 4 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
// ANALYSIS CANDIDATE IDS: W-ee67c354a6184f32f2d0
// RAW BIN IDS: ee67c354a6184f32f2d0
Branch 4 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 148"
// Branch 5 "3640980630" "result.q0_positive"
// ANALYSIS CANDIDATE IDS: W-29fc7fcd4f6bb4c7a572
// RAW BIN IDS: 29fc7fcd4f6bb4c7a572
Branch 5 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
// ANALYSIS CANDIDATE IDS: W-c09b69d200fc2a1e8cce
// RAW BIN IDS: c09b69d200fc2a1e8cce
Branch 5 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 156"
// Branch 6 "3640980630" "result.q0_positive"
// ANALYSIS CANDIDATE IDS: W-3a97b254874d8ad076d9
// RAW BIN IDS: 3a97b254874d8ad076d9
Branch 6 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
// ANALYSIS CANDIDATE IDS: W-3e8349d76de8a6483278
// RAW BIN IDS: 3e8349d76de8a6483278
Branch 6 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 158"
// Branch 7 "3538857052" "result.q1_positive"
// ANALYSIS CANDIDATE IDS: W-33da7aa69f400af94121
// RAW BIN IDS: 33da7aa69f400af94121
Branch 7 "3538857052" "result.q1_positive" (0) "result.q1_positive 1"
// ANALYSIS CANDIDATE IDS: W-7a235a87aa93b43200ce
// RAW BIN IDS: 7a235a87aa93b43200ce
Branch 7 "3538857052" "result.q1_positive" (1) "result.q1_positive 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 170"
// Branch 8 "3292009172" "(u0_check > 0)"
// ANALYSIS CANDIDATE IDS: W-aece0ac432d59f59357a
// RAW BIN IDS: aece0ac432d59f59357a
Branch 8 "3292009172" "(u0_check > 0)" (0) "(u0_check > 0) 1"
// ANALYSIS CANDIDATE IDS: W-853ccd1007de242f2670
// RAW BIN IDS: 853ccd1007de242f2670
Branch 8 "3292009172" "(u0_check > 0)" (1) "(u0_check > 0) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 173"
// Branch 9 "2944370531" "(u1_check > 0)"
// ANALYSIS CANDIDATE IDS: W-a4c610be4068ccb6feef
// RAW BIN IDS: a4c610be4068ccb6feef
Branch 9 "2944370531" "(u1_check > 0)" (0) "(u1_check > 0) 1"
// ANALYSIS CANDIDATE IDS: W-4d0cda60b1eec927d874
// RAW BIN IDS: 4d0cda60b1eec927d874
Branch 9 "2944370531" "(u1_check > 0)" (1) "(u1_check > 0) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 175"
// Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))"
// ANALYSIS CANDIDATE IDS: W-07595ae82be962bae968
// RAW BIN IDS: 07595ae82be962bae968
Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))" (0) "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw}))) 1"
// ANALYSIS CANDIDATE IDS: W-b1248344ace9bb75130f
// RAW BIN IDS: b1248344ace9bb75130f
Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))" (1) "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw}))) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 180"
// Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))"
// ANALYSIS CANDIDATE IDS: W-b7c973d42d65e9309ed4
// RAW BIN IDS: b7c973d42d65e9309ed4
Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))" (0) "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)) 1"
// ANALYSIS CANDIDATE IDS: W-b3da33f83c5a531bfc3f
// RAW BIN IDS: b3da33f83c5a531bfc3f
Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))" (1) "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 187"
// Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))"
// ANALYSIS CANDIDATE IDS: W-19c4f90c6626eba8b50c
// RAW BIN IDS: 19c4f90c6626eba8b50c
Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))" (0) "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1"
// ANALYSIS CANDIDATE IDS: W-888de437a90c76e950bd
// RAW BIN IDS: 888de437a90c76e950bd
Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))" (1) "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 189"
// Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))"
// ANALYSIS CANDIDATE IDS: W-9f6ca386aad08bcc2c0e
// RAW BIN IDS: 9f6ca386aad08bcc2c0e
Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))" (0) "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1"
// ANALYSIS CANDIDATE IDS: W-901dcdedb38807335a4e
// RAW BIN IDS: 901dcdedb38807335a4e
Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))" (1) "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 0"



CHECKSUM: "1491642939 4234966567"
//
ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[1].g_order2.u_tid
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 96"
// Branch 0 "1027625233" "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0))"
// ANALYSIS CANDIDATE IDS: W-1ce71fdfafcf38ff2718
// RAW BIN IDS: 1ce71fdfafcf38ff2718
Branch 0 "1027625233" "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0))" (0) "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0)) 1"
// Branch 0 "1027625233" "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0))" (1) "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0)) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 231"
// Branch 1 "4262564349" "PAIR_LOOKAHEAD"
// ANALYSIS CANDIDATE IDS: W-46f7a24307e77f7dd1ad
// RAW BIN IDS: 46f7a24307e77f7dd1ad
Branch 1 "4262564349" "PAIR_LOOKAHEAD" (0) "PAIR_LOOKAHEAD 1"
// Branch 1 "4262564349" "PAIR_LOOKAHEAD" (1) "PAIR_LOOKAHEAD 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 332"
// Branch 2 "3880551804" "(!rst_n)"
// Branch 2 "3880551804" "(!rst_n)" (0) "(!rst_n) 1,-,-"
// Branch 2 "3880551804" "(!rst_n)" (1) "(!rst_n) 0,1,1"
// Branch 2 "3880551804" "(!rst_n)" (2) "(!rst_n) 0,1,0"
// Branch 2 "3880551804" "(!rst_n)" (3) "(!rst_n) 0,0,-"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 104"
// Branch 3 "3836319117" "(value > STATE_MAX)"
// Branch 3 "3836319117" "(value > STATE_MAX)" (0) "(value > STATE_MAX) 1,-"
// Branch 3 "3836319117" "(value > STATE_MAX)" (1) "(value > STATE_MAX) 0,1"
// Branch 3 "3836319117" "(value > STATE_MAX)" (2) "(value > STATE_MAX) 0,0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 144"
// Branch 4 "3640980630" "result.q0_positive"
// ANALYSIS CANDIDATE IDS: W-155dbaa1c9498dd51e5a
// RAW BIN IDS: 155dbaa1c9498dd51e5a
Branch 4 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
// ANALYSIS CANDIDATE IDS: W-dfed55699971bef1e6cd
// RAW BIN IDS: dfed55699971bef1e6cd
Branch 4 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 148"
// Branch 5 "3640980630" "result.q0_positive"
// ANALYSIS CANDIDATE IDS: W-47b515e15cb9417c09be
// RAW BIN IDS: 47b515e15cb9417c09be
Branch 5 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
// ANALYSIS CANDIDATE IDS: W-7d8b860c6e7355869264
// RAW BIN IDS: 7d8b860c6e7355869264
Branch 5 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 156"
// Branch 6 "3640980630" "result.q0_positive"
// ANALYSIS CANDIDATE IDS: W-b741f7af06b2e4f99a33
// RAW BIN IDS: b741f7af06b2e4f99a33
Branch 6 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
// ANALYSIS CANDIDATE IDS: W-245ea2aad6e8bbe9851e
// RAW BIN IDS: 245ea2aad6e8bbe9851e
Branch 6 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 158"
// Branch 7 "3538857052" "result.q1_positive"
// ANALYSIS CANDIDATE IDS: W-8c908fa74a19add74eae
// RAW BIN IDS: 8c908fa74a19add74eae
Branch 7 "3538857052" "result.q1_positive" (0) "result.q1_positive 1"
// ANALYSIS CANDIDATE IDS: W-f7cee7a600b940a80e11
// RAW BIN IDS: f7cee7a600b940a80e11
Branch 7 "3538857052" "result.q1_positive" (1) "result.q1_positive 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 170"
// Branch 8 "3292009172" "(u0_check > 0)"
// ANALYSIS CANDIDATE IDS: W-1c79e758a80da3e722a8
// RAW BIN IDS: 1c79e758a80da3e722a8
Branch 8 "3292009172" "(u0_check > 0)" (0) "(u0_check > 0) 1"
// ANALYSIS CANDIDATE IDS: W-345d237588f5695e78f4
// RAW BIN IDS: 345d237588f5695e78f4
Branch 8 "3292009172" "(u0_check > 0)" (1) "(u0_check > 0) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 173"
// Branch 9 "2944370531" "(u1_check > 0)"
// ANALYSIS CANDIDATE IDS: W-5008fb88bf48da84c634
// RAW BIN IDS: 5008fb88bf48da84c634
Branch 9 "2944370531" "(u1_check > 0)" (0) "(u1_check > 0) 1"
// ANALYSIS CANDIDATE IDS: W-b474cd1a63bd0e177410
// RAW BIN IDS: b474cd1a63bd0e177410
Branch 9 "2944370531" "(u1_check > 0)" (1) "(u1_check > 0) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 175"
// Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))"
// ANALYSIS CANDIDATE IDS: W-c7e2e18e4a93de7e8507
// RAW BIN IDS: c7e2e18e4a93de7e8507
Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))" (0) "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw}))) 1"
// ANALYSIS CANDIDATE IDS: W-a7ca730ff90022089f59
// RAW BIN IDS: a7ca730ff90022089f59
Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))" (1) "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw}))) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 180"
// Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))"
// ANALYSIS CANDIDATE IDS: W-8c094ed4ef14c2b35437
// RAW BIN IDS: 8c094ed4ef14c2b35437
Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))" (0) "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)) 1"
// ANALYSIS CANDIDATE IDS: W-71d2aff709a5e0e78321
// RAW BIN IDS: 71d2aff709a5e0e78321
Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))" (1) "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 187"
// Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))"
// ANALYSIS CANDIDATE IDS: W-7c0b393f8851361219c3
// RAW BIN IDS: 7c0b393f8851361219c3
Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))" (0) "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1"
// ANALYSIS CANDIDATE IDS: W-a2ed58bc0685d51efd0f
// RAW BIN IDS: a2ed58bc0685d51efd0f
Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))" (1) "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 189"
// Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))"
// ANALYSIS CANDIDATE IDS: W-d3289fc8bc060fce62c5
// RAW BIN IDS: d3289fc8bc060fce62c5
Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))" (0) "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1"
// ANALYSIS CANDIDATE IDS: W-ec5f62e93baac8b26f68
// RAW BIN IDS: ec5f62e93baac8b26f68
Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))" (1) "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 0"



CHECKSUM: "1491642939 4234966567"
//
ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[2].g_order2.u_tid
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 96"
// Branch 0 "1027625233" "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0))"
// ANALYSIS CANDIDATE IDS: W-fc029df550c82288db58
// RAW BIN IDS: fc029df550c82288db58
Branch 0 "1027625233" "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0))" (0) "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0)) 1"
// Branch 0 "1027625233" "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0))" (1) "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0)) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 231"
// Branch 1 "4262564349" "PAIR_LOOKAHEAD"
// ANALYSIS CANDIDATE IDS: W-8d03896cc8852ebcabcc
// RAW BIN IDS: 8d03896cc8852ebcabcc
Branch 1 "4262564349" "PAIR_LOOKAHEAD" (0) "PAIR_LOOKAHEAD 1"
// Branch 1 "4262564349" "PAIR_LOOKAHEAD" (1) "PAIR_LOOKAHEAD 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 332"
// Branch 2 "3880551804" "(!rst_n)"
// Branch 2 "3880551804" "(!rst_n)" (0) "(!rst_n) 1,-,-"
// Branch 2 "3880551804" "(!rst_n)" (1) "(!rst_n) 0,1,1"
// Branch 2 "3880551804" "(!rst_n)" (2) "(!rst_n) 0,1,0"
// Branch 2 "3880551804" "(!rst_n)" (3) "(!rst_n) 0,0,-"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 104"
// Branch 3 "3836319117" "(value > STATE_MAX)"
// Branch 3 "3836319117" "(value > STATE_MAX)" (0) "(value > STATE_MAX) 1,-"
// Branch 3 "3836319117" "(value > STATE_MAX)" (1) "(value > STATE_MAX) 0,1"
// Branch 3 "3836319117" "(value > STATE_MAX)" (2) "(value > STATE_MAX) 0,0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 144"
// Branch 4 "3640980630" "result.q0_positive"
// ANALYSIS CANDIDATE IDS: W-2e97aaee7d82c89cfd72
// RAW BIN IDS: 2e97aaee7d82c89cfd72
Branch 4 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
// ANALYSIS CANDIDATE IDS: W-66d49753d50ce437c0db
// RAW BIN IDS: 66d49753d50ce437c0db
Branch 4 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 148"
// Branch 5 "3640980630" "result.q0_positive"
// ANALYSIS CANDIDATE IDS: W-4b5fd4cbe88a61fead9d
// RAW BIN IDS: 4b5fd4cbe88a61fead9d
Branch 5 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
// ANALYSIS CANDIDATE IDS: W-fa909a022f8528abda80
// RAW BIN IDS: fa909a022f8528abda80
Branch 5 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 156"
// Branch 6 "3640980630" "result.q0_positive"
// ANALYSIS CANDIDATE IDS: W-40b9199dc646f7001f91
// RAW BIN IDS: 40b9199dc646f7001f91
Branch 6 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
// ANALYSIS CANDIDATE IDS: W-9e3ba6da1c9fdcc56bde
// RAW BIN IDS: 9e3ba6da1c9fdcc56bde
Branch 6 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 158"
// Branch 7 "3538857052" "result.q1_positive"
// ANALYSIS CANDIDATE IDS: W-37620c81e59584fa038a
// RAW BIN IDS: 37620c81e59584fa038a
Branch 7 "3538857052" "result.q1_positive" (0) "result.q1_positive 1"
// ANALYSIS CANDIDATE IDS: W-a6c435c920c87f7ae408
// RAW BIN IDS: a6c435c920c87f7ae408
Branch 7 "3538857052" "result.q1_positive" (1) "result.q1_positive 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 170"
// Branch 8 "3292009172" "(u0_check > 0)"
// ANALYSIS CANDIDATE IDS: W-7fdb0c8c6b1fd0eda3b0
// RAW BIN IDS: 7fdb0c8c6b1fd0eda3b0
Branch 8 "3292009172" "(u0_check > 0)" (0) "(u0_check > 0) 1"
// ANALYSIS CANDIDATE IDS: W-0069b379bb9d20b59915
// RAW BIN IDS: 0069b379bb9d20b59915
Branch 8 "3292009172" "(u0_check > 0)" (1) "(u0_check > 0) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 173"
// Branch 9 "2944370531" "(u1_check > 0)"
// ANALYSIS CANDIDATE IDS: W-aefd5dc462523785ab45
// RAW BIN IDS: aefd5dc462523785ab45
Branch 9 "2944370531" "(u1_check > 0)" (0) "(u1_check > 0) 1"
// ANALYSIS CANDIDATE IDS: W-e61df6503d6262e28965
// RAW BIN IDS: e61df6503d6262e28965
Branch 9 "2944370531" "(u1_check > 0)" (1) "(u1_check > 0) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 175"
// Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))"
// ANALYSIS CANDIDATE IDS: W-d299bcb3dec989183735
// RAW BIN IDS: d299bcb3dec989183735
Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))" (0) "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw}))) 1"
// ANALYSIS CANDIDATE IDS: W-d4025a2ed0eae976a530
// RAW BIN IDS: d4025a2ed0eae976a530
Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))" (1) "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw}))) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 180"
// Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))"
// ANALYSIS CANDIDATE IDS: W-daa3f60e6c62904d5efd
// RAW BIN IDS: daa3f60e6c62904d5efd
Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))" (0) "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)) 1"
// ANALYSIS CANDIDATE IDS: W-a42ee25f7cbcfaa7bc0d
// RAW BIN IDS: a42ee25f7cbcfaa7bc0d
Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))" (1) "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 187"
// Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))"
// ANALYSIS CANDIDATE IDS: W-d6eecb031b5843c14674
// RAW BIN IDS: d6eecb031b5843c14674
Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))" (0) "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1"
// ANALYSIS CANDIDATE IDS: W-d199f0712c4014a81717
// RAW BIN IDS: d199f0712c4014a81717
Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))" (1) "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 189"
// Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))"
// ANALYSIS CANDIDATE IDS: W-8730606fdf52d195258e
// RAW BIN IDS: 8730606fdf52d195258e
Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))" (0) "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1"
// ANALYSIS CANDIDATE IDS: W-f9dd9ede058446a8a283
// RAW BIN IDS: f9dd9ede058446a8a283
Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))" (1) "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 0"



CHECKSUM: "1491642939 4234966567"
//
ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[3].g_order2.u_tid
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 96"
// Branch 0 "1027625233" "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0))"
// ANALYSIS CANDIDATE IDS: W-42b83997e24279309813
// RAW BIN IDS: 42b83997e24279309813
Branch 0 "1027625233" "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0))" (0) "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0)) 1"
// Branch 0 "1027625233" "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0))" (1) "(((W < 2) || (CHANNELS < 2)) || ((CHANNELS % 2) != 0)) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 231"
// Branch 1 "4262564349" "PAIR_LOOKAHEAD"
// ANALYSIS CANDIDATE IDS: W-560e41ce2a2f213cecb3
// RAW BIN IDS: 560e41ce2a2f213cecb3
Branch 1 "4262564349" "PAIR_LOOKAHEAD" (0) "PAIR_LOOKAHEAD 1"
// Branch 1 "4262564349" "PAIR_LOOKAHEAD" (1) "PAIR_LOOKAHEAD 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 332"
// Branch 2 "3880551804" "(!rst_n)"
// Branch 2 "3880551804" "(!rst_n)" (0) "(!rst_n) 1,-,-"
// Branch 2 "3880551804" "(!rst_n)" (1) "(!rst_n) 0,1,1"
// Branch 2 "3880551804" "(!rst_n)" (2) "(!rst_n) 0,1,0"
// Branch 2 "3880551804" "(!rst_n)" (3) "(!rst_n) 0,0,-"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 104"
// Branch 3 "3836319117" "(value > STATE_MAX)"
// Branch 3 "3836319117" "(value > STATE_MAX)" (0) "(value > STATE_MAX) 1,-"
// Branch 3 "3836319117" "(value > STATE_MAX)" (1) "(value > STATE_MAX) 0,1"
// Branch 3 "3836319117" "(value > STATE_MAX)" (2) "(value > STATE_MAX) 0,0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 144"
// Branch 4 "3640980630" "result.q0_positive"
// ANALYSIS CANDIDATE IDS: W-7c8695dde72c8429f295
// RAW BIN IDS: 7c8695dde72c8429f295
Branch 4 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
// ANALYSIS CANDIDATE IDS: W-6f69a85945c89b741826
// RAW BIN IDS: 6f69a85945c89b741826
Branch 4 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 148"
// Branch 5 "3640980630" "result.q0_positive"
// ANALYSIS CANDIDATE IDS: W-ff3f8908b39f1abafc97
// RAW BIN IDS: ff3f8908b39f1abafc97
Branch 5 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
// ANALYSIS CANDIDATE IDS: W-269a42ab130079c48434
// RAW BIN IDS: 269a42ab130079c48434
Branch 5 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 156"
// Branch 6 "3640980630" "result.q0_positive"
// ANALYSIS CANDIDATE IDS: W-e522b70b87f7c3c5845e
// RAW BIN IDS: e522b70b87f7c3c5845e
Branch 6 "3640980630" "result.q0_positive" (0) "result.q0_positive 1"
// ANALYSIS CANDIDATE IDS: W-16e3ed5b14d4966ed44f
// RAW BIN IDS: 16e3ed5b14d4966ed44f
Branch 6 "3640980630" "result.q0_positive" (1) "result.q0_positive 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 158"
// Branch 7 "3538857052" "result.q1_positive"
// ANALYSIS CANDIDATE IDS: W-50ad46fa15b7113e9fe0
// RAW BIN IDS: 50ad46fa15b7113e9fe0
Branch 7 "3538857052" "result.q1_positive" (0) "result.q1_positive 1"
// ANALYSIS CANDIDATE IDS: W-2079b2636d7e630e7b36
// RAW BIN IDS: 2079b2636d7e630e7b36
Branch 7 "3538857052" "result.q1_positive" (1) "result.q1_positive 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 170"
// Branch 8 "3292009172" "(u0_check > 0)"
// ANALYSIS CANDIDATE IDS: W-4b00a82b8873f6083b95
// RAW BIN IDS: 4b00a82b8873f6083b95
Branch 8 "3292009172" "(u0_check > 0)" (0) "(u0_check > 0) 1"
// ANALYSIS CANDIDATE IDS: W-d7369017a410eba2d192
// RAW BIN IDS: d7369017a410eba2d192
Branch 8 "3292009172" "(u0_check > 0)" (1) "(u0_check > 0) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 173"
// Branch 9 "2944370531" "(u1_check > 0)"
// ANALYSIS CANDIDATE IDS: W-2797b57dcd6a9cd4f4d4
// RAW BIN IDS: 2797b57dcd6a9cd4f4d4
Branch 9 "2944370531" "(u1_check > 0)" (0) "(u1_check > 0) 1"
// ANALYSIS CANDIDATE IDS: W-e5b869d873f59d4a9fb4
// RAW BIN IDS: e5b869d873f59d4a9fb4
Branch 9 "2944370531" "(u1_check > 0)" (1) "(u1_check > 0) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 175"
// Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))"
// ANALYSIS CANDIDATE IDS: W-b2d10a5c48c2d3099182
// RAW BIN IDS: b2d10a5c48c2d3099182
Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))" (0) "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw}))) 1"
// ANALYSIS CANDIDATE IDS: W-35935eb86d2f36a73cfb
// RAW BIN IDS: 35935eb86d2f36a73cfb
Branch 10 "2391466633" "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw})))" (1) "(((($signed(u0_check) != $signed({result.u0[(ACC_W - 1)], result.u0})) || ($signed(e0_raw_check) != $signed({result.e0_raw[(ACC_W - 1)], result.e0_raw}))) || ($signed(u1_check) != $signed({result.u1[(ACC_W - 1)], result.u1}))) || ($signed(e1_raw_check) != $signed({result.e1_raw[(ACC_W - 1)], result.e1_raw}))) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 180"
// Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))"
// ANALYSIS CANDIDATE IDS: W-9b60a32bc00b63ad654d
// RAW BIN IDS: 9b60a32bc00b63ad654d
Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))" (0) "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)) 1"
// ANALYSIS CANDIDATE IDS: W-539d794d911a00ba7533
// RAW BIN IDS: 539d794d911a00ba7533
Branch 11 "4278405649" "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND))" (1) "((((((((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND)) || (u1_check < (-U_ABS_BOUND))) || (u1_check > U_ABS_BOUND)) || (e0_raw_check < (-E_RAW_ABS_BOUND))) || (e0_raw_check > E_RAW_ABS_BOUND)) || (e1_raw_check < (-E_RAW_ABS_BOUND))) || (e1_raw_check > E_RAW_ABS_BOUND)) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 187"
// Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))"
// ANALYSIS CANDIDATE IDS: W-0cb5cc31868f49a6aa01
// RAW BIN IDS: 0cb5cc31868f49a6aa01
Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))" (0) "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1"
// ANALYSIS CANDIDATE IDS: W-8239c3285ed23d594cb0
// RAW BIN IDS: 8239c3285ed23d594cb0
Branch 12 "3911475839" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX))" (1) "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 189"
// Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))"
// ANALYSIS CANDIDATE IDS: W-e5d275c30c22fa4ceff6
// RAW BIN IDS: e5d275c30c22fa4ceff6
Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))" (0) "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1"
// ANALYSIS CANDIDATE IDS: W-51f462b1b63b94614914
// RAW BIN IDS: 51f462b1b63b94614914
Branch 13 "1928174088" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN))" (1) "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 0"



CHECKSUM: "3956776050 240787270"
//
ANNOTATION: "ModuleName: tid32_thermo5_axi_lite_axis_frontend_tx"
INSTANCE: thermo5_sku_uvm_tb.dut
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv, LineNumber: 107"
// Branch 0 "1051891802" "(!s_axis_aresetn)"
// Branch 0 "1051891802" "(!s_axis_aresetn)" (0) "(!s_axis_aresetn) 1,-,-,-,-,-,-,-"
// Branch 0 "1051891802" "(!s_axis_aresetn)" (1) "(!s_axis_aresetn) 0,1,-,-,-,-,-,-"
// Branch 0 "1051891802" "(!s_axis_aresetn)" (2) "(!s_axis_aresetn) 0,0,1,-,-,-,-,-"
// Branch 0 "1051891802" "(!s_axis_aresetn)" (3) "(!s_axis_aresetn) 0,0,0,-,-,-,-,-"
// Branch 0 "1051891802" "(!s_axis_aresetn)" (4) "(!s_axis_aresetn) 0,-,-,1,-,-,-,-"
// Branch 0 "1051891802" "(!s_axis_aresetn)" (5) "(!s_axis_aresetn) 0,-,-,0,-,-,-,-"
// Branch 0 "1051891802" "(!s_axis_aresetn)" (6) "(!s_axis_aresetn) 0,-,-,-,1,1,-,-"
// Branch 0 "1051891802" "(!s_axis_aresetn)" (7) "(!s_axis_aresetn) 0,-,-,-,1,0,-,-"
// Branch 0 "1051891802" "(!s_axis_aresetn)" (8) "(!s_axis_aresetn) 0,-,-,-,1,-,1,-"
// Branch 0 "1051891802" "(!s_axis_aresetn)" (9) "(!s_axis_aresetn) 0,-,-,-,1,-,0,-"
// Branch 0 "1051891802" "(!s_axis_aresetn)" (10) "(!s_axis_aresetn) 0,-,-,-,1,-,-,1"
// Branch 0 "1051891802" "(!s_axis_aresetn)" (11) "(!s_axis_aresetn) 0,-,-,-,1,-,-,0"
// Branch 0 "1051891802" "(!s_axis_aresetn)" (12) "(!s_axis_aresetn) 0,-,-,-,0,-,-,-"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv, LineNumber: 155"
// Branch 1 "3677627324" "(!core_aresetn)"
// Branch 1 "3677627324" "(!core_aresetn)" (0) "(!core_aresetn) 1"
// Branch 1 "3677627324" "(!core_aresetn)" (1) "(!core_aresetn) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv, LineNumber: 183"
// Branch 2 "3677627324" "(!core_aresetn)"
// Branch 2 "3677627324" "(!core_aresetn)" (0) "(!core_aresetn) 1"
// Branch 2 "3677627324" "(!core_aresetn)" (1) "(!core_aresetn) 0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv, LineNumber: 198"
// Branch 3 "2439108191" "(!core_aresetn)"
// Branch 3 "2439108191" "(!core_aresetn)" (0) "(!core_aresetn) 1,-,-,-,-,-"
// Branch 3 "2439108191" "(!core_aresetn)" (1) "(!core_aresetn) 0,2'b10 ,1,-,-,-"
// Branch 3 "2439108191" "(!core_aresetn)" (2) "(!core_aresetn) 0,2'b10 ,0,-,-,-"
// Branch 3 "2439108191" "(!core_aresetn)" (3) "(!core_aresetn) 0,2'b01 ,-,1,-,-"
// Branch 3 "2439108191" "(!core_aresetn)" (4) "(!core_aresetn) 0,2'b01 ,-,0,-,-"
// Branch 3 "2439108191" "(!core_aresetn)" (5) "(!core_aresetn) 0,default,-,-,-,-"
// Branch 3 "2439108191" "(!core_aresetn)" (6) "(!core_aresetn) 0,-,-,-,1,-"
// Branch 3 "2439108191" "(!core_aresetn)" (7) "(!core_aresetn) 0,-,-,-,0,1"
// Branch 3 "2439108191" "(!core_aresetn)" (8) "(!core_aresetn) 0,-,-,-,0,0"
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv, LineNumber: 274"
// Branch 4 "483805220" "((DPD_MAX_TAPS < 1) || (DPD_MAX_TAPS > 4))"
// ANALYSIS CANDIDATE IDS: W-8a77e7b66cc62a232b69
// RAW BIN IDS: 8a77e7b66cc62a232b69
Branch 4 "483805220" "((DPD_MAX_TAPS < 1) || (DPD_MAX_TAPS > 4))" (0) "((DPD_MAX_TAPS < 1) || (DPD_MAX_TAPS > 4)) 1"
// Branch 4 "483805220" "((DPD_MAX_TAPS < 1) || (DPD_MAX_TAPS > 4))" (1) "((DPD_MAX_TAPS < 1) || (DPD_MAX_TAPS > 4)) 0"

CHECKSUM: "1491642939 475307837"
//
ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[0].g_order2.u_tid
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 144"
// Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1"
// ANALYSIS CANDIDATE IDS: W-2fdb0f2eeeece879e9d0
// RAW BIN IDS: 2fdb0f2eeeece879e9d0
Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-a38566592c0a82524397
// RAW BIN IDS: a38566592c0a82524397
Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 148"
// Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1"
// ANALYSIS CANDIDATE IDS: W-f6593cb7ceba45ee8816
// RAW BIN IDS: f6593cb7ceba45ee8816
Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-517a1e88d8de7c6dc94b
// RAW BIN IDS: 517a1e88d8de7c6dc94b
Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 156"
// Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1"
// ANALYSIS CANDIDATE IDS: W-9e0b25a0ee7fd86bea04
// RAW BIN IDS: 9e0b25a0ee7fd86bea04
Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-c13dbca1c54900356c25
// RAW BIN IDS: c13dbca1c54900356c25
Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 158"
// Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1"
// ANALYSIS CANDIDATE IDS: W-8d913192bef7fc19c083
// RAW BIN IDS: 8d913192bef7fc19c083
Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-8230f4c91a66b600b56d
// RAW BIN IDS: 8230f4c91a66b600b56d
Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 170"
// Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1"
// ANALYSIS CANDIDATE IDS: W-0f97415b58493a490d10
// RAW BIN IDS: 0f97415b58493a490d10
Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-04778360b5c1face9357
// RAW BIN IDS: 04778360b5c1face9357
Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 173"
// Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1"
// ANALYSIS CANDIDATE IDS: W-5ef6d83f4732ac634897
// RAW BIN IDS: 5ef6d83f4732ac634897
Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-54e5baf9e387d2dc27b8
// RAW BIN IDS: 54e5baf9e387d2dc27b8
Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 180"
// Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1"
// ANALYSIS CANDIDATE IDS: W-31c81575ba7468405518
// RAW BIN IDS: 31c81575ba7468405518
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (1 "00000000")
// ANALYSIS CANDIDATE IDS: W-e9b8c9976dd11461946e
// RAW BIN IDS: e9b8c9976dd11461946e
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (2 "00000001")
// ANALYSIS CANDIDATE IDS: W-e2e2c8c20c6ed722105a
// RAW BIN IDS: e2e2c8c20c6ed722105a
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (3 "00000010")
// ANALYSIS CANDIDATE IDS: W-073534c5a1d13f18225c
// RAW BIN IDS: 073534c5a1d13f18225c
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (4 "00000100")
// ANALYSIS CANDIDATE IDS: W-cc76214066b91651843d
// RAW BIN IDS: cc76214066b91651843d
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (5 "00001000")
// ANALYSIS CANDIDATE IDS: W-b3a10664d9256a7aedbb
// RAW BIN IDS: b3a10664d9256a7aedbb
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (6 "00010000")
// ANALYSIS CANDIDATE IDS: W-880ed80bfab266756f29
// RAW BIN IDS: 880ed80bfab266756f29
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (7 "00100000")
// ANALYSIS CANDIDATE IDS: W-8d3f031e0e3dfa9b1ff3
// RAW BIN IDS: 8d3f031e0e3dfa9b1ff3
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (8 "01000000")
// ANALYSIS CANDIDATE IDS: W-2da0c120b56ea7dc06e1
// RAW BIN IDS: 2da0c120b56ea7dc06e1
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (9 "10000000")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 187"
// Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1"
// ANALYSIS CANDIDATE IDS: W-db9cbcb335cd3f94c405
// RAW BIN IDS: db9cbcb335cd3f94c405
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (1 "00")
// ANALYSIS CANDIDATE IDS: W-ad1a429a094c84ebab00
// RAW BIN IDS: ad1a429a094c84ebab00
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (2 "01")
// ANALYSIS CANDIDATE IDS: W-c017722d69e375876155
// RAW BIN IDS: c017722d69e375876155
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (3 "10")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 189"
// Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1"
// ANALYSIS CANDIDATE IDS: W-8d0540b4fe663d54eabd
// RAW BIN IDS: 8d0540b4fe663d54eabd
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (1 "00")
// ANALYSIS CANDIDATE IDS: W-7193dfbba4b0dbf7c1ca
// RAW BIN IDS: 7193dfbba4b0dbf7c1ca
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (2 "01")
// ANALYSIS CANDIDATE IDS: W-781cd9e42630743f6b3b
// RAW BIN IDS: 781cd9e42630743f6b3b
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (3 "10")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 329"
// Condition 10 "688901962" "(in_valid && in_ready) 1 -1"
// Condition 10 "688901962" "(in_valid && in_ready) 1 -1" (1 "01")
// Condition 10 "688901962" "(in_valid && in_ready) 1 -1" (2 "10")
// Condition 10 "688901962" "(in_valid && in_ready) 1 -1" (3 "11")



CHECKSUM: "1491642939 475307837"
//
ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[1].g_order2.u_tid
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 144"
// Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1"
// ANALYSIS CANDIDATE IDS: W-a8adec026bb472d26910
// RAW BIN IDS: a8adec026bb472d26910
Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-4a0283db87d955c8298a
// RAW BIN IDS: 4a0283db87d955c8298a
Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 148"
// Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1"
// ANALYSIS CANDIDATE IDS: W-4518c718d7412de416ff
// RAW BIN IDS: 4518c718d7412de416ff
Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-53f8d71cfcdb0a320bfe
// RAW BIN IDS: 53f8d71cfcdb0a320bfe
Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 156"
// Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1"
// ANALYSIS CANDIDATE IDS: W-bb5c42f487783cf5b255
// RAW BIN IDS: bb5c42f487783cf5b255
Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-af7c81f2cecd39fdacc1
// RAW BIN IDS: af7c81f2cecd39fdacc1
Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 158"
// Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1"
// ANALYSIS CANDIDATE IDS: W-897e1e039ae1186450ce
// RAW BIN IDS: 897e1e039ae1186450ce
Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-641c434215df2b885107
// RAW BIN IDS: 641c434215df2b885107
Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 170"
// Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1"
// ANALYSIS CANDIDATE IDS: W-790796e6a90e20198f9c
// RAW BIN IDS: 790796e6a90e20198f9c
Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-37b1ec95ce156ae6c901
// RAW BIN IDS: 37b1ec95ce156ae6c901
Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 173"
// Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1"
// ANALYSIS CANDIDATE IDS: W-8aebec79646e39c5c158
// RAW BIN IDS: 8aebec79646e39c5c158
Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-6bbe671a00e8adbbc67a
// RAW BIN IDS: 6bbe671a00e8adbbc67a
Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 180"
// Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1"
// ANALYSIS CANDIDATE IDS: W-c6c2a1b8547680b0e0ab
// RAW BIN IDS: c6c2a1b8547680b0e0ab
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (1 "00000000")
// ANALYSIS CANDIDATE IDS: W-9d1af2eb381071bd3b7d
// RAW BIN IDS: 9d1af2eb381071bd3b7d
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (2 "00000001")
// ANALYSIS CANDIDATE IDS: W-f4e9c70e66ecbf5e4ca2
// RAW BIN IDS: f4e9c70e66ecbf5e4ca2
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (3 "00000010")
// ANALYSIS CANDIDATE IDS: W-2f0aeeb19c847d772935
// RAW BIN IDS: 2f0aeeb19c847d772935
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (4 "00000100")
// ANALYSIS CANDIDATE IDS: W-92ac451faeb760079ca8
// RAW BIN IDS: 92ac451faeb760079ca8
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (5 "00001000")
// ANALYSIS CANDIDATE IDS: W-cd4717ad916b9979a47a
// RAW BIN IDS: cd4717ad916b9979a47a
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (6 "00010000")
// ANALYSIS CANDIDATE IDS: W-bb05cd241de66235fa1e
// RAW BIN IDS: bb05cd241de66235fa1e
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (7 "00100000")
// ANALYSIS CANDIDATE IDS: W-a57a0b313e3f00466444
// RAW BIN IDS: a57a0b313e3f00466444
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (8 "01000000")
// ANALYSIS CANDIDATE IDS: W-9ec2703ad2aa3138e8c5
// RAW BIN IDS: 9ec2703ad2aa3138e8c5
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (9 "10000000")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 187"
// Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1"
// ANALYSIS CANDIDATE IDS: W-3352031a5d823fee76a4
// RAW BIN IDS: 3352031a5d823fee76a4
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (1 "00")
// ANALYSIS CANDIDATE IDS: W-3fb67e1cd05225795b0f
// RAW BIN IDS: 3fb67e1cd05225795b0f
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (2 "01")
// ANALYSIS CANDIDATE IDS: W-9f9a80cdcc8e3d7d572b
// RAW BIN IDS: 9f9a80cdcc8e3d7d572b
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (3 "10")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 189"
// Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1"
// ANALYSIS CANDIDATE IDS: W-cfaeee0b5bacfde49a2e
// RAW BIN IDS: cfaeee0b5bacfde49a2e
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (1 "00")
// ANALYSIS CANDIDATE IDS: W-51bd4a0184fcf73631d4
// RAW BIN IDS: 51bd4a0184fcf73631d4
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (2 "01")
// ANALYSIS CANDIDATE IDS: W-af6eed398c1d0eff8426
// RAW BIN IDS: af6eed398c1d0eff8426
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (3 "10")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 329"
// Condition 10 "688901962" "(in_valid && in_ready) 1 -1"
// Condition 10 "688901962" "(in_valid && in_ready) 1 -1" (1 "01")
// Condition 10 "688901962" "(in_valid && in_ready) 1 -1" (2 "10")
// Condition 10 "688901962" "(in_valid && in_ready) 1 -1" (3 "11")



CHECKSUM: "1491642939 475307837"
//
ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[2].g_order2.u_tid
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 144"
// Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1"
// ANALYSIS CANDIDATE IDS: W-fd9d4f78be18e1442c24
// RAW BIN IDS: fd9d4f78be18e1442c24
Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-458048661ba94a621314
// RAW BIN IDS: 458048661ba94a621314
Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 148"
// Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1"
// ANALYSIS CANDIDATE IDS: W-93d4ee060ebe784edb96
// RAW BIN IDS: 93d4ee060ebe784edb96
Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-f25ebad0320e66c0dca7
// RAW BIN IDS: f25ebad0320e66c0dca7
Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 156"
// Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1"
// ANALYSIS CANDIDATE IDS: W-bfed9e3b1fa5fd8cc2c5
// RAW BIN IDS: bfed9e3b1fa5fd8cc2c5
Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-0c4aa9036eb4c1fe9764
// RAW BIN IDS: 0c4aa9036eb4c1fe9764
Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 158"
// Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1"
// ANALYSIS CANDIDATE IDS: W-d74adb996db5455880c6
// RAW BIN IDS: d74adb996db5455880c6
Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-fe3f6d3f30b98a8d0d18
// RAW BIN IDS: fe3f6d3f30b98a8d0d18
Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 170"
// Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1"
// ANALYSIS CANDIDATE IDS: W-791cd55755bcfda44000
// RAW BIN IDS: 791cd55755bcfda44000
Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-19b67d0bc9b9f676ef60
// RAW BIN IDS: 19b67d0bc9b9f676ef60
Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 173"
// Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1"
// ANALYSIS CANDIDATE IDS: W-848617efc0bb57eac6e4
// RAW BIN IDS: 848617efc0bb57eac6e4
Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-e03c6e851e69dd25e01a
// RAW BIN IDS: e03c6e851e69dd25e01a
Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 180"
// Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1"
// ANALYSIS CANDIDATE IDS: W-690ee0f339bbe43ca379
// RAW BIN IDS: 690ee0f339bbe43ca379
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (1 "00000000")
// ANALYSIS CANDIDATE IDS: W-a134b5bd5e93149f4b39
// RAW BIN IDS: a134b5bd5e93149f4b39
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (2 "00000001")
// ANALYSIS CANDIDATE IDS: W-f0459143b16c300b919f
// RAW BIN IDS: f0459143b16c300b919f
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (3 "00000010")
// ANALYSIS CANDIDATE IDS: W-363588e0df4d9ecd2068
// RAW BIN IDS: 363588e0df4d9ecd2068
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (4 "00000100")
// ANALYSIS CANDIDATE IDS: W-c7dec529569a73017998
// RAW BIN IDS: c7dec529569a73017998
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (5 "00001000")
// ANALYSIS CANDIDATE IDS: W-69a7d4a2fcee0887d8d7
// RAW BIN IDS: 69a7d4a2fcee0887d8d7
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (6 "00010000")
// ANALYSIS CANDIDATE IDS: W-f4d5eabd75de10da4c31
// RAW BIN IDS: f4d5eabd75de10da4c31
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (7 "00100000")
// ANALYSIS CANDIDATE IDS: W-fa10dfc48e988db3bd2e
// RAW BIN IDS: fa10dfc48e988db3bd2e
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (8 "01000000")
// ANALYSIS CANDIDATE IDS: W-70c0858a8c5510e42074
// RAW BIN IDS: 70c0858a8c5510e42074
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (9 "10000000")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 187"
// Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1"
// ANALYSIS CANDIDATE IDS: W-912269dbb59e9e128f81
// RAW BIN IDS: 912269dbb59e9e128f81
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (1 "00")
// ANALYSIS CANDIDATE IDS: W-fd9f8e433b539e1e953d
// RAW BIN IDS: fd9f8e433b539e1e953d
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (2 "01")
// ANALYSIS CANDIDATE IDS: W-a6d91a8ca55484cc7cd4
// RAW BIN IDS: a6d91a8ca55484cc7cd4
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (3 "10")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 189"
// Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1"
// ANALYSIS CANDIDATE IDS: W-7b8bc3e5777cc4ac24be
// RAW BIN IDS: 7b8bc3e5777cc4ac24be
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (1 "00")
// ANALYSIS CANDIDATE IDS: W-b927ee9751ff388015c0
// RAW BIN IDS: b927ee9751ff388015c0
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (2 "01")
// ANALYSIS CANDIDATE IDS: W-720b47bb9a20014f52e4
// RAW BIN IDS: 720b47bb9a20014f52e4
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (3 "10")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 329"
// Condition 10 "688901962" "(in_valid && in_ready) 1 -1"
// Condition 10 "688901962" "(in_valid && in_ready) 1 -1" (1 "01")
// Condition 10 "688901962" "(in_valid && in_ready) 1 -1" (2 "10")
// Condition 10 "688901962" "(in_valid && in_ready) 1 -1" (3 "11")



CHECKSUM: "1491642939 475307837"
//
ANNOTATION: "ModuleName: tid32_cartesian_ef2_fs4_gt_tx"
INSTANCE: thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[3].g_order2.u_tid
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 144"
// Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1"
// ANALYSIS CANDIDATE IDS: W-8db679fc5012215d5484
// RAW BIN IDS: 8db679fc5012215d5484
Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-c5d2541e1341b3613326
// RAW BIN IDS: c5d2541e1341b3613326
Condition 1 "1953573688" "(result.q0_positive ? ((result.u0 - Q_ONE)) : ((result.u0 + Q_ONE))) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 148"
// Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1"
// ANALYSIS CANDIDATE IDS: W-bbc46a91227fdccc548b
// RAW BIN IDS: bbc46a91227fdccc548b
Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-d963f3cdc81fc914b305
// RAW BIN IDS: d963f3cdc81fc914b305
Condition 2 "3006289612" "(result.q0_positive ? e0_positive : e0_negative) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 156"
// Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1"
// ANALYSIS CANDIDATE IDS: W-2a3041a830ab4cac60b0
// RAW BIN IDS: 2a3041a830ab4cac60b0
Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-97813d9f5d8ea24e1714
// RAW BIN IDS: 97813d9f5d8ea24e1714
Condition 3 "3561519776" "(result.q0_positive ? u1_positive : u1_negative) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 158"
// Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1"
// ANALYSIS CANDIDATE IDS: W-30092f8de894fc57c94a
// RAW BIN IDS: 30092f8de894fc57c94a
Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-af75d090569b7268ce38
// RAW BIN IDS: af75d090569b7268ce38
Condition 4 "527959824" "(result.q1_positive ? ((result.u1 - Q_ONE)) : ((result.u1 + Q_ONE))) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 170"
// Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1"
// ANALYSIS CANDIDATE IDS: W-eb74b76dedbc17069352
// RAW BIN IDS: eb74b76dedbc17069352
Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-3df854e4d5acad4954e9
// RAW BIN IDS: 3df854e4d5acad4954e9
Condition 5 "2700207206" "((u0_check > 0) ? ((u0_check - q_one_wide)) : ((u0_check + q_one_wide))) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 173"
// Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1"
// ANALYSIS CANDIDATE IDS: W-cbbdc22bea4dcb68e993
// RAW BIN IDS: cbbdc22bea4dcb68e993
Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1" (1 "0")
// ANALYSIS CANDIDATE IDS: W-53b1039d234d6df53cad
// RAW BIN IDS: 53b1039d234d6df53cad
Condition 6 "2364900909" "((u1_check > 0) ? ((u1_check - q_one_wide)) : ((u1_check + q_one_wide))) 1 -1" (2 "1")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 180"
// Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1"
// ANALYSIS CANDIDATE IDS: W-282f6a27fa00f9b49c1c
// RAW BIN IDS: 282f6a27fa00f9b49c1c
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (1 "00000000")
// ANALYSIS CANDIDATE IDS: W-01349a622effb357d1f4
// RAW BIN IDS: 01349a622effb357d1f4
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (2 "00000001")
// ANALYSIS CANDIDATE IDS: W-51ccbf11b128b0100d55
// RAW BIN IDS: 51ccbf11b128b0100d55
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (3 "00000010")
// ANALYSIS CANDIDATE IDS: W-e6609cff4bb591ce23cb
// RAW BIN IDS: e6609cff4bb591ce23cb
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (4 "00000100")
// ANALYSIS CANDIDATE IDS: W-c4f57b97a499e9a90693
// RAW BIN IDS: c4f57b97a499e9a90693
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (5 "00001000")
// ANALYSIS CANDIDATE IDS: W-b98693b84fe5dfe439c0
// RAW BIN IDS: b98693b84fe5dfe439c0
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (6 "00010000")
// ANALYSIS CANDIDATE IDS: W-651abe641dfd9d3edf9b
// RAW BIN IDS: 651abe641dfd9d3edf9b
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (7 "00100000")
// ANALYSIS CANDIDATE IDS: W-2d6abf39cccca20e472e
// RAW BIN IDS: 2d6abf39cccca20e472e
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (8 "01000000")
// ANALYSIS CANDIDATE IDS: W-a6eb909a107429a0b413
// RAW BIN IDS: a6eb909a107429a0b413
Condition 7 "4113282234" "((u0_check < (-U_ABS_BOUND)) || (u0_check > U_ABS_BOUND) || (u1_check < (-U_ABS_BOUND)) || (u1_check > U_ABS_BOUND) || (e0_raw_check < (-E_RAW_ABS_BOUND)) || (e0_raw_check > E_RAW_ABS_BOUND) || (e1_raw_check < (-E_RAW_ABS_BOUND)) || (e1_raw_check > E_RAW_ABS_BOUND)) 1 -1" (9 "10000000")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 187"
// Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1"
// ANALYSIS CANDIDATE IDS: W-678501bf661ea331e2dd
// RAW BIN IDS: 678501bf661ea331e2dd
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (1 "00")
// ANALYSIS CANDIDATE IDS: W-8346a40b7dcd0c8cfc4d
// RAW BIN IDS: 8346a40b7dcd0c8cfc4d
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (2 "01")
// ANALYSIS CANDIDATE IDS: W-c61882ec3154b2c2c9bf
// RAW BIN IDS: c61882ec3154b2c2c9bf
Condition 8 "3793358804" "((result.e0_raw > STATE_MAX) || (result.e1_raw > STATE_MAX)) 1 -1" (3 "10")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 189"
// Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1"
// ANALYSIS CANDIDATE IDS: W-7048570142d3de113f57
// RAW BIN IDS: 7048570142d3de113f57
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (1 "00")
// ANALYSIS CANDIDATE IDS: W-ba09148cd149a52cbe6b
// RAW BIN IDS: ba09148cd149a52cbe6b
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (2 "01")
// ANALYSIS CANDIDATE IDS: W-0ae419541faf50d99931
// RAW BIN IDS: 0ae419541faf50d99931
Condition 9 "2511091053" "((result.e0_raw < STATE_MIN) || (result.e1_raw < STATE_MIN)) 1 -1" (3 "10")
//
ANNOTATION: "FileName: /home/ray/workspace/dsm_ip/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv, LineNumber: 329"
// Condition 10 "688901962" "(in_valid && in_ready) 1 -1"
// Condition 10 "688901962" "(in_valid && in_ready) 1 -1" (1 "01")
// Condition 10 "688901962" "(in_valid && in_ready) 1 -1" (2 "10")
// Condition 10 "688901962" "(in_valid && in_ready) 1 -1" (3 "11")
