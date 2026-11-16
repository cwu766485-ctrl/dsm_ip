`timescale 1ns/1ps
`default_nettype none
module tb_weighted_mash_backend_adapter;
  localparam int W=16, L=32, N=128;
  logic clk=0, rst_n=0, in_valid=0, out_ready=0;
  logic signed [L*W-1:0] ii='0, qq='0;
  logic [15:0] cfg=0, epoch=7; logic fs=0, fe=0, tail=0;
  wire in_ready, out_valid, overflow_error;
  wire [2*L-1:0] s1,s2; wire [15:0] ocfg,oepoch; wire ofs,ofe,otail; wire [15:0] inflight;
  integer n, accepted=0, produced=0, cycles=0, errors=0;
  int unsigned expected_cfg[$];
  thermo5_weighted_mash_backend_adapter #(.FIFO_DEPTH(16)) dut(
    .clk,.rst_n,.in_valid,.in_ready,.in_i_poly_vec(ii),.in_q_poly_vec(qq),
    .in_config_id(cfg),.in_epoch(epoch),.in_frame_start(fs),.in_frame_end(fe),.in_tail(tail),
    .out_valid,.out_ready,.out_stage1_data(s1),.out_stage2_data(s2),.out_config_id(ocfg),.out_epoch(oepoch),
    .out_frame_start(ofs),.out_frame_end(ofe),.out_tail(otail),.overflow_error,.inflight_count(inflight));
  always #5 clk=~clk;
  always @(posedge clk) begin
    cycles <= cycles+1;
    if (rst_n && in_valid && in_ready) begin accepted=accepted+1; expected_cfg.push_back(cfg); end
    if (rst_n && out_valid && out_ready) begin
      if (oepoch !== 16'd7) errors=errors+1;
      if (expected_cfg.size()==0 || ocfg !== expected_cfg[0]) errors=errors+1;
      else expected_cfg.pop_front();
      produced=produced+1;
    end
  end
  initial begin
    repeat(3) @(negedge clk); rst_n=1;
    out_ready=1;
    for(n=0;n<N;n=n+1) begin
      @(negedge clk); in_valid=1; cfg=n; ii='0; qq='0; fs=(n==0); fe=(n==N-1); tail=(n==N-1);
      if (!in_ready) begin @(negedge clk); end
    end
    @(negedge clk); in_valid=0;
    repeat(12) begin @(negedge clk); out_ready = (cycles % 3 != 0); end
    out_ready=1;
    wait(produced==N);
    if (accepted!=N || errors!=0 || overflow_error) $fatal(1,"adapter failure accepted=%0d produced=%0d errors=%0d overflow=%0b",accepted,produced,errors,overflow_error);
    $display("THERMO5_MASH_ADAPTER_PASS accepted=%0d produced=%0d II=1 bounded_fifo=16",accepted,produced);
    $finish;
  end
endmodule
`default_nettype wire
