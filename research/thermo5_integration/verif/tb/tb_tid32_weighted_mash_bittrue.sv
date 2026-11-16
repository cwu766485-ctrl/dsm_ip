`timescale 1ns/1ps
`default_nettype none
module tb_tid32_weighted_mash_bittrue;
  localparam int W=16, L=32, WORDS=128;
  logic clk=0, rst_n=0, in_valid=0;
  logic signed [L*W-1:0] in_i='0, in_q='0;
  wire in_ready, raw_valid, enc_ready, pa_valid;
  wire [2*L-1:0] raw_s1, raw_s2, pa0, pa1;
  logic [W-1:0] i_mem[0:L*WORDS-1], q_mem[0:L*WORDS-1];
  logic [63:0] pa0_mem[0:WORDS-1], pa1_mem[0:WORDS-1];
  integer n, lane, accepted=0, produced=0, errors=0, cycles=0;
  integer first_accept=-1, first_output=-1, previous_output=-1;

  tid32_mash11_fs4_multipa_tx #(.W(W),.CHANNELS(L)) u_mash(
    .clk,.rst_n,.in_valid,.in_ready,.in_i_poly_vec(in_i),.in_q_poly_vec(in_q),
    .pa_valid(raw_valid),.pa_stage1_data(raw_s1),.pa_stage2_data(raw_s2));
  thermo5_weighted_mash_encoder #(.CHANNELS(L)) u_encoder(
    .clk,.rst_n,.in_valid(raw_valid),.in_ready(enc_ready),
    .in_stage1_data(raw_s1),.in_stage2_data(raw_s2),.out_valid(pa_valid),
    .out_ready(1'b1),.out_pa0_data(pa0),.out_pa1_data(pa1));
  always #5 clk=~clk;

  always @(posedge clk) begin
    cycles=cycles+1;
    if(rst_n && in_valid && in_ready) begin
      if(first_accept<0) first_accept=cycles;
      accepted=accepted+1;
    end
    if(rst_n && pa_valid) begin
      if(first_output<0) first_output=cycles;
      if(previous_output>=0 && cycles-previous_output!=1) errors=errors+1;
      previous_output=cycles;
      if(pa0 !== pa0_mem[produced] || pa1 !== pa1_mem[produced]) begin
        $error("weighted PA mismatch word=%0d",produced); errors=errors+1;
      end
      produced=produced+1;
    end
  end

  initial begin
    $readmemh("tidmash_i.mem",i_mem);
    $readmemh("tidmash_q.mem",q_mem);
    $readmemh("weighted_pa0.mem",pa0_mem);
    $readmemh("weighted_pa1.mem",pa1_mem);
    repeat(3) @(negedge clk); rst_n=1;
    for(n=0;n<WORDS;n=n+1) begin
      @(negedge clk);
      if(!in_ready) $fatal(1,"unexpected source stall at vector %0d",n);
      for(lane=0;lane<L;lane=lane+1) begin
        in_i[lane*W +: W]=i_mem[n*L+lane];
        in_q[lane*W +: W]=q_mem[n*L+lane];
      end
      in_valid=1;
    end
    @(negedge clk); in_valid=0;
    wait(produced==WORDS);
    if(accepted!=WORDS || errors!=0)
      $fatal(1,"weighted miter accepted=%0d produced=%0d errors=%0d",accepted,produced,errors);
    $display("THERMO5_TID32_WEIGHTED_MASH_BITTRUE_PASS accepted=%0d produced=%0d latency=%0d II=1",accepted,produced,first_output-first_accept);
    $finish;
  end
endmodule
`default_nettype wire
