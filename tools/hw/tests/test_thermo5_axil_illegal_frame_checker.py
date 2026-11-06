import unittest

from tools.hw.check_thermo5_axil_illegal_frame import (
    ExpectedNegativeCheckError,
    audit_log_text,
)


def valid_log() -> str:
    return '''
"rtl/axis/dsm_axis14_to_core8_cdc.sv", 262: thermo5_sku_uvm_tb.dut.u_cdc.unnamed$$_1: started at 171450ps failed at 171450ps
Error: "rtl/axis/dsm_axis14_to_core8_cdc.sv", 262: thermo5_sku_uvm_tb.dut.u_cdc.unnamed$$_1: at time 171450 ps
DSM frame_start was not aligned to a 56-sample boundary
THERMO5_AXIL_ILLEGAL_FRAME_OBSERVED early_tlast=1
"rtl/interp/dsm_interp_x2_centered_cubic_vector.sv", 310: thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1.unnamed$$_1: started at 322326ps failed at 322326ps
Error: "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv", 310: thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1.unnamed$$_1: at time 322326 ps
centered cubic frame-end vector was followed by same-frame data
"rtl/interp/dsm_interp_x2_centered_cubic_vector.sv", 310: thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2.unnamed$$_1: started at 395478ps failed at 395478ps
Error: "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv", 310: thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2.unnamed$$_1: at time 395478 ps
centered cubic frame-end vector was followed by same-frame data
THERMO5_AXIL_ILLEGAL_FRAME_UVM_PASS sticky error cleared by public reset
UVM_WARNING :    0
UVM_ERROR :    0
UVM_FATAL :    0
'''


class TestIllegalFrameLogChecker(unittest.TestCase):
    def test_exact_expected_assertions_and_reset_recovery_pass(self):
        result = audit_log_text(valid_log())
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(len(result["expected_rtl_assertion_failures"]), 3)

    def test_missing_stage2_assertion_fails_closed(self):
        text = valid_log().replace(
            '"rtl/interp/dsm_interp_x2_centered_cubic_vector.sv", 310: '
            'thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2.unnamed$$_1: '
            'started at 395478ps failed at 395478ps\n'
            'Error: "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv", 310: '
            'thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2.unnamed$$_1: '
            'at time 395478 ps\n'
            'centered cubic frame-end vector was followed by same-frame data\n',
            "",
        )
        with self.assertRaises(ExpectedNegativeCheckError):
            audit_log_text(text)

    def test_unexpected_rtl_assertion_fails_closed(self):
        text = valid_log() + (
            'Error: "rtl/unexpected.sv", 99: dut.unexpected: at time 1 ps\n'
        )
        with self.assertRaises(ExpectedNegativeCheckError):
            audit_log_text(text)

    def test_nonzero_uvm_error_fails_closed(self):
        with self.assertRaises(ExpectedNegativeCheckError):
            audit_log_text(valid_log().replace("UVM_ERROR :    0", "UVM_ERROR :    1"))


if __name__ == "__main__":
    unittest.main()
