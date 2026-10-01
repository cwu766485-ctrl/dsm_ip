`timescale 1ns/1ps
`default_nettype none

module tb_thermo5_i2_d1_axis_bittrue;
`ifdef THERMO5_XPM_FIFO
  localparam bit USE_XPM_FIFO=1'b1;
`else
  localparam bit USE_XPM_FIFO=1'b0;
`endif
  localparam int SRC_BEATS=32, CORE_WORDS=56, SAMPLES=448;
  logic src_clk=0, core_clk=0, src_rst_n=0, core_rst_n=0;
  logic src_valid=0, frame_start=0, core_enable=0;
  logic signed [223:0] src_i='0, src_q='0;
  logic signed [15:0] frame_gain=16'sd16384;
  logic [3:0] pa_ready=4'hf;
  wire src_ready, fifo_full, underflow, protocol_error;
  wire [3:0] pa_valid;
  wire [63:0] pa_data[0:3];
  logic [15:0] i_mem[0:SAMPLES-1], q_mem[0:SAMPLES-1];
  logic [15:0] frame_mem[0:CORE_WORDS-1], gain_mem[0:CORE_WORDS-1];
  logic [63:0] pa_mem[0:3][0:CORE_WORDS-1];
  integer sent=0, got=0, stalls=0, cycles=0;
  logic stalled=0;
  logic [63:0] held_data[0:3];

  always #4 src_clk=~src_clk;
  always #2.286 core_clk=~core_clk;

  tid32_thermo5_axis_frontend_tx #(
    .INTERP_TAPS(2),.DPD_MAX_TAPS(1),.BYPASS_DPD(1'b0),.FPGA_USE_XPM_FIFO(USE_XPM_FIFO)
  ) dut (
    .s_axis_aclk(src_clk),.s_axis_aresetn(src_rst_n),
    .s_axis_tvalid(src_valid),.s_axis_tready(src_ready),
    .s_axis_i_vec(src_i),.s_axis_q_vec(src_q),
    .s_axis_tuser_frame_start(frame_start),.s_axis_tuser_frame_gain(frame_gain),
    .s_axis_fifo_full(fifo_full),
    .core_clk(core_clk),.core_aresetn(core_rst_n),.core_enable(core_enable),
    .core_underflow(underflow),.core_protocol_error(protocol_error),
    .dpd_active_taps(3'd1),.c1_re(64'd16384),.c1_im(64'd0),
    .c3_re(64'd0),.c3_im(64'd0),.c5_re(64'd0),.c5_im(64'd0),
    .pa_valid(pa_valid),.pa_data(pa_data),.pa_ready(pa_ready)
  );

  initial begin
    $readmemh("tid32_thermo5_frontend_i.mem",i_mem);
    $readmemh("tid32_thermo5_frontend_q.mem",q_mem);
    $readmemh("tid32_thermo5_frontend_frame_start.mem",frame_mem);
    $readmemh("tid32_thermo5_frontend_frame_gain.mem",gain_mem);
    $readmemh("tid32_thermo5_frontend_pa0.mem",pa_mem[0]);
    $readmemh("tid32_thermo5_frontend_pa1.mem",pa_mem[1]);
    $readmemh("tid32_thermo5_frontend_pa2.mem",pa_mem[2]);
    $readmemh("tid32_thermo5_frontend_pa3.mem",pa_mem[3]);
    repeat(8) @(negedge src_clk); src_rst_n=1;
    repeat(8) @(negedge core_clk); core_rst_n=1;
    fork
      begin
        for (int beat=0; beat<SRC_BEATS; beat++) begin
          @(negedge src_clk);
          src_valid=1;
          frame_start=frame_mem[(14*beat)/8][0];
          frame_gain=gain_mem[(14*beat)/8];
          for (int lane=0;lane<14;lane++) begin
            src_i[lane*16+:16]=i_mem[14*beat+lane];
            src_q[lane*16+:16]=q_mem[14*beat+lane];
          end
          do @(posedge src_clk); while (!src_ready);
          sent++;
        end
        @(negedge src_clk); src_valid=0;
      end
      begin
        wait(sent>=4);
        @(negedge core_clk); core_enable=1;
        while(got<CORE_WORDS) @(posedge core_clk);
        @(negedge core_clk); core_enable=0;
        if(sent!=SRC_BEATS || protocol_error || (stalls==0 && $test$plusargs("STRESS_PA_READY")))
          $fatal(1,"closure sent=%0d/%0d protocol=%b stalls=%0d",sent,SRC_BEATS,protocol_error,stalls);
        $display("THERMO5_I2_D1_AXIS_BITTRUE_PASS source=%0d output=%0d stalls=%0d",sent,got,stalls);
        $finish;
      end
      begin
        repeat(10000) @(posedge core_clk);
        $fatal(1,"timeout sent=%0d got=%0d",sent,got);
      end
    join
  end

  always @(negedge core_clk) begin
    if(core_enable) pa_ready=$test$plusargs("STRESS_PA_READY") ?
                             (($urandom_range(0,3)==0) ? 4'h0 : 4'hf) : 4'hf;
  end
  always @(posedge core_clk) begin
    if(core_rst_n) begin
      if(stalled) begin
        if(pa_valid!==4'hf) $fatal(1,"valid dropped on output stall");
        for(int p=0;p<4;p++)
          if(pa_data[p]!==held_data[p]) $fatal(1,"plane%0d changed on stall",p);
      end
      if(pa_valid!==4'h0 && pa_valid!==4'hf) $fatal(1,"plane valid mismatch %b",pa_valid);
      stalled=(pa_valid==4'hf && pa_ready!=4'hf);
      if(stalled) begin
        stalls++;
        for(int p=0;p<4;p++) held_data[p]=pa_data[p];
      end
      if(pa_valid==4'hf && pa_ready==4'hf) begin
        if(got>=CORE_WORDS) $fatal(1,"extra output word");
        for(int p=0;p<4;p++)
          if(pa_data[p]!==pa_mem[p][got])
            $fatal(1,"word=%0d plane=%0d got=%h exp=%h",got,p,pa_data[p],pa_mem[p][got]);
        got++;
      end
    end
  end
endmodule

`default_nettype wire
