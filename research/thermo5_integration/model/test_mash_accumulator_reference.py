import random
import unittest
from mash_accumulator_reference import scalar_stages


class AccumulatorMashIdentityTest(unittest.TestCase):
    def test_second_order_cancellation_identity_without_saturation(self):
        rng=random.Random(281001)
        samples=[(rng.randrange(-32768,32768),rng.randrange(-32768,32768)) for _ in range(4096)]
        q1,q2,_=scalar_stages(samples)
        r1=[0,0];r2=[0,0];r2_older=[0,0];q2_prev=[-32768,-32768]
        for n,x in enumerate(samples):
            for c in range(2):
                next_r1=r1[c]+x[c]-(2*q1[n][c]-1)*32768
                next_r2=r2[c]+next_r1-32768-(2*q2[n][c]-1)*32768
                self.assertTrue(0<=next_r1<65536)
                self.assertTrue(0<=next_r2<65536)
                reconstructed=(2*q1[n][c]-1)*32768+(2*q2[n][c]-1)*32768-q2_prev[c]
                self.assertEqual(reconstructed,x[c]+2*r2[c]-next_r2-r2_older[c])
                r1[c]=next_r1;r2_older[c]=r2[c];r2[c]=next_r2;q2_prev[c]=(2*q2[n][c]-1)*32768


if __name__=='__main__':unittest.main()
