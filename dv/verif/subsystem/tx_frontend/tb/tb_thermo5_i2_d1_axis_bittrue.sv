`timescale 1ns/1ps
`default_nettype none

module tb_thermo5_i2_d1_axis_bittrue #(
`ifdef THERMO5_LONG_1008
  parameter int CORE_WORDS = 1008
`else
  parameter int CORE_WORDS = 56
`endif
);
`ifdef THERMO5_XPM_FIFO
  localparam bit USE_XPM_FIFO=1'b1;
`else
  localparam bit USE_XPM_FIFO=1'b0;
`endif
  localparam int SRC_BEATS=(CORE_WORDS*4)/7, SAMPLES=CORE_WORDS*8;
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
  integer interp1_empty_blocked_hits=0;
  integer probe_gap=80, probe_beat=16, probe_stall_start=45, probe_stall_length=40;
  logic stalled=0;
  logic [63:0] held_data[0:3];
  wire [31:0] dpd_sample_count[0:15], dpd_saturation_count[0:15];

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
  for (genvar lane=0;lane<16;lane++) begin : g_dpd_observe
    assign dpd_sample_count[lane] =
      dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[lane].u_dpd.sample_count;
    assign dpd_saturation_count[lane] =
      dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[lane].u_dpd.saturation_count;
  end

  initial begin
    void'($value$plusargs("PROBE_GAP=%d",probe_gap));
    void'($value$plusargs("PROBE_BEAT=%d",probe_beat));
    void'($value$plusargs("PROBE_STALL_START=%d",probe_stall_start));
    void'($value$plusargs("PROBE_STALL_LENGTH=%d",probe_stall_length));
    if (CORE_WORDS < 7 || CORE_WORDS % 7 != 0)
      $fatal(1,"CORE_WORDS must be a positive multiple of seven");
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
          if ($test$plusargs("INTERP1_GAP_STALL") && beat==probe_beat-1) begin
            // Legal AXI-stream bubble after four complete accepted beats.
            @(negedge src_clk); src_valid=0;
            repeat(probe_gap) @(negedge src_clk);
          end
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
        for (int lane=0;lane<16;lane++)
          if (dpd_sample_count[lane] !== CORE_WORDS || dpd_saturation_count[lane] !== 0)
            $fatal(1,"DPD lane%0d count=%0d/%0d saturation=%0d",
                   lane,dpd_sample_count[lane],CORE_WORDS,dpd_saturation_count[lane]);
        if ($test$plusargs("INTERP1_GAP_STALL") && interp1_empty_blocked_hits==0)
          $fatal(1,"interp1 empty/blocked condition was not reached");
        if ($test$plusargs("INTERP1_GAP_STALL"))
          $display("THERMO5_INTERP1_EMPTY_BLOCKED_COUNT hits=%0d",interp1_empty_blocked_hits);
        $display("THERMO5_I2_D1_AXIS_BITTRUE_PASS source=%0d output=%0d stalls=%0d",sent,got,stalls);
        $finish;
      end
      begin
        repeat(2*CORE_WORDS+10000) @(posedge core_clk);
        $fatal(1,"timeout sent=%0d got=%0d",sent,got);
      end
    join
  end

  always @(negedge core_clk) begin
    if(core_enable) begin
      if ($test$plusargs("INTERP1_GAP_STALL") && cycles>=probe_stall_start && cycles<probe_stall_start+probe_stall_length)
        pa_ready=4'h0;
      else
        pa_ready=$test$plusargs("STRESS_PA_READY") ?
                 (($urandom_range(0,3)==0) ? 4'h0 : 4'hf) : 4'hf;
    end
  end
  always @(posedge core_clk) begin
    if(core_rst_n) begin
      cycles++;
      if ($test$plusargs("TRACE_INTERP") && core_enable && cycles<180)
        $display("I1_TRACE cycle=%0d sent=%0d ready=%h i1=%b%b%b%b i1outready=%b i1s2ready=%b i2=%b%b%b%b got=%0d",cycles,sent,pa_ready,
          dut.u_frontend.u_interp_1.s0_valid,dut.u_frontend.u_interp_1.s1_valid,
          dut.u_frontend.u_interp_1.s2_valid,dut.u_frontend.u_interp_1.out_valid,
          dut.u_frontend.u_interp_1.out_ready,dut.u_frontend.u_interp_1.s2_ready,
          dut.u_frontend.u_interp_2.s0_valid,dut.u_frontend.u_interp_2.s1_valid,
          dut.u_frontend.u_interp_2.s2_valid,dut.u_frontend.u_interp_2.out_valid,got);
      if ($test$plusargs("INTERP1_GAP_STALL") && core_enable &&
          !dut.u_frontend.u_interp_1.s1_valid &&
          !dut.u_frontend.u_interp_1.s2_ready) begin
        interp1_empty_blocked_hits++;
        if (interp1_empty_blocked_hits==1)
          $display("THERMO5_INTERP1_EMPTY_BLOCKED_HIT cycle=%0d u_interp_1.s1_valid=%b s2_ready=%b",cycles,
                   dut.u_frontend.u_interp_1.s1_valid,dut.u_frontend.u_interp_1.s2_ready);
      end
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
