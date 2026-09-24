`timescale 1ns/1ps
`default_nettype none

module tb_tid32_thermo5_frontend_tx_bittrue;
  localparam int W=16, LANES=8, WORDS=64;
  logic clk=1'b0, rst_n=1'b0, enable=1'b1, in_valid=1'b0, in_frame_start=1'b0;
  logic signed [W-1:0] in_frame_gain=16'sd16384;
  logic signed [LANES*W-1:0] in_i_vec='0, in_q_vec='0;
  logic [3:0] pa_ready='0;
  wire in_ready; wire [3:0] pa_valid; wire [63:0] pa_data[0:3];
  logic [W-1:0] i_mem[0:LANES*WORDS-1], q_mem[0:LANES*WORDS-1];
  logic [W-1:0] frame_start_mem[0:WORDS-1], frame_gain_mem[0:WORDS-1];
  logic [63:0] pa_mem[0:3][0:WORDS-1];
  logic signed [63:0] c1_re,c1_im,c3_re,c3_im,c5_re,c5_im;
  integer sent, got, lane, branch, errors, cycles;

  tid32_thermo5_frontend_tx #(.STEP(7168)) dut (
    .clk(clk),.rst_n(rst_n),.enable(enable),.in_valid(in_valid),.in_ready(in_ready),
    .in_frame_start(in_frame_start),.in_frame_gain(in_frame_gain),.in_i_vec(in_i_vec),.in_q_vec(in_q_vec),
    .dpd_active_taps(3'd1),.c1_re(c1_re),.c1_im(c1_im),.c3_re(c3_re),.c3_im(c3_im),.c5_re(c5_re),.c5_im(c5_im),
    .pa_valid(pa_valid),.pa_data(pa_data),.pa_ready(pa_ready)
  );
  always #5 clk=~clk;

  initial begin
    $readmemh("tid32_thermo5_frontend_i.mem",i_mem); $readmemh("tid32_thermo5_frontend_q.mem",q_mem);
    $readmemh("tid32_thermo5_frontend_frame_start.mem",frame_start_mem);
    $readmemh("tid32_thermo5_frontend_frame_gain.mem",frame_gain_mem);
    $readmemh("tid32_thermo5_frontend_pa0.mem",pa_mem[0]); $readmemh("tid32_thermo5_frontend_pa1.mem",pa_mem[1]);
    $readmemh("tid32_thermo5_frontend_pa2.mem",pa_mem[2]); $readmemh("tid32_thermo5_frontend_pa3.mem",pa_mem[3]);
    c1_re={48'sd0,16'sd16384}; c1_im='0; c3_re='0; c3_im='0; c5_re='0; c5_im='0;
    sent=0; got=0; errors=0; cycles=0;
    repeat(5) @(negedge clk); rst_n=1'b1;
    while(got<WORDS) begin
      @(negedge clk); cycles=cycles+1;
      if(cycles>6000) $fatal(1,"thermo5 frontend timeout sent=%0d got=%0d",sent,got);
      pa_ready=4'hf; in_valid=(sent<WORDS);
      if (sent < WORDS) begin
        in_frame_start=frame_start_mem[sent][0]; in_frame_gain=frame_gain_mem[sent];
        for(lane=0;lane<LANES;lane=lane+1) begin
          in_i_vec[lane*W+:W]=i_mem[sent*LANES+lane]; in_q_vec[lane*W+:W]=q_mem[sent*LANES+lane];
        end
      end else begin
        in_frame_start=1'b0; in_frame_gain=16'sd16384;
        in_i_vec='0; in_q_vec='0;
      end
    end
    in_valid=1'b0; pa_ready=4'hf;
    if(sent!=WORDS) $fatal(1,"accepted %0d/%0d inputs",sent,WORDS);
    if(errors!=0) $fatal(1,"thermo5 frontend mismatches=%0d",errors);
    $display("TID32_THERMO5_FRONTEND_BITTRUE_PASS words=%0d output_samples=%0d",WORDS,WORDS*32);
    $finish;
  end

  always @(posedge clk) begin
    if(!rst_n) begin sent<=0; got<=0; end else begin
      if(in_valid && in_ready) sent<=sent+1;
      if(pa_valid!==4'h0 && pa_valid!==4'hf) $fatal(1,"PA valid alignment failure: %b",pa_valid);
      if(pa_valid==4'hf && pa_ready==4'hf) begin
        for(branch=0;branch<4;branch=branch+1) begin
          if(pa_data[branch]!==pa_mem[branch][got]) begin
            $error("PA%0d mismatch word=%0d got=%h exp=%h",branch,got,pa_data[branch],pa_mem[branch][got]); errors<=errors+1;
          end
        end
        got<=got+1;
      end
    end
  end
endmodule

`default_nettype wire
