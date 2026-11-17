`timescale 1ns/1ps
`default_nettype none
// Research candidate for the fixed Q14 centered-cubic coefficients only.
// The original numerator is 1024*(-xm1 + 9*x0 + 9*xp1 - xp2).
// No registered latency or production integration is implied.
module centered_cubic_midpoint_candidate #(parameter int W=16)(
  input wire logic signed [W-1:0] xm1,x0,xp1,xp2,
  output logic signed [W-1:0] result
);
  localparam int NW=W+5;
  logic signed [NW-1:0] a,b,c,d,middle,edges,numerator,adjusted,rounded,maxv,minv;
  always_comb begin
    a={{(NW-W){xm1[W-1]}},xm1}; b={{(NW-W){x0[W-1]}},x0};
    c={{(NW-W){xp1[W-1]}},xp1}; d={{(NW-W){xp2[W-1]}},xp2};
    middle=b+c; edges=a+d;
    numerator=(middle <<< 3)+middle-edges;
    // Arithmetic right shift floors negative numbers; +7 reproduces ties
    // away from zero, while positive numbers require +8.
    adjusted=numerator+(numerator<0 ? NW'(7) : NW'(8));
    rounded=adjusted >>> 4;
    maxv=({{(NW-1){1'b0}},1'b1} <<< (W-1))-1;
    minv=-({{(NW-1){1'b0}},1'b1} <<< (W-1));
    if(rounded>maxv)result=maxv[W-1:0];
    else if(rounded<minv)result=minv[W-1:0];
    else result=rounded[W-1:0];
  end
  initial if(W<2)$error("W must be at least 2");
endmodule
`default_nettype wire
