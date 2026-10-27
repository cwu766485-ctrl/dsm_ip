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
`ifdef THERMO5_CENTERED_CUBIC
  localparam bit USE_CENTERED_CUBIC=1'b1;
`else
  localparam bit USE_CENTERED_CUBIC=1'b0;
`endif
`ifdef THERMO5_TIDSM_ORDER_2
  localparam int TIDSM_ORDER=2;
`else
  localparam int TIDSM_ORDER=1;
`endif
`ifdef THERMO5_STEP_5120
  localparam int TIDSM_STEP=5120;
`else
  localparam int TIDSM_STEP=7168;
`endif
  localparam int SRC_BEATS=(CORE_WORDS*4)/7, SAMPLES=CORE_WORDS*8;
  logic src_clk=0, core_clk=0, src_rst_n=0, core_rst_n=0;
  logic axil_clk=0;
  logic axil_rst_n=0;
  logic src_valid=0, src_last=0, frame_start=0, core_enable=0;
  logic signed [223:0] src_i='0, src_q='0;
  logic signed [15:0] frame_gain=16'sd16384;
  logic [3:0] pa_ready=4'hf;
  logic [7:0] axil_awaddr='0, axil_araddr='0;
  logic axil_awvalid=0, axil_wvalid=0, axil_bready=0;
  logic axil_arvalid=0, axil_rready=0;
  logic [31:0] axil_wdata='0;
  logic [3:0] axil_wstrb=4'hf;
  wire axil_awready, axil_wready, axil_bvalid, axil_arready, axil_rvalid;
  wire [1:0] axil_bresp, axil_rresp;
  wire [31:0] axil_rdata;
  wire cfg_busy, cfg_done, cfg_error;
  wire [2:0] dpd_active_taps_probe;
  wire dpd_config_boundary_probe;
  wire src_ready, fifo_full, underflow, protocol_error;
  wire [3:0] pa_valid;
  wire [63:0] pa_data[0:3];
  logic [15:0] i_mem[0:SAMPLES-1], q_mem[0:SAMPLES-1];
  logic [15:0] frame_mem[0:CORE_WORDS-1], gain_mem[0:CORE_WORDS-1];
  logic [63:0] pa_mem[0:3][0:CORE_WORDS-1];
  integer sent=0, got=0, stalls=0, cycles=0;
  integer expected_dpd_samples=0;
  integer interp1_empty_blocked_hits=0;
  integer probe_gap=80, probe_beat=16, probe_stall_start=45, probe_stall_length=40;
  logic [1:0] axil_response;
  logic [31:0] axil_status;
  bit axil_boundary_seen;
  logic stalled=0;
  logic [63:0] held_data[0:3];
  wire [31:0] dpd_sample_count[0:15], dpd_saturation_count[0:15];

  always #4 src_clk=~src_clk;
  always #2.286 core_clk=~core_clk;
  always #5 axil_clk=~axil_clk;
  // Common assertion epoch with reset deassertion synchronized to axil_clk.
  always_ff @(posedge axil_clk or negedge core_rst_n) begin
    if (!core_rst_n) axil_rst_n <= 1'b0;
    else axil_rst_n <= 1'b1;
  end

`ifdef THERMO5_AXIL_CONTROL
  tid32_thermo5_axi_lite_axis_frontend_tx #(
    .STEP(TIDSM_STEP),.TIDSM_ORDER(TIDSM_ORDER),
    .INTERP_TAPS(2),.INTERP_CENTERED_CUBIC(USE_CENTERED_CUBIC),
    .DPD_MAX_TAPS(4),.BYPASS_DPD(1'b0),.FPGA_USE_XPM_FIFO(USE_XPM_FIFO)
  ) dut (
    .s_axil_aclk(axil_clk),.s_axil_aresetn(axil_rst_n),
    .s_axil_awaddr(axil_awaddr),.s_axil_awvalid(axil_awvalid),.s_axil_awready(axil_awready),
    .s_axil_wdata(axil_wdata),.s_axil_wstrb(axil_wstrb),.s_axil_wvalid(axil_wvalid),.s_axil_wready(axil_wready),
    .s_axil_bresp(axil_bresp),.s_axil_bvalid(axil_bvalid),.s_axil_bready(axil_bready),
    .s_axil_araddr(axil_araddr),.s_axil_arvalid(axil_arvalid),.s_axil_arready(axil_arready),
    .s_axil_rdata(axil_rdata),.s_axil_rresp(axil_rresp),.s_axil_rvalid(axil_rvalid),.s_axil_rready(axil_rready),
    .s_axis_aclk(src_clk),.s_axis_aresetn(src_rst_n),
    .s_axis_tvalid(src_valid),.s_axis_tready(src_ready),.s_axis_tlast(src_last),
    .s_axis_i_vec(src_i),.s_axis_q_vec(src_q),
    .s_axis_tuser_frame_start(frame_start),.s_axis_tuser_frame_gain(frame_gain),
    .s_axis_fifo_full(fifo_full),.core_clk(core_clk),.core_aresetn(core_rst_n),
    .core_underflow(underflow),.core_protocol_error(protocol_error),
    .pa_valid(pa_valid),.pa_data(pa_data),.pa_ready(pa_ready),
    .cfg_busy(cfg_busy),.cfg_done(cfg_done),.cfg_error(cfg_error)
  );
  assign dpd_active_taps_probe=dut.dpd_active_taps;
  assign dpd_config_boundary_probe=dut.dpd_config_boundary;
`else
  tid32_thermo5_axis_frontend_tx #(
    .STEP(TIDSM_STEP),.TIDSM_ORDER(TIDSM_ORDER),
    .INTERP_TAPS(2),.INTERP_CENTERED_CUBIC(USE_CENTERED_CUBIC),
    .DPD_MAX_TAPS(1),.BYPASS_DPD(1'b0),.FPGA_USE_XPM_FIFO(USE_XPM_FIFO)
  ) dut (
    .s_axis_aclk(src_clk),.s_axis_aresetn(src_rst_n),
    .s_axis_tvalid(src_valid),.s_axis_tready(src_ready),
    .s_axis_tlast(USE_CENTERED_CUBIC ? src_last : 1'b0),
    .s_axis_i_vec(src_i),.s_axis_q_vec(src_q),
    .s_axis_tuser_frame_start(frame_start),.s_axis_tuser_frame_gain(frame_gain),
    .s_axis_fifo_full(fifo_full),
    .core_clk(core_clk),.core_aresetn(core_rst_n),.core_enable(core_enable),
    .core_underflow(underflow),.core_protocol_error(protocol_error),
    .dpd_active_taps(3'd1),.c1_re(64'd16384),.c1_im(64'd0),
    .c3_re(64'd0),.c3_im(64'd0),.c5_re(64'd0),.c5_im(64'd0),
    .pa_valid(pa_valid),.pa_data(pa_data),.pa_ready(pa_ready)
  );
  assign axil_awready=1'b0; assign axil_wready=1'b0; assign axil_bvalid=1'b0;
  assign axil_bresp=2'b00; assign axil_arready=1'b0; assign axil_rvalid=1'b0;
  assign axil_rresp=2'b00; assign axil_rdata=32'd0;
  assign cfg_busy=1'b0; assign cfg_done=1'b0; assign cfg_error=1'b0;
  assign dpd_active_taps_probe=3'd1; assign dpd_config_boundary_probe=1'b0;
`endif
  for (genvar lane=0;lane<16;lane++) begin : g_dpd_observe
    assign dpd_sample_count[lane] =
      dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[lane].u_dpd.sample_count;
    assign dpd_saturation_count[lane] =
      dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[lane].u_dpd.saturation_count;
  end

  task automatic axil_write(input logic [7:0] addr, input logic [31:0] data,
                            input int unsigned aw_gap, input int unsigned w_gap,
                            output logic [1:0] response);
    fork
      begin
        repeat (aw_gap) @(negedge axil_clk);
        axil_awaddr=addr; axil_awvalid=1'b1;
        do @(posedge axil_clk); while (!axil_awready);
        @(negedge axil_clk); axil_awvalid=1'b0;
      end
      begin
        repeat (w_gap) @(negedge axil_clk);
        axil_wdata=data; axil_wstrb=4'hf; axil_wvalid=1'b1;
        do @(posedge axil_clk); while (!axil_wready);
        @(negedge axil_clk); axil_wvalid=1'b0;
      end
    join
    @(negedge axil_clk); axil_bready=1'b1;
    do @(posedge axil_clk); while (!axil_bvalid);
    response=axil_bresp;
    @(negedge axil_clk); axil_bready=1'b0;
  endtask

  task automatic axil_read(input logic [7:0] addr,
                           output logic [31:0] data, output logic [1:0] response);
    @(negedge axil_clk); axil_araddr=addr; axil_arvalid=1'b1;
    do @(posedge axil_clk); while (!axil_arready);
    @(negedge axil_clk); axil_arvalid=1'b0; axil_rready=1'b1;
    do @(posedge axil_clk); while (!axil_rvalid);
    data=axil_rdata; response=axil_rresp;
    @(negedge axil_clk); axil_rready=1'b0;
  endtask

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
    expected_dpd_samples=CORE_WORDS;
`ifdef THERMO5_CENTERED_CUBIC
    // The first centered stage injects one look-ahead-only tail vector per
    // source frame. It is consumed by DPD but must not become an extra PA word.
    for (integer frame_index=0;frame_index<CORE_WORDS;frame_index++)
      if (frame_mem[frame_index][0]) expected_dpd_samples++;
`endif
    repeat(8) @(negedge src_clk); src_rst_n=1;
    repeat(8) @(negedge core_clk); core_rst_n=1;
    fork
      begin
        for (int beat=0; beat<SRC_BEATS; beat++) begin
          @(negedge src_clk);
          src_valid=1;
          src_last=(beat==SRC_BEATS-1);
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
        @(negedge src_clk); src_valid=0; src_last=0;
      end
      begin
        wait(sent>=4);
`ifdef THERMO5_AXIL_CONTROL
        axil_read(8'h0c,axil_status,axil_response);
        if(axil_response!=2'b00 || axil_status!=32'h5448_3501) $fatal(1,"AXI-Lite ID read failed");
        axil_write(8'h08,32'd0,0,2,axil_response);
        axil_write(8'h00,32'h2,3,0,axil_response);
        if(axil_response!=2'b10) $fatal(1,"Illegal tap count did not return SLVERR");
        axil_read(8'h04,axil_status,axil_response);
        if(axil_response!=2'b00 || axil_status[2:0]!=3'b100) $fatal(1,"ERROR status did not latch");
        axil_write(8'h04,32'h4,0,1,axil_response);
        axil_write(8'h08,32'd2,0,3,axil_response);
        axil_write(8'h10,32'h0000_4000,2,0,axil_response);
        axil_write(8'h14,32'd0,0,2,axil_response);
        axil_write(8'h00,32'h2,0,3,axil_response);
        if(axil_response!=2'b00 || !cfg_busy || cfg_done || cfg_error ||
           dpd_active_taps_probe!=3'd1 || dpd_config_boundary_probe)
          $fatal(1,"Commit did not remain pending before the frame boundary");
        axil_write(8'h00,32'h1,2,0,axil_response);
        if(axil_response!=2'b00) $fatal(1,"run_request write failed");
        core_enable=1;
        axil_boundary_seen=0;
        for(int wait_cycle=0;wait_cycle<2000 && !axil_boundary_seen;wait_cycle++) begin
          @(posedge core_clk);
          if(dpd_config_boundary_probe && dpd_active_taps_probe==3'd2)
            axil_boundary_seen=1;
        end
        if(!axil_boundary_seen) $fatal(1,"Config was not selected at a marked DPD input handshake");
        @(posedge core_clk);
        if(dpd_active_taps_probe!=3'd2) $fatal(1,"Applied config did not remain active");
        while(got<CORE_WORDS) @(posedge core_clk);
        repeat(6) @(posedge axil_clk);
        axil_read(8'h04,axil_status,axil_response);
        if(axil_response!=2'b00 || axil_status[2:0]!=3'b010)
          $fatal(1,"Expected DONE/no BUSY/no ERROR, status=%08h",axil_status);
        if(sent!=SRC_BEATS || protocol_error || (stalls==0 && $test$plusargs("STRESS_PA_READY")))
          $fatal(1,"closure sent=%0d/%0d protocol=%b stalls=%0d",sent,SRC_BEATS,protocol_error,stalls);
        for(int lane=0;lane<16;lane++)
          if(dpd_sample_count[lane]!==CORE_WORDS || dpd_saturation_count[lane]!==0)
            $fatal(1,"DPD lane%0d count=%0d/%0d saturation=%0d",lane,dpd_sample_count[lane],CORE_WORDS,dpd_saturation_count[lane]);
        axil_write(8'h00,32'd0,0,0,axil_response);
        core_enable=0;
        $display("THERMO5_AXIL_CONFIG_BITTRUE_PASS source=%0d output=%0d taps=%0d identity=1",sent,got,dpd_active_taps_probe);
        $finish;
`else
        @(negedge core_clk); core_enable=1;
        while(got<CORE_WORDS) @(posedge core_clk);
        @(negedge core_clk); core_enable=0;
        if(sent!=SRC_BEATS || protocol_error || (stalls==0 && $test$plusargs("STRESS_PA_READY")))
          $fatal(1,"closure sent=%0d/%0d protocol=%b stalls=%0d",sent,SRC_BEATS,protocol_error,stalls);
        for (int lane=0;lane<16;lane++)
          if (dpd_sample_count[lane] !== expected_dpd_samples || dpd_saturation_count[lane] !== 0)
            $fatal(1,"DPD lane%0d count=%0d/%0d saturation=%0d",
                   lane,dpd_sample_count[lane],expected_dpd_samples,dpd_saturation_count[lane]);
        if ($test$plusargs("INTERP1_GAP_STALL") && interp1_empty_blocked_hits==0)
          $fatal(1,"interp1 empty/blocked condition was not reached");
        if ($test$plusargs("INTERP1_GAP_STALL"))
          $display("THERMO5_INTERP1_EMPTY_BLOCKED_COUNT hits=%0d",interp1_empty_blocked_hits);
        $display("THERMO5_I2_D1_AXIS_BITTRUE_PASS source=%0d output=%0d stalls=%0d",sent,got,stalls);
        $finish;
`endif
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
`ifndef THERMO5_CENTERED_CUBIC
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
`endif
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
