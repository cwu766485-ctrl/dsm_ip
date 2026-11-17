`timescale 1ns/1ps
module midpoint_miter #(parameter int W=16, parameter int TESTS=100000)(output logic done=0);
  logic signed [W-1:0] a,b,c,d;
  wire signed [W-1:0] actual;
  dsm_interp_x2_centered_cubic_vector #(.W(W),.LANES(2)) dut();
  assign actual=dut.cubic_midpoint(a,b,c,d);
  function automatic logic signed [W-1:0] original(input logic signed [W-1:0] i,j,k,l);
    localparam int AW=W+17;
    logic signed [AW-1:0] si,sj,sk,sl,v,r,hi,lo;
    begin
      si={{(AW-W){i[W-1]}},i};sj={{(AW-W){j[W-1]}},j};
      sk={{(AW-W){k[W-1]}},k};sl={{(AW-W){l[W-1]}},l};
      v=-1024*si+9216*sj+9216*sk-1024*sl;
      if(v>=0)r=(v+8192)>>>14;else r=-(((-v)+8192)>>>14);
      hi=({{(AW-1){1'b0}},1'b1}<<<(W-1))-1;
      lo=-({{(AW-1){1'b0}},1'b1}<<<(W-1));
      if(r>hi)original=hi[W-1:0];else if(r<lo)original=lo[W-1:0];else original=r[W-1:0];
    end
  endfunction
  initial begin
    for(int n=0;n<TESTS;n++) begin
      if(W==4)begin a=W'(n);b=W'(n>>4);c=W'(n>>8);d=W'(n>>12);end
      else begin a=W'($urandom);b=W'($urandom);c=W'($urandom);d=W'($urandom);end
      #1;
      if(actual!==original(a,b,c,d))$fatal(1,"mismatch W=%0d n=%0d a=%0d b=%0d c=%0d d=%0d got=%0d expected=%0d",W,n,a,b,c,d,actual,original(a,b,c,d));
    end
    $display("CUBIC_CANDIDATE_BITTRUE_PASS W=%0d cases=%0d",W,TESTS);done=1;
  end
endmodule
module tb_centered_cubic_candidate;
  wire exhaustive_done,random_done;
  midpoint_miter #(.W(4),.TESTS(65536)) exhaustive(.done(exhaustive_done));
  midpoint_miter #(.W(16),.TESTS(100000)) random16(.done(random_done));
  initial begin wait(exhaustive_done&&random_done);$finish;end
endmodule
