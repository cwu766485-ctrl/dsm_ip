`timescale 1ps/1fs
`default_nettype none
module tb_runtime_backend_ii;
  localparam int N=2048;
  logic clk=0,rst_n=0,in_valid=0;
  logic [1:0] arch=0;
  logic [15:0] txid=0;
  wire in_ready;
  wire [3:0] valid,mask;
  wire [63:0] data[0:3];
  wire [15:0] outid,epoch;
  wire weighted,overflow;
  integer sent=0,got=0,cycle=0,first_in=-1,first_out=-1,last_out=-1;
  always #2285.714 clk=~clk;
  thermo5_runtime_dsm_backend dut(.clk(clk),.rst_n(rst_n),.reset_arch(1'b0),.arch(arch),
    .in_valid(in_valid),.in_ready(in_ready),.in_i_vec(512'd0),.in_q_vec(512'd0),
    .in_frame_start(1'b0),.in_frame_end(1'b0),.in_tail(1'b0),.in_config_id(txid),.in_epoch(16'h1234),
    .pa_valid(valid),.pa_ready(4'hf),.pa_data(data),.out_frame_start(),.out_frame_end(),.out_tail(),
    .out_config_id(outid),.out_epoch(epoch),.weighted_contract(weighted),.channel_mask(mask),.overflow_error(overflow));
  always @(posedge clk) if(rst_n) begin
    cycle=cycle+1;
    if(in_valid) begin
      if(!in_ready)$fatal(1,"arch=%0d input bubble cycle=%0d",arch,cycle);
      if(first_in<0)first_in=cycle;
      sent=sent+1;
    end
    if(valid!=0) begin
      if(valid!==(arch==2?4'h3:4'hf) || mask!==valid || weighted!==(arch==2))$fatal(1,"PA contract arch=%0d",arch);
      if(outid!==16'(got) || epoch!==16'h1234)$fatal(1,"transaction order arch=%0d word=%0d id=%0d",arch,got,outid);
      if(last_out>=0 && cycle!=last_out+1)$fatal(1,"output bubble arch=%0d word=%0d",arch,got);
      if(first_out<0)first_out=cycle;
      last_out=cycle;got=got+1;
    end
    if(overflow)$fatal(1,"overflow arch=%0d",arch);
  end
  initial begin
    for(int mode=0;mode<3;mode++) begin
      rst_n=0;in_valid=0;arch=2'(mode);sent=0;got=0;cycle=0;first_in=-1;first_out=-1;last_out=-1;
      repeat(5)@(negedge clk);rst_n=1;
      for(int n=0;n<N;n++) begin @(negedge clk);in_valid=1;txid=16'(n);end
      @(negedge clk);in_valid=0;
      wait(got==N);@(negedge clk);
      $display("RUNTIME_BACKEND_II_PASS arch=%0d words=%0d first_latency_cycles=%0d",mode,got,first_out-first_in);
    end
    $finish;
  end
  initial begin #200000000;$fatal(1,"runtime backend timeout");end
endmodule
`default_nettype wire
