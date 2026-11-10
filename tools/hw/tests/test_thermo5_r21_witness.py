"""Keep same-line expression/subexpression bins separate."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))
import thermo5_r21_witness as witness


class ExactConditionTest(unittest.TestCase):
    def test_subexpression_does_not_borrow_expression_hit(self):
        row = dict(metric='cond', exact_urg_bin='337:1/0',
                   source_location='line:337:subexpression:1/0',
                   instance='dut', semantic_bin_id='target',
                   source_file='tools/hw/thermo5_r21_witness.py',
                   source_file_sha256=witness.digest(HERE/'thermo5_r21_witness.py'))
        parsed = [dict(instance='dut', line='337', operand_bin='1/0',
                       expression='EXPRESSION valid && sat', status='Covered'),
                  dict(instance='dut', line='337', operand_bin='1/0',
                       expression='SUB-EXPRESSION sat_i || sat_q', status='Not Covered')]
        with patch.object(witness.audit, 'condition_rows', return_value=(parsed, [], [], [])):
            self.assertEqual(witness.condition_hits([row], Path('/unused')), [])
        parsed[1]['status'] = 'Covered'
        with tempfile.TemporaryDirectory() as d:
            page = Path(d) / 'mod1.html'
            page.write_text('native report')
            parsed[1]['module_file'] = page.name
            with patch.object(witness.audit, 'condition_rows', return_value=(parsed, [], [], [])):
                result = witness.condition_hits([row], Path(d))
            self.assertEqual(result[0]['semantic_bin_id'], 'target')


if __name__ == '__main__':
    unittest.main()
