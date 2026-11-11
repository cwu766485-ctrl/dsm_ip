"""The final What-if may have no remaining line gaps; extraction must reconcile."""
import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import thermo5_coverage_denominator as denominator

class EmptyGapInventory(unittest.TestCase):
    def test_real_fully_excluded_line_metric(self):
        report=Path(__file__).resolve().parents[3]/'runs/pr55_exact/full_whatif/report'
        if not report.exists():self.skipTest('Local licensed URG fixture unavailable')
        totals,lines,branches=denominator.inventory(report)
        self.assertEqual([],lines)
        self.assertEqual(0,sum(r['missing'] for r in totals if r['metric']=='line'))
        self.assertEqual(2,len(branches))

if __name__=='__main__':unittest.main()
