`timescale 1ps/1fs
`default_nettype none
module tb_mash_ii;
  localparam int N=2048;
  logic clk=0,rst_n=0,in_valid=0,out_ready=1;
  wire in_ready,out_valid,overflow;
  logic [15:0] transaction_id=0;
  wire [15:0] out_id;
  wire [63:0] pa0,pa1;
  integer accepted=0,received=0,cycle=0,first_in=-1,first_out=-1,last_out=-1;
  always #2285.714 clk=~clk;
  thermo5_mash_backend dut(.clk(clk),.rst_n(rst_n),.stop_req(1'b0),.drain_done(),
    .in_valid(in_valid),.in_ready(in_ready),.in_i_poly_vec(512'd0),.in_q_poly_vec(512'd0),
    .in_config_id(transaction_id),.in_epoch(16'd1),.in_frame_start(1'b0),.in_frame_end(1'b0),.in_tail(1'b0),
    .out_valid(out_valid),.out_ready(out_ready),.out_stage1_data(),.out_stage2_data(),
    .out_pa0_data(pa0),.out_pa1_data(pa1),.out_config_id(out_id),.out_epoch(),
    .out_frame_start(),.out_frame_end(),.out_tail(),.overflow_error(overflow),.inflight_count());
  always @(posedge clk) if(rst_n) begin
    cycle=cycle+1;
    if(in_valid) begin
      if(!in_ready) $fatal(1,"input bubble cycle=%0d",cycle);
      if(first_in<0)first_in=cycle;
      accepted=accepted+1;
    end
    if(out_valid) begin
      if(first_out<0)first_out=cycle;
      if(last_out>=0 && cycle!=last_out+1) $fatal(1,"output bubble at word=%0d",received);
      if(out_id!==received[15:0])$fatal(1,"lost/reordered transaction output=%0d id=%0d",received,out_id);
      if((^pa0===1'bx)||(^pa1===1'bx))$fatal(1,"unknown PA bits");
      last_out=cycle;received=received+1;
    end
    if(overflow)$fatal(1,"overflow");
  end
  initial begin
    repeat(5) @(negedge clk);rst_n=1;
    for(int n=0;n<N;n++) begin @(negedge clk);in_valid=1;transaction_id=n;end
    @(negedge clk);in_valid=0;
    wait(received==N);@(negedge clk);
    if(accepted!=N || last_out-first_out+1!=N)$fatal(1,"count mismatch");
    $display("MASH_II_PASS words=%0d input_ii=1 output_ii=1 first_latency_cycles=%0d pa_width=64 lanes=2",N,first_out-first_in);
    $finish;
  end
  initial begin : optional_trace
    string path;
    if($value$plusargs("VCD=%s",path)) begin
      $dumpfile(path);
      $dumpvars(0,clk,rst_n,in_valid,in_ready,transaction_id,out_valid,out_ready,out_id,pa0,pa1,overflow);
    end
  end
  initial begin #100000000;$fatal(1,"timeout");end
endmodule
`default_nettype wire
