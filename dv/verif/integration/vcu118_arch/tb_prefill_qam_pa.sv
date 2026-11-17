`timescale 1ps/1fs
`default_nettype none
module tb_prefill_qam_pa;
  localparam int N=5264;
  logic clk=0,rst_n=0,run_request=0,in_valid=0,in_start=0,in_end=0;
  logic [255:0] in_data=0;
  logic [63:0] pa0[0:N-1],pa1[0:N-1];
  wire in_ready,drain_done,fault,overflow,link_fault,out_start,out_end,out_tail;
  wire [255:0] out_data;wire [3:0] out_mask;wire [15:0] out_cfg,out_epoch;wire [1:0] out_arch;
  integer sent=0,received=0,cycle=0,last_cycle=-1;
  string pa0_path,pa1_path;
  always #2285.714 clk=~clk;
  thermo5_frame_prefill_tx #(.MAX_FRAME_WORDS(N)) dut(.clk(clk),.rst_n(rst_n),.run_request(run_request),.link_ready(1'b1),
    .in_valid(in_valid),.in_ready(in_ready),.in_data(in_data),.in_mask(4'h3),.in_arch(2'd2),
    .in_start(in_start),.in_end(in_end),.in_tail(in_end),.in_config_id(16'h1234),.in_epoch(16'h0099),
    .gt_data(out_data),.pa_enable_mask(out_mask),.out_start(out_start),.out_end(out_end),.out_tail(out_tail),
    .out_arch(out_arch),.out_config_id(out_cfg),.out_epoch(out_epoch),.drain_done(drain_done),
    .protocol_fault(fault),.frame_overflow(overflow),.link_fault(link_fault));
  always @(posedge clk) if(rst_n) begin
    cycle=cycle+1;
    if(in_valid&&in_ready)sent=sent+1;
    if(out_mask!=0) begin
      if(sent!=N)$fatal(1,"frame emitted before complete prefill sent=%0d",sent);
      if(out_mask!==4'h3 || out_arch!==2 || out_cfg!==16'h1234 || out_epoch!==16'h0099 ||
         out_data[63:0]!==pa0[received] || out_data[127:64]!==pa1[received])
        $fatal(1,"PA or metadata mismatch word=%0d",received);
      if(out_start!==(received==0) || out_end!==(received==N-1) || out_tail!==out_end)
        $fatal(1,"frame marker mismatch word=%0d",received);
      if(last_cycle>=0 && cycle!=last_cycle+1)$fatal(1,"bubble in emitted QAM frame");
      last_cycle=cycle;received=received+1;
    end
    if(fault||overflow||link_fault)$fatal(1,"unexpected fault");
  end
  initial begin
    if(!$value$plusargs("PA0=%s",pa0_path) || !$value$plusargs("PA1=%s",pa1_path))$fatal(1,"PA0 and PA1 paths required");
    $readmemh(pa0_path,pa0);$readmemh(pa1_path,pa1);
    repeat(4)@(negedge clk);rst_n=1;run_request=1;
    for(int n=0;n<N;n++) begin
      if(n%37==9)begin @(negedge clk);in_valid=0;repeat(2)@(negedge clk);end
      @(negedge clk);in_valid=1;in_start=(n==0);in_end=(n==N-1);in_data={128'd0,pa1[n],pa0[n]};
      if(n==3000)run_request=0;
      do @(posedge clk);while(!in_ready);
    end
    @(negedge clk);in_valid=0;in_start=0;in_end=0;
    wait(received==N);repeat(2)@(negedge clk);
    if(!drain_done)$fatal(1,"STOP did not complete drain");
    $display("PREFILL_ACTUAL_RTL_QAM_PA_PASS words=%0d planes=2 input_bubbles=1 stop_mid_frame=1 output_bubbles=0",N);
    $finish;
  end
  initial begin #200000000;$fatal(1,"timeout");end
endmodule
`default_nettype wire
