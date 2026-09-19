`timescale 1ns/1ps
`default_nettype none

module tb_tid32_thermo3_frontend_tx_bittrue;
  localparam int W=16, LANES=8, WORDS=64;
  logic clk=1'b0, rst_n=1'b0, enable=1'b1, in_valid=1'b0;
  logic pa_p_ready=1'b0, pa_m_ready=1'b0;
  logic signed [LANES*W-1:0] in_i_vec='0, in_q_vec='0;
  wire in_ready, pa_p_valid, pa_m_valid;
  wire [63:0] pa_p_data, pa_m_data;
  logic [W-1:0] i_mem[0:LANES*WORDS-1], q_mem[0:LANES*WORDS-1];
  logic [63:0] p_mem[0:WORDS-1], m_mem[0:WORDS-1];
  logic signed [63:0] c1_re,c1_im,c3_re,c3_im,c5_re,c5_im;
  integer sent, got, lane, errors, cycles;

  tid32_thermo3_frontend_tx dut (
    .clk(clk),.rst_n(rst_n),.enable(enable),.in_valid(in_valid),.in_ready(in_ready),
    .in_i_vec(in_i_vec),.in_q_vec(in_q_vec),.dpd_active_taps(3'd4),
    .c1_re(c1_re),.c1_im(c1_im),.c3_re(c3_re),.c3_im(c3_im),.c5_re(c5_re),.c5_im(c5_im),
    .pa_p_valid(pa_p_valid),.pa_p_data(pa_p_data),.pa_p_ready(pa_p_ready),
    .pa_m_valid(pa_m_valid),.pa_m_data(pa_m_data),.pa_m_ready(pa_m_ready)
  );
  always #5 clk=~clk;

  initial begin
    $readmemh("tid32_frontend_i.mem",i_mem); $readmemh("tid32_frontend_q.mem",q_mem);
    $readmemh("tid32_frontend_pa_p.mem",p_mem); $readmemh("tid32_frontend_pa_m.mem",m_mem);
    c1_re={16'sd256,-16'sd640,16'sd1200,16'sd15000};
    c1_im={16'sd96,-16'sd192,16'sd320,-16'sd120};
    c3_re={-16'sd128,16'sd384,-16'sd800,16'sd4200};
    c3_im={16'sd64,-16'sd160,16'sd256,-16'sd900};
    c5_re={-16'sd48,16'sd128,-16'sd320,16'sd1800};
    c5_im={16'sd24,-16'sd64,16'sd160,-16'sd400};
    sent=0;got=0;errors=0;cycles=0;
    repeat(5) @(negedge clk); rst_n=1'b1;
    while (got < WORDS) begin
      @(negedge clk); cycles=cycles+1;
      if (cycles>5000) $fatal(1,"frontend timeout sent=%0d got=%0d",sent,got);
      // The raw-GTH path has a fixed 218.75-MHz cadence.  Production data
      // therefore must be continuous after start; an upstream underflow is a
      // framing fault, not a legal RF-stream backpressure event.
      pa_p_ready = 1'b1; pa_m_ready=1'b1;
      in_valid = (sent<WORDS);
      for (lane=0;lane<LANES;lane=lane+1) begin
        in_i_vec[lane*W+:W]=i_mem[sent*LANES+lane];
        in_q_vec[lane*W+:W]=q_mem[sent*LANES+lane];
      end
    end
    in_valid=1'b0; pa_p_ready=1'b1; pa_m_ready=1'b1;
    if(sent!=WORDS) $fatal(1,"frontend accepted %0d/%0d input words",sent,WORDS);
    if(errors!=0) $fatal(1,"frontend bit mismatches=%0d",errors);
    $display("TID32_THERMO3_FRONTEND_BITTRUE_PASS words=%0d output_samples=%0d",WORDS,WORDS*32);
    $finish;
  end

  always @(posedge clk) begin
    if(!rst_n) begin sent<=0;got<=0; end else begin
      if(in_valid && in_ready) sent<=sent+1;
      if(pa_p_valid!==pa_m_valid) $fatal(1,"PA valid alignment failure");
      if(pa_p_valid && pa_p_ready && pa_m_ready) begin
        if(pa_p_data!==p_mem[got]) begin $error("PA+ mismatch word=%0d got=%h exp=%h",got,pa_p_data,p_mem[got]); errors<=errors+1; end
        if(pa_m_data!==m_mem[got]) begin $error("PA- mismatch word=%0d got=%h exp=%h",got,pa_m_data,m_mem[got]); errors<=errors+1; end
        got<=got+1;
      end
    end
  end
endmodule

`default_nettype wire
