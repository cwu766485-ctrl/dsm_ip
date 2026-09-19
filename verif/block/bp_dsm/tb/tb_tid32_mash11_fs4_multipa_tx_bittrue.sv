`timescale 1ns/1ps
`default_nettype none

module tb_tid32_mash11_fs4_multipa_tx_bittrue;
  localparam int W=16, LANES=32, WORDS=128;
  logic clk=1'b0, rst_n=1'b0, in_valid=1'b0;
  logic signed [LANES*W-1:0] in_i_poly_vec='0, in_q_poly_vec='0;
  wire in_ready, pa_valid;
  wire [2*LANES-1:0] pa_stage1_data, pa_stage2_data;
  logic [W-1:0] i_mem[0:LANES*WORDS-1], q_mem[0:LANES*WORDS-1];
  logic pa1_mem[0:2*LANES*WORDS-1], pa2_mem[0:2*LANES*WORDS-1];
  integer n,lane,accepted,errors,timeout;

  tid32_mash11_fs4_multipa_tx #(.W(W),.CHANNELS(LANES)) dut (
    .clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_ready(in_ready),
    .in_i_poly_vec(in_i_poly_vec),.in_q_poly_vec(in_q_poly_vec),
    .pa_valid(pa_valid),.pa_stage1_data(pa_stage1_data),.pa_stage2_data(pa_stage2_data)
  );
  always #5 clk=~clk;
  initial begin
    $readmemh("tidmash_i.mem",i_mem); $readmemh("tidmash_q.mem",q_mem);
    $readmemh("tidmash_pa1.mem",pa1_mem); $readmemh("tidmash_pa2.mem",pa2_mem);
    accepted=0; errors=0;
    repeat(3) @(negedge clk); rst_n=1'b1;
    for(n=0;n<WORDS;n=n+1) begin
      @(negedge clk); if(!in_ready) $fatal(1,"Unexpected backpressure at word %0d",n);
      for(lane=0;lane<LANES;lane=lane+1) begin
        in_i_poly_vec[lane*W +: W]=i_mem[n*LANES+lane];
        in_q_poly_vec[lane*W +: W]=q_mem[n*LANES+lane];
      end
      in_valid=1'b1;
    end
    @(negedge clk); in_valid=1'b0; timeout=0;
    while(accepted<WORDS && timeout<32) begin @(negedge clk); timeout=timeout+1; end
    if(accepted!=WORDS) $fatal(1,"Received %0d PA words",accepted);
    if(errors!=0) $fatal(1,"TID-MASH bit-true mismatches=%0d",errors);
    $display("TID32_MASH11_FS4_MULTIPA_BITTRUE_PASS words=%0d samples=%0d",WORDS,WORDS*LANES);
    $finish;
  end
  always @(posedge clk) if(rst_n && pa_valid) begin
    for(lane=0;lane<2*LANES;lane=lane+1) begin
      if(pa_stage1_data[lane] !== pa1_mem[accepted*2*LANES+lane]) begin
        $error("PA1 mismatch word=%0d bit=%0d",accepted,lane); errors=errors+1;
      end
      if(pa_stage2_data[lane] !== pa2_mem[accepted*2*LANES+lane]) begin
        $error("PA2 mismatch word=%0d bit=%0d",accepted,lane); errors=errors+1;
      end
    end
    accepted=accepted+1;
  end
endmodule

`default_nettype wire
