`timescale 1ns/1ps
`default_nettype none

module tb_tid32_thermo5_frontend_tx_bittrue #(
  parameter int WORDS=64,
  parameter int TIDSM_ORDER=2,
  parameter bit USE_EXTERNAL_DSM=1'b0,
  parameter int DSM_ARCH=(TIDSM_ORDER==1) ? 0 : 1
);
  localparam int W=16, LANES=8;
`ifdef TB_INTERP_2
  localparam int INTERP_TAPS = 2;
`elsif TB_INTERP_3
  localparam int INTERP_TAPS = 3;
`else
  localparam int INTERP_TAPS = 4;
`endif
`ifdef TB_DPD_1
  localparam int DPD_MAX_TAPS = 1;
`elsif TB_DPD_2
  localparam int DPD_MAX_TAPS = 2;
`else
  localparam int DPD_MAX_TAPS = 4;
`endif
  logic clk=1'b0, rst_n=1'b0, enable=1'b1, in_valid=1'b0;
  logic in_frame_start=1'b0, in_frame_end=1'b0;
  logic [15:0] in_config_id=0, in_reset_epoch=16'd7;
  logic signed [W-1:0] in_frame_gain=16'sd16384;
  logic signed [LANES*W-1:0] in_i_vec='0, in_q_vec='0;
  logic [3:0] pa_ready='0;
  wire in_ready; wire [3:0] pa_valid; wire [63:0] pa_data[0:3];
  wire [3:0] frontend_pa_valid; wire [63:0] frontend_pa_data[0:3];
  wire pre_dsm_valid, pre_dsm_ready;
  wire signed [511:0] pre_dsm_i, pre_dsm_q;
  wire pre_dsm_frame_start, pre_dsm_frame_end, pre_dsm_tail;
  wire [15:0] pre_dsm_config_id, pre_dsm_epoch;
  wire [15:0] backend_config_id, backend_epoch;
  wire backend_frame_start, backend_frame_end, backend_tail;
  wire backend_drain_done, backend_overflow, backend_weighted;
  logic [W-1:0] i_mem[0:LANES*WORDS-1], q_mem[0:LANES*WORDS-1];
  logic [W-1:0] pre_i_mem[0:32*WORDS-1], pre_q_mem[0:32*WORDS-1];
  logic [W-1:0] frame_start_mem[0:WORDS-1], frame_gain_mem[0:WORDS-1];
  logic [63:0] pa0_mem[0:WORDS-1], pa1_mem[0:WORDS-1];
  logic [63:0] pa2_mem[0:WORDS-1], pa3_mem[0:WORDS-1];
  logic signed [DPD_MAX_TAPS*W-1:0] c1_re,c1_im,c3_re,c3_im,c5_re,c5_im;
  integer sent, got, lane, branch, errors, drive_cycles;
  integer pre_words, pre_frame_starts, pre_frame_ends, pre_tails;
  integer expected_frame_config;
  integer cycle_counter=0, first_accept_cycle=-1, first_output_cycle=-1;
  integer pre_sample_index;
  logic held_output_valid=1'b0;
  logic [3:0] held_pa_valid;
  logic [63:0] held_pa_data[0:3];
  logic [34:0] held_backend_meta;
  int unsigned frame_config_q[$];
  logic [34:0] expected_meta_q[$];

  tid32_thermo5_frontend_tx #(
    .STEP(7168), .INTERP_TAPS(INTERP_TAPS), .MAX_TAPS(DPD_MAX_TAPS),
    .TIDSM_ORDER(TIDSM_ORDER), .USE_EXTERNAL_DSM(USE_EXTERNAL_DSM)
  ) dut (
    .clk(clk),.rst_n(rst_n),.enable(enable),.in_valid(in_valid),.in_ready(in_ready),
    .in_frame_start(in_frame_start),.in_frame_end(in_frame_end),
    .in_config_id(in_config_id),.in_reset_epoch(in_reset_epoch),
    .in_frame_gain(in_frame_gain),.in_i_vec(in_i_vec),.in_q_vec(in_q_vec),
    .dpd_active_taps(3'd1),.c1_re(c1_re),.c1_im(c1_im),.c3_re(c3_re),.c3_im(c3_im),.c5_re(c5_re),.c5_im(c5_im),
    .pa_valid(frontend_pa_valid),.pa_data(frontend_pa_data),.pa_ready(pa_ready),
    .pre_dsm_valid(pre_dsm_valid),.pre_dsm_ready(pre_dsm_ready),
    .pre_dsm_i_vec(pre_dsm_i),.pre_dsm_q_vec(pre_dsm_q),
    .pre_dsm_frame_start(pre_dsm_frame_start),.pre_dsm_frame_end(pre_dsm_frame_end),
    .pre_dsm_tail(pre_dsm_tail),.pre_dsm_config_id(pre_dsm_config_id),
    .pre_dsm_reset_epoch(pre_dsm_epoch),.dpd_config_boundary()
  );

  generate
    if (USE_EXTERNAL_DSM) begin : g_external_backend
      thermo5_unified_dsm_backend #(
        .STEP(7168), .DSM_ARCH(DSM_ARCH)
      ) u_backend (
        .clk(clk),.rst_n(rst_n),.stop_req(1'b0),.drain_done(backend_drain_done),
        .in_valid(pre_dsm_valid),.in_ready(pre_dsm_ready),
        .in_i_vec(pre_dsm_i),.in_q_vec(pre_dsm_q),
        .in_config_id(pre_dsm_config_id),.in_reset_epoch(pre_dsm_epoch),
        .in_frame_start(pre_dsm_frame_start),.in_frame_end(pre_dsm_frame_end),
        .in_tail(pre_dsm_tail),.pa_valid(pa_valid),.pa_ready(pa_ready),.pa_data(pa_data),
        .pa_contract_weighted(backend_weighted),.out_frame_start(backend_frame_start),
        .out_frame_end(backend_frame_end),.out_tail(backend_tail),
        .out_config_id(backend_config_id),.out_reset_epoch(backend_epoch),
        .overflow_error(backend_overflow)
      );
      for (genvar p=0; p<4; p=p+1) begin : g_external_pa
        assign frontend_pa_data[p] = '0;
      end
      assign frontend_pa_valid = '0;
    end else begin : g_internal_backend
      assign pa_valid = frontend_pa_valid;
      for (genvar p=0; p<4; p=p+1) begin : g_internal_pa
        assign pa_data[p] = frontend_pa_data[p];
      end
      assign pre_dsm_ready = 1'b0;
      assign backend_drain_done = 1'b0;
      assign backend_config_id = '0;
      assign backend_epoch = '0;
      assign backend_frame_start = 1'b0;
      assign backend_frame_end = 1'b0;
      assign backend_tail = 1'b0;
      assign backend_overflow = 1'b0;
      assign backend_weighted = 1'b0;
    end
  endgenerate
  always #5 clk=~clk;

  initial begin
    $readmemh("tid32_thermo5_frontend_i.mem",i_mem); $readmemh("tid32_thermo5_frontend_q.mem",q_mem);
    $readmemh("tid32_thermo5_frontend_frame_start.mem",frame_start_mem);
    $readmemh("tid32_thermo5_frontend_frame_gain.mem",frame_gain_mem);
    $readmemh("tid32_thermo5_frontend_pa0.mem",pa0_mem);
    $readmemh("tid32_thermo5_frontend_pa1.mem",pa1_mem);
    if (DSM_ARCH!=2) begin
      $readmemh("tid32_thermo5_frontend_pa2.mem",pa2_mem);
      $readmemh("tid32_thermo5_frontend_pa3.mem",pa3_mem);
    end
    if (DSM_ARCH==2) begin
      $readmemh("thermo5_pre_dsm_i.mem",pre_i_mem);
      $readmemh("thermo5_pre_dsm_q.mem",pre_q_mem);
    end
    c1_re='0; c1_re[15:0]=16'sd16384;
    c1_im='0; c3_re='0; c3_im='0; c5_re='0; c5_im='0;
    sent=0; got=0; errors=0; drive_cycles=0;
    pre_words=0; pre_frame_starts=0; pre_frame_ends=0; pre_tails=0;
    expected_frame_config=0;
    repeat(5) @(negedge clk); rst_n=1'b1;
    while(got<WORDS) begin
      @(negedge clk); drive_cycles=drive_cycles+1;
      if(drive_cycles>6000) $fatal(1,"thermo5 frontend timeout sent=%0d got=%0d",sent,got);
      pa_ready=(drive_cycles>=120 && drive_cycles<180) ? 4'h0 :
               ((drive_cycles%5)==0 ? 4'h0 : 4'hf);
      in_valid=(sent<WORDS);
      if (sent < WORDS) begin
        in_frame_start=frame_start_mem[sent][0]; in_frame_gain=frame_gain_mem[sent];
        in_frame_end=(sent==WORDS-1) ? 1'b1 : frame_start_mem[sent+1][0];
        in_config_id=16'h1000+sent;
        for(lane=0;lane<LANES;lane=lane+1) begin
          in_i_vec[lane*W+:W]=i_mem[sent*LANES+lane]; in_q_vec[lane*W+:W]=q_mem[sent*LANES+lane];
        end
      end else begin
        in_frame_start=1'b0; in_frame_end=1'b0; in_config_id='0; in_frame_gain=16'sd16384;
        in_i_vec='0; in_q_vec='0;
      end
    end
    in_valid=1'b0; pa_ready=4'hf;
    if(sent!=WORDS) $fatal(1,"accepted %0d/%0d inputs",sent,WORDS);
    if(errors!=0) $fatal(1,"thermo5 frontend mismatches=%0d",errors);
    if (USE_EXTERNAL_DSM && (pre_words!=WORDS || pre_frame_starts!=3 || pre_frame_ends!=3 || pre_tails!=0 || backend_overflow))
      $fatal(1,"Pre-DSM contract words=%0d starts=%0d ends=%0d tails=%0d overflow=%0b",pre_words,pre_frame_starts,pre_frame_ends,pre_tails,backend_overflow);
    if (USE_EXTERNAL_DSM && expected_meta_q.size()!=0)
      $fatal(1,"unmatched backend metadata transactions=%0d",expected_meta_q.size());
    if (USE_EXTERNAL_DSM)
      $display("PRE_DSM_METADATA_PASS words=%0d starts=%0d ends=%0d tails=%0d",pre_words,pre_frame_starts,pre_frame_ends,pre_tails);
    $display("TID32_THERMO5_FRONTEND_BITTRUE_PASS arch=%0d words=%0d output_samples=%0d observed_first_output_latency=%0d",
      DSM_ARCH,WORDS,WORDS*32,first_output_cycle-first_accept_cycle);
    $finish;
  end

  always @(posedge clk) begin
    cycle_counter=cycle_counter+1;
    if(!rst_n) begin sent<=0; got<=0; end else begin
      if(in_valid && in_ready) begin
        if (first_accept_cycle<0) first_accept_cycle=cycle_counter;
        if (in_frame_start) frame_config_q.push_back(in_config_id);
        sent<=sent+1;
      end
      if (USE_EXTERNAL_DSM && pre_dsm_valid && pre_dsm_ready) begin
        if (pre_words < 2)
          $display("PRE_DSM_TRACE n=%0d i=%h q=%h cfg=%h epoch=%h",pre_words,pre_dsm_i,pre_dsm_q,pre_dsm_config_id,pre_dsm_epoch);
        if (pre_dsm_frame_start) begin
          if (frame_config_q.size()==0) $fatal(1,"Pre-DSM frame start without source frame context");
          expected_frame_config=frame_config_q.pop_front();
          pre_frame_starts=pre_frame_starts+1;
        end
        if (pre_dsm_config_id !== expected_frame_config[15:0] || pre_dsm_epoch !== 16'd7)
          $fatal(1,"Pre-DSM frame context mismatch word=%0d config=%h expected=%h epoch=%h",pre_words,pre_dsm_config_id,expected_frame_config[15:0],pre_dsm_epoch);
        if (DSM_ARCH==2) begin
          for (pre_sample_index=0; pre_sample_index<32; pre_sample_index=pre_sample_index+1) begin
            if (pre_dsm_i[pre_sample_index*W +: W] !== pre_i_mem[pre_words*32+pre_sample_index] ||
                pre_dsm_q[pre_sample_index*W +: W] !== pre_q_mem[pre_words*32+pre_sample_index])
              $fatal(1,"independent Pre-DSM oracle mismatch word=%0d lane=%0d",pre_words,pre_sample_index);
          end
        end
        if (pre_dsm_frame_end) pre_frame_ends=pre_frame_ends+1;
        if (pre_dsm_tail) pre_tails=pre_tails+1;
        expected_meta_q.push_back({pre_dsm_epoch,pre_dsm_config_id,pre_dsm_tail,
                                   pre_dsm_frame_end,pre_dsm_frame_start});
        pre_words=pre_words+1;
      end
      if (held_output_valid) begin
        if (pa_valid !== held_pa_valid)
          $fatal(1,"PA valid changed while output was blocked");
        for (branch=0; branch<((DSM_ARCH==2)?2:4); branch=branch+1)
          if (pa_data[branch] !== held_pa_data[branch])
            $fatal(1,"PA data changed while blocked plane=%0d",branch);
        if (USE_EXTERNAL_DSM &&
            {backend_epoch,backend_config_id,backend_tail,backend_frame_end,backend_frame_start} !== held_backend_meta)
          $fatal(1,"PA metadata changed while output was blocked");
      end
      held_output_valid=1'b0;
      if ((|pa_valid) &&
          (((DSM_ARCH==2) && pa_ready[1:0]!=2'b11) ||
           ((DSM_ARCH!=2) && pa_ready!=4'hf))) begin
        held_output_valid=1'b1;
        held_pa_valid=pa_valid;
        for (branch=0; branch<4; branch=branch+1) held_pa_data[branch]=pa_data[branch];
        held_backend_meta={backend_epoch,backend_config_id,backend_tail,backend_frame_end,backend_frame_start};
      end
      if (DSM_ARCH==2) begin
        if (pa_valid!==4'h0 && pa_valid!==4'b0011)
          $fatal(1,"Weighted MASH PA valid alignment failure: %b",pa_valid);
      end else if(pa_valid!==4'h0 && pa_valid!==4'hf) begin
        $fatal(1,"equal-plane PA valid alignment failure: %b",pa_valid);
      end
      if (((DSM_ARCH==2) && pa_valid==4'b0011 && pa_ready[1:0]==2'b11) ||
          ((DSM_ARCH!=2) && pa_valid==4'hf && pa_ready==4'hf)) begin
        if (backend_weighted !== (DSM_ARCH==2))
          $fatal(1,"PA contract selector mismatch arch=%0d weighted=%b",DSM_ARCH,backend_weighted);
        if (first_output_cycle<0) first_output_cycle=cycle_counter;
        if (USE_EXTERNAL_DSM && got < 2)
          $display("PA_TRACE n=%0d data0=%h valid=%b",got,pa_data[0],pa_valid);
        if (USE_EXTERNAL_DSM) begin
          if (expected_meta_q.size()==0) $fatal(1,"PA output without Pre-DSM transaction");
          if ({backend_epoch,backend_config_id,backend_tail,backend_frame_end,backend_frame_start} !== expected_meta_q[0])
            $fatal(1,"PA metadata was not aligned to its Pre-DSM transaction");
          expected_meta_q.pop_front();
        end
        for(branch=0;branch<((DSM_ARCH==2)?2:4);branch=branch+1) begin
          case (branch)
            0: if(pa_data[branch]!==pa0_mem[got]) begin
              $error("PA%0d mismatch word=%0d got=%h exp=%h",branch,got,pa_data[branch],pa0_mem[got]); errors<=errors+1;
            end
            1: if(pa_data[branch]!==pa1_mem[got]) begin
              $error("PA%0d mismatch word=%0d got=%h exp=%h",branch,got,pa_data[branch],pa1_mem[got]); errors<=errors+1;
            end
            2: if(pa_data[branch]!==pa2_mem[got]) begin
              $error("PA%0d mismatch word=%0d got=%h exp=%h",branch,got,pa_data[branch],pa2_mem[got]); errors<=errors+1;
            end
            3: if(pa_data[branch]!==pa3_mem[got]) begin
              $error("PA%0d mismatch word=%0d got=%h exp=%h",branch,got,pa_data[branch],pa3_mem[got]); errors<=errors+1;
            end
          endcase
        end
        got<=got+1;
      end
    end
  end
endmodule

`default_nettype wire
