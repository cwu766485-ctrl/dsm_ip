`timescale 1ns/1ps
`default_nettype none
module tb_bp_ef2_map_compose_id_pipe;
 localparam int ACC_W=28,MAP4=5,MAP8=9,TRANSACTIONS=24,MAX_Q=32;
`ifdef USE_CONTEXT_BANK
 localparam bit USE_CONTEXT_BANK=1'b1;
`else
 localparam bit USE_CONTEXT_BANK=1'b0;
`endif
 logic clk=0,rst_n=0,in_valid=0; logic signed [63:0] left_x='0,right_x='0;
 wire [MAP4-1:0] lv,ls,rv,rs; wire signed [MAP4*ACC_W-1:0] llo,lhi,lof,rlo,rhi,rof; wire [MAP4*4-1:0] lb,rb;
 wire pipe_valid; wire [MAP8-1:0] pv,ps,cv,cs; wire signed [MAP8*ACC_W-1:0] plo,phi,pof,clo,chi,cof; wire [MAP8*8-1:0] pb,cb;
 logic [MAP8-1:0] qv[0:MAX_Q-1],qs[0:MAX_Q-1]; logic signed [MAP8*ACC_W-1:0] qlo[0:MAX_Q-1],qhi[0:MAX_Q-1],qof[0:MAX_Q-1]; logic [MAP8*8-1:0] qb[0:MAX_Q-1];
 integer n,wr=0,rd=0,errors=0,cycle=0,quiet=0;
 bp_ef2_phase_map4 u_l(.x_vec(left_x),.region_valid(lv),.region_slope_neg(ls),.region_lo_bus(llo),.region_hi_bus(lhi),.region_offset_bus(lof),.region_bits_bus(lb));
 bp_ef2_phase_map4 u_r(.x_vec(right_x),.region_valid(rv),.region_slope_neg(rs),.region_lo_bus(rlo),.region_hi_bus(rhi),.region_offset_bus(rof),.region_bits_bus(rb));
 bp_ef2_map_compose u_ref(.l_valid(lv),.l_slope_neg(ls),.l_lo_bus(llo),.l_hi_bus(lhi),.l_offset_bus(lof),.l_bits_bus(lb),.r_valid(rv),.r_slope_neg(rs),.r_lo_bus(rlo),.r_hi_bus(rhi),.r_offset_bus(rof),.r_bits_bus(rb),.out_valid(cv),.out_slope_neg(cs),.out_lo_bus(clo),.out_hi_bus(chi),.out_offset_bus(cof),.out_bits_bus(cb));
 bp_ef2_map_compose_id_pipe #(.USE_CONTEXT_BANK(USE_CONTEXT_BANK)) u_dut(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.l_valid(lv),.l_slope_neg(ls),.l_lo_bus(llo),.l_hi_bus(lhi),.l_offset_bus(lof),.l_bits_bus(lb),.r_valid(rv),.r_slope_neg(rs),.r_lo_bus(rlo),.r_hi_bus(rhi),.r_offset_bus(rof),.r_bits_bus(rb),.out_valid(pipe_valid),.out_map_valid(pv),.out_slope_neg(ps),.out_lo_bus(plo),.out_hi_bus(phi),.out_offset_bus(pof),.out_bits_bus(pb));
 always #5 clk=~clk;
 task automatic set_inputs(input integer t); integer k; begin for(k=0;k<4;k=k+1) begin left_x[k*16 +:16]=((t*1733+k*7919+17)%65536)-32768; right_x[k*16 +:16]=((t*3571+k*4567+919)%65536)-32768; end end endtask
 initial begin repeat(3) @(negedge clk); rst_n=1; n=0; while(n<TRANSACTIONS) begin @(negedge clk); cycle=cycle+1; if((cycle%6)==2||(cycle%6)==3) begin in_valid=0; left_x='0; right_x='0; end else begin set_inputs(n); in_valid=1; #1; qv[wr]=cv; qs[wr]=cs; qlo[wr]=clo; qhi[wr]=chi; qof[wr]=cof; qb[wr]=cb; wr=wr+1; n=n+1; end end @(negedge clk); in_valid=0; repeat(80) @(negedge clk); if(rd!=TRANSACTIONS)$fatal(1,"lost outputs %0d/%0d",rd,TRANSACTIONS); if(errors)$fatal(1,"errors=%0d",errors); $display("BP_EF2_MAP_COMPOSE_ID_PIPE_PASS transactions=%0d context=%0d",TRANSACTIONS,USE_CONTEXT_BANK); $finish; end
 always @(posedge clk) begin #1; if(rst_n&&pipe_valid) begin if(rd>=wr||pv!==qv[rd]||ps!==qs[rd]||plo!==qlo[rd]||phi!==qhi[rd]||pof!==qof[rd]||pb!==qb[rd]) begin $error("id-pipe mismatch transaction=%0d context=%0d valid=%h/%h bits=%h/%h",rd,USE_CONTEXT_BANK,pv,qv[rd],pb,qb[rd]); errors=errors+1; end rd=rd+1; end end
endmodule
`default_nettype wire
