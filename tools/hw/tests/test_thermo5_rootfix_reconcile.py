import importlib.util
from pathlib import Path
import unittest
p=Path(__file__).resolve().parents[1]/'thermo5_rootfix_reconcile.py'
s=importlib.util.spec_from_file_location('rootfix',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class RootfixReconciliation(unittest.TestCase):
 def test_native_severity(self):
  rows=m.parse("[A] R alias SynthesisWarning rtl/x.sv 12 2 message\n[B] Ac_glitch03 Error rtl/y.sv 20 1 Destination flop 'top.s1' is driven by combinational logic",'cdc')
  self.assertEqual([r['severity'] for r in rows],['Warning','Error'])
  self.assertEqual(rows[1]['destination'],'top.s1')
 def test_original_exact(self):
  from thermo5_rdc_rootcause_audit import audit
  root=Path(__file__).resolve().parents[3]
  a=audit(root/'docs/verification/data/thermo5-cdc-phase2/static_messages.csv.gz')
  self.assertEqual(sum(r['count'] for r in a['root_groups'] if r['goal']=='rdc'),10525)
  self.assertEqual(len(a['glitch_targets']),5)
