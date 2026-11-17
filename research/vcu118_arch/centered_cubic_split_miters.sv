`default_nettype none
// Compositional bit-vector checks for the exact 16-bit midpoint candidate.
module cubic_numerator_miter(input wire signed [15:0] a,b,c,d);
  logic signed [32:0] sa,sb,sc,sd,reference,extended;
  logic signed [20:0] aa,bb,cc,dd,middle,edges,numerator;
  always_comb begin
    sa={{17{a[15]}},a};sb={{17{b[15]}},b};sc={{17{c[15]}},c};sd={{17{d[15]}},d};
    reference=sa*(-33'sd1024)+sb*33'sd9216+sc*33'sd9216+sd*(-33'sd1024);
    aa={{5{a[15]}},a};bb={{5{b[15]}},b};cc={{5{c[15]}},c};dd={{5{d[15]}},d};
    middle=bb+cc;edges=aa+dd;numerator=(middle<<<3)+middle-edges;
    extended={{2{numerator[20]}},numerator,10'b0};
    assert(reference==extended);
  end
endmodule
module cubic_round_miter(input wire signed [20:0] numerator);
  logic signed [32:0] value,reference,hi,lo;
  logic signed [20:0] adjusted,candidate;
  logic signed [15:0] ref_sat,candidate_sat;
  always_comb begin
    value={{2{numerator[20]}},numerator,10'b0};
    if(value>=0)reference=(value+33'sd8192)>>>14;
    else reference=-(((-value)+33'sd8192)>>>14);
    adjusted=numerator+(numerator<0 ? 21'sd7 : 21'sd8);
    candidate=adjusted>>>4;
    hi=33'sd32767;lo=-33'sd32768;
    if(reference>hi)ref_sat=hi[15:0];else if(reference<lo)ref_sat=lo[15:0];else ref_sat=reference[15:0];
    if(candidate>21'sd32767)candidate_sat=16'sh7fff;else if(candidate< -21'sd32768)candidate_sat=16'sh8000;else candidate_sat=candidate[15:0];
    // Valid numerator magnitude is <= 655,360 for 16-bit inputs, so the
    // positive rounding addition cannot overflow its signed 21-bit carrier.
    if(numerator>= -21'sd655360 && numerator<=21'sd655360)assert(ref_sat==candidate_sat);
  end
endmodule
`default_nettype wire
