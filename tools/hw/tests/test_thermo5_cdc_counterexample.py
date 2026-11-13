"""Check that counterexample diagnostics cannot invent reset assumptions."""
import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[1] / 'thermo5_cdc_counterexample.py'
spec = importlib.util.spec_from_file_location('counterexample', path)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

HEADER = '''$timescale
1ps
$end
$var wire 1 a s_axil_aresetn $end
$var wire 1 b s_axis_aresetn $end
$var wire 1 c core_aresetn $end
$var wire 1 d tx_active_status_c $end
$enddefinitions $end
#0
1a
1b
1c
0d
#100
1d
#200
0d
#204
1d
'''


class Counterexample(unittest.TestCase):
    def test_real_pulse_and_reset_release(self):
        result = m.extract(HEADER)
        self.assertTrue(result['all_resets_observed_held_released'])
        self.assertEqual(result['timescale'], '1ps')
        self.assertEqual(result['bounded_status_pulses'][-1]['duration'], 4)
        self.assertEqual(result['disposition'], 'OPEN_REQUIRES_PROTOCOL_REVIEW')

    def test_runtime_reset_and_unknown_are_not_ignored(self):
        for value in ('0', 'x', 'z'):
            self.assertFalse(m.extract(HEADER + '#205\n' + value + 'a\n')[
                'all_resets_observed_held_released'])

    def test_missing_reset_is_not_proof(self):
        self.assertFalse(m.extract(HEADER.replace('1c\n', ''))[
            'all_resets_observed_held_released'])
