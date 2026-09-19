`timescale 1ps/1fs
`default_nettype none

module tb_tid32_thermo5_frontend_serdes_loopback;
  localparam int W=16, LANES=8, WORDS=64;
  logic usr_clk=1'b0, ser_clk=1'b0, rst_n=1'b0, enable=1'b1;
  logic in_valid=1'b0, in_frame_start=1'b0;
  logic signed [W-1:0] in_frame_gain=16'sd16384;
  logic signed [LANES*W-1:0] in_i_vec='0, in_q_vec='0;
  wire in_ready; wire [3:0] pa_valid; wire [63:0] pa_data[0:3];
  wire [3:0] pa_ready, rx_valid; wire [63:0] rx_data[0:3];
  wire [3:0] serial_bit;
  logic [W-1:0] i_mem[0:LANES*WORDS-1], q_mem[0:LANES*WORDS-1];
  logic [W-1:0] frame_start_mem[0:WORDS-1], frame_gain_mem[0:WORDS-1];
  logic [63:0] pa_mem[0:3][0:WORDS-1];
  logic signed [63:0] c1_re,c1_im,c3_re,c3_im,c5_re,c5_im;
  integer sent, got[0:3], lane, branch, errors, cycles;

  // 218.75 MHz user clock and exact 64x 14-GHz raw serial clock.
  always #2285.714 usr_clk=~usr_clk;
  always #35.71428125 ser_clk=~ser_clk;

  tid32_thermo5_frontend_tx #(.STEP(7168)) dut (
    .clk(usr_clk),.rst_n(rst_n),.enable(enable),.in_valid(in_valid),.in_ready(in_ready),
    .in_frame_start(in_frame_start),.in_frame_gain(in_frame_gain),.in_i_vec(in_i_vec),.in_q_vec(in_q_vec),
    .dpd_active_taps(3'd1),.c1_re(c1_re),.c1_im(c1_im),.c3_re(c3_re),.c3_im(c3_im),.c5_re(c5_re),.c5_im(c5_im),
    .pa_valid(pa_valid),.pa_data(pa_data),.pa_ready(pa_ready)
  );

  genvar b;
  generate for (b=0;b<4;b=b+1) begin: g_serdes
    raw64_serializer_loopback_model #(.DATA_W(64)) u_serdes (
      .usr_clk(usr_clk),.ser_clk(ser_clk),.rst_n(rst_n),.tx_valid(pa_valid[b]),.tx_ready(pa_ready[b]),.tx_data(pa_data[b]),
      .serial_bit(serial_bit[b]),.rx_valid(rx_valid[b]),.rx_data(rx_data[b])
    );
  end endgenerate

  initial begin
    $readmemh("tid32_thermo5_frontend_i.mem",i_mem); $readmemh("tid32_thermo5_frontend_q.mem",q_mem);
    $readmemh("tid32_thermo5_frontend_frame_start.mem",frame_start_mem); $readmemh("tid32_thermo5_frontend_frame_gain.mem",frame_gain_mem);
    $readmemh("tid32_thermo5_frontend_pa0.mem",pa_mem[0]); $readmemh("tid32_thermo5_frontend_pa1.mem",pa_mem[1]);
    $readmemh("tid32_thermo5_frontend_pa2.mem",pa_mem[2]); $readmemh("tid32_thermo5_frontend_pa3.mem",pa_mem[3]);
    c1_re={48'sd0,16'sd16384}; c1_im='0; c3_re='0; c3_im='0; c5_re='0; c5_im='0;
    sent=0; errors=0; cycles=0; for(branch=0;branch<4;branch=branch+1) got[branch]=0;
    repeat(6) @(negedge usr_clk); rst_n=1'b1;
    while(got[0]<WORDS || got[1]<WORDS || got[2]<WORDS || got[3]<WORDS) begin
      @(negedge usr_clk); cycles=cycles+1;
      if(cycles>12000) $fatal(1,"serializer loopback timeout sent=%0d got0=%0d",sent,got[0]);
      if(sent<WORDS) begin
        in_valid=1'b1; in_frame_start=frame_start_mem[sent][0]; in_frame_gain=frame_gain_mem[sent];
        for(lane=0;lane<LANES;lane=lane+1) begin in_i_vec[lane*W+:W]=i_mem[sent*LANES+lane]; in_q_vec[lane*W+:W]=q_mem[sent*LANES+lane]; end
      end else begin in_valid=1'b0; in_frame_start=1'b0; in_frame_gain=16'sd16384; in_i_vec='0; in_q_vec='0; end
    end
    if(sent!=WORDS) $fatal(1,"accepted %0d/%0d inputs",sent,WORDS);
    if(errors!=0) $fatal(1,"serializer loopback mismatches=%0d",errors);
    $display("THERMO5_FOUR_PA_SERDES_LOOPBACK_PASS words=%0d bits_per_path=%0d",WORDS,WORDS*64);
    $finish;
  end

  always @(posedge usr_clk) if(rst_n && in_valid && in_ready) sent<=sent+1;
  always @(posedge ser_clk) if(rst_n) begin
    for(branch=0;branch<4;branch=branch+1) if(rx_valid[branch]) begin
      if(got[branch]>=WORDS || rx_data[branch]!==pa_mem[branch][got[branch]]) begin
        $error("SERDES loopback mismatch"); errors<=errors+1;
      end
      got[branch]<=got[branch]+1;
    end
  end
endmodule

`default_nettype wire
