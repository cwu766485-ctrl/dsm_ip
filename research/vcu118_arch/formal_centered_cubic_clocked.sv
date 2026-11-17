`default_nettype none
// Combinational equivalence against the exact original W=16/Q14 arithmetic.
module formal_centered_cubic_clocked(input wire clk, input wire signed [15:0] a,b,c,d);
  wire signed [15:0] candidate;
  logic signed [32:0] sa,sb,sc,sd,value,rounded,maxv,minv;
  logic signed [15:0] reference;
  centered_cubic_midpoint_candidate #(.W(16)) u_candidate(.xm1(a),.x0(b),.xp1(c),.xp2(d),.result(candidate));
  always_comb begin
    sa={{17{a[15]}},a};sb={{17{b[15]}},b};sc={{17{c[15]}},c};sd={{17{d[15]}},d};
    value=sa*(-33'sd1024)+sb*33'sd9216+sc*33'sd9216+sd*(-33'sd1024);
    if(value>=0)rounded=(value+33'sd8192)>>>14;
    else rounded=-(((-value)+33'sd8192)>>>14);
    maxv=33'sd32767;minv=-33'sd32768;
    if(rounded>maxv)reference=maxv[15:0];
    else if(rounded<minv)reference=minv[15:0];
    else reference=rounded[15:0];
  end
  a_midpoint_equivalent: assert property (@(posedge clk) candidate==reference);
endmodule
`default_nettype wire
