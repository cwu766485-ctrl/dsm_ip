`timescale 1ns/1ps
`default_nettype none

module tb_tid32_thermo5_mash_axis_qam #(
  parameter int SOURCE_BEATS = 3004,
  parameter int EXPECTED_WORDS = 5257,
  parameter bit USE_ACCUMULATOR_RESIDUE = 1'b0
);
  localparam int W = 16;
  logic s_clk = 1'b0, core_clk = 1'b0;
  logic s_rst_n = 1'b0, core_rst_n = 1'b0;
  logic core_drain = 1'b0;
  logic s_valid = 1'b0, s_frame_start = 1'b0, s_last = 1'b0;
  logic signed [14*W-1:0] s_i = '0, s_q = '0;
  wire s_ready, s_fifo_full, core_underflow, core_protocol_error;
  wire [1:0] pa_valid;
  logic [1:0] pa_ready = 2'b11;
  wire [63:0] pa0, pa1;
  wire frame_start, frame_end, tail, overflow_error;
  wire [15:0] config_id, reset_epoch;
  logic [W-1:0] i_samples[0:14*SOURCE_BEATS-1];
  logic [W-1:0] q_samples[0:14*SOURCE_BEATS-1];
  logic [63:0] expected_pa0[0:EXPECTED_WORDS-1];
  logic [63:0] expected_pa1[0:EXPECTED_WORDS-1];
  integer beat, lane, accepted, produced, errors, cycles;
  integer pa0_fd, pa1_fd;
  string pa0_path, pa1_path;
  logic signed [15:0] c1_re;
  // Optional passive root-cause probes. All observations use pre-NBA handshake
  // values, matching the receiving sequential logic at this clock edge.
  string audit_dir, vcd_path;
  integer pre_fd=0, stage_fd=0, pair_fd=0, event_fd=0, source_fd=0, residual_fd=0, stage2_fd=0;
  integer pre_id=0, stage_id=0, pair_id=0, audit_cycle=0, source_id=0, residual_id=0, stage2_id=0;
  initial begin
    if ($value$plusargs("audit_dir=%s", audit_dir)) begin
      pre_fd=$fopen({audit_dir,"/pre_words.csv"},"w");
      stage_fd=$fopen({audit_dir,"/stage1_words.csv"},"w");
      pair_fd=$fopen({audit_dir,"/stage_pairs.csv"},"w");
      event_fd=$fopen({audit_dir,"/events.csv"},"w");
      source_fd=$fopen({audit_dir,"/source_events.csv"},"w");
      residual_fd=$fopen({audit_dir,"/residual_words.csv"},"w");
      stage2_fd=$fopen({audit_dir,"/stage2_words.csv"},"w");
      if (!pre_fd || !stage_fd || !pair_fd || !event_fd || !source_fd || !residual_fd || !stage2_fd) $fatal(1,"audit open failed");
      $fdisplay(pre_fd,"id,time_ps,cycle,i_hex,q_hex,frame_start,frame_end,tail,config_id,epoch");
      $fdisplay(stage_fd,"id,time_ps,cycle,raw_hex");
      $fdisplay(pair_fd,"id,time_ps,cycle,q1_hex,q2_hex,pa0_hex,pa1_hex,frame_start,frame_end,tail,config_id,epoch");
      $fdisplay(event_fd,"time_ps,cycle,pre_valid,pre_ready,stage1_valid,pa_valid,pa_ready");
      $fdisplay(source_fd,"id,time_ps,frame_start,last");
      $fdisplay(residual_fd,"id,time_ps,i_hex,q_hex,x_i_hex,x_q_hex,q1_hex");
      $fdisplay(stage2_fd,"id,time_ps,cycle,raw_hex");
    end
    if ($value$plusargs("vcd=%s", vcd_path)) begin
      $dumpfile(vcd_path);
      $dumpvars(0, core_clk, core_rst_n, s_clk, s_rst_n, s_valid, s_ready,
        dut.pre_valid, dut.pre_ready, dut.pre_i_vec, dut.pre_q_vec,
        dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.s1_valid,
        dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.s1_data,
        dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.s1_to_s2_valid,
        dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.residual_i_vec,
        dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.residual_q_vec,
        pa_valid, pa_ready, pa0, pa1);
    end
  end
  wire [31:0] dpd_saturations[0:15];
  wire [31:0] dpd_samples[0:15];
  for(genvar probe_lane=0;probe_lane<16;probe_lane=probe_lane+1) begin : g_audit_dpd
    assign dpd_saturations[probe_lane] =
      dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[probe_lane].u_dpd.saturation_count;
    assign dpd_samples[probe_lane] =
      dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[probe_lane].u_dpd.sample_count;
  end
  always @(posedge s_clk) begin
    if(s_rst_n && source_fd && s_valid && s_ready) begin
      $fdisplay(source_fd,"%0d,%0.0f,%0b,%0b",source_id,$realtime*1000,s_frame_start,s_last);
      source_id=source_id+1;
    end
  end
  always @(posedge core_clk) begin
    audit_cycle=audit_cycle+1;
    if (core_rst_n && pre_fd) begin
      $fdisplay(event_fd,"%0.0f,%0d,%0b,%0b,%0b,%0h,%0h",$realtime*1000,audit_cycle,
        dut.pre_valid,dut.pre_ready,
        dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.s1_valid,pa_valid,pa_ready);
      if (dut.pre_valid && dut.pre_ready) begin
        $fdisplay(pre_fd,"%0d,%0.0f,%0d,%0128h,%0128h,%0b,%0b,%0b,%0d,%0d",
          pre_id,$realtime*1000,audit_cycle,dut.pre_i_vec,dut.pre_q_vec,
          dut.pre_frame_start,dut.pre_frame_end,dut.pre_tail,dut.pre_config_id,dut.pre_reset_epoch);
        pre_id=pre_id+1;
      end
      if (dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.s1_valid) begin
        $fdisplay(stage_fd,"%0d,%0.0f,%0d,%016h",stage_id,$realtime*1000,audit_cycle,
          dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.s1_data);
        stage_id=stage_id+1;
      end
      if (dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.s1_to_s2_valid &&
          dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.s2_in_ready) begin
        $fdisplay(residual_fd,"%0d,%0.0f,%0128h,%0128h,%0128h,%0128h,%016h",residual_id,$realtime*1000,
          dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.residual_i_vec,
          dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.residual_q_vec,
          dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.i_delay[34],
          dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.q_delay[34],
          dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.s1_to_s2_data);
        residual_id=residual_id+1;
      end
      if (dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.s2_valid) begin
        $fdisplay(stage2_fd,"%0d,%0.0f,%0d,%016h",stage2_id,$realtime*1000,audit_cycle,
          dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.s2_data);
        stage2_id=stage2_id+1;
      end
      if ((&pa_valid) && (&pa_ready)) begin
        $fdisplay(pair_fd,"%0d,%0.0f,%0d,%016h,%016h,%016h,%016h,%0b,%0b,%0b,%0d,%0d",
          pair_id,$realtime*1000,audit_cycle,
          dut.u_mash_backend.g_weighted_mash.u_mash_adapter.out_stage1_data,
          dut.u_mash_backend.g_weighted_mash.u_mash_adapter.out_stage2_data,
          pa0,pa1,frame_start,frame_end,tail,config_id,reset_epoch);
        pair_id=pair_id+1;
      end
    end
  end

  always #4 s_clk = ~s_clk;
  always #2.285714 core_clk = ~core_clk;

  tid32_thermo5_mash_axis_frontend_tx #(
    .W(W), .GAIN_W(16), .DPD_MAX_TAPS(1), .INTERP_TAPS(2),
    .FPGA_USE_XPM_FIFO(1'b0), .CONFIG_ID(16'h0042), .RESET_EPOCH(16'h0001),
    .USE_ACCUMULATOR_RESIDUE(USE_ACCUMULATOR_RESIDUE)
  ) dut (
    .s_axis_aclk(s_clk), .s_axis_aresetn(s_rst_n),
    .s_axis_tvalid(s_valid), .s_axis_tready(s_ready),
    .s_axis_i_vec(s_i), .s_axis_q_vec(s_q),
    .s_axis_tuser_frame_start(s_frame_start), .s_axis_tlast(s_last),
    .s_axis_tuser_frame_gain(16'sh4000), .s_axis_fifo_full(s_fifo_full),
    .core_clk(core_clk), .core_aresetn(core_rst_n),
    .core_drain(core_drain),
    .core_underflow(core_underflow), .core_protocol_error(core_protocol_error),
    .dpd_active_taps(3'd1), .c1_re(c1_re), .c1_im(16'sd0),
    .c3_re(16'sd0), .c3_im(16'sd0), .c5_re(16'sd0), .c5_im(16'sd0),
    .mash_pa_valid(pa_valid), .mash_pa_ready(pa_ready),
    .mash_pa0_data(pa0), .mash_pa1_data(pa1),
    .out_frame_start(frame_start), .out_frame_end(frame_end), .out_tail(tail),
    .out_config_id(config_id), .out_reset_epoch(reset_epoch),
    .adapter_overflow(overflow_error)
  );

  initial begin
    $readmemh("axis_i_samples.mem", i_samples);
    $readmemh("axis_q_samples.mem", q_samples);
    if (USE_ACCUMULATOR_RESIDUE) begin
      $readmemh("corrected_expected_pa0.mem", expected_pa0);
      $readmemh("corrected_expected_pa1.mem", expected_pa1);
    end else begin
      $readmemh("expected_mash_pa0.mem", expected_pa0);
      $readmemh("expected_mash_pa1.mem", expected_pa1);
    end
    if (!$value$plusargs("pa0=%s", pa0_path)) $fatal(1,"missing +pa0=<path>");
    if (!$value$plusargs("pa1=%s", pa1_path)) $fatal(1,"missing +pa1=<path>");
    pa0_fd=$fopen(pa0_path,"w");
    pa1_fd=$fopen(pa1_path,"w");
    if (!pa0_fd || !pa1_fd) $fatal(1,"cannot open PA capture output");
    c1_re = 16'sh4000;
    accepted=0; produced=0; errors=0; cycles=0;
    repeat (8) begin @(negedge s_clk); end
    s_rst_n=1'b1;
    repeat (8) begin @(negedge core_clk); end
    core_rst_n=1'b1;

    for (beat=0; beat<SOURCE_BEATS; beat=beat+1) begin
      @(negedge s_clk);
      s_valid=1'b1;
      s_frame_start=(beat==0);
      s_last=(beat==SOURCE_BEATS-1);
      for (lane=0; lane<14; lane=lane+1) begin
        s_i[lane*W +: W]=i_samples[beat*14+lane];
        s_q[lane*W +: W]=q_samples[beat*14+lane];
      end
      do @(posedge s_clk); while (!s_ready);
      accepted=accepted+1;
    end
    @(negedge s_clk);
    s_valid=1'b0; s_frame_start=1'b0; s_last=1'b0;
    core_drain=1'b1;

    wait(produced==EXPECTED_WORDS);
    repeat (4) @(posedge core_clk);
    if (accepted!=SOURCE_BEATS || errors!=0 || core_underflow ||
        core_protocol_error || overflow_error || s_fifo_full)
      $fatal(1,"MASH QAM RTL mismatch accepted=%0d/%0d produced=%0d/%0d errors=%0d underflow=%b protocol=%b overflow=%b",
        accepted,SOURCE_BEATS,produced,EXPECTED_WORDS,errors,core_underflow,
        core_protocol_error,overflow_error);
    $display("THERMO5_MASH_AXIS_QAM_BITTRUE_PASS source_beats=%0d pa_words=%0d II=1",accepted,produced);
    for(integer probe=0;probe<16;probe=probe+1)
      $display("DPD_COUNTER lane=%0d samples=%0d saturations=%0d",probe,dpd_samples[probe],dpd_saturations[probe]);
    $fclose(pa0_fd); $fclose(pa1_fd);
    $finish;
  end

  always @(posedge core_clk) begin
    cycles=cycles+1;
    if (core_rst_n && (|pa_valid)) begin
      if (pa_valid!==2'b11)
        $fatal(1,"PA pair lost atomic valid: %b",pa_valid);
      if (config_id!==16'h0042 || reset_epoch!==16'h0001 || tail)
        $fatal(1,"MASH output metadata mismatch word=%0d cfg=%h epoch=%h tail=%b",
          produced,config_id,reset_epoch,tail);
      if (frame_start !== (produced==0) || frame_end !== (produced==EXPECTED_WORDS-1))
        $fatal(1,"frame marker mismatch word=%0d start=%b end=%b",produced,frame_start,frame_end);
      if (pa0!==expected_pa0[produced] || pa1!==expected_pa1[produced]) begin
        errors=errors+1;
        if(errors<5) $error("PA Golden mismatch word=%0d",produced);
      end
      $fdisplay(pa0_fd,"%016h",pa0);
      $fdisplay(pa1_fd,"%016h",pa1);
      produced=produced+1;
    end
    if (cycles>2000000) $fatal(1,"MASH QAM watchdog accepted=%0d produced=%0d",accepted,produced);
  end
endmodule

`default_nettype wire
