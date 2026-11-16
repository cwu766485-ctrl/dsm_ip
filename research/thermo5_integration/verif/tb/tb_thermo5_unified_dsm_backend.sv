`timescale 1ns/1ps
`default_nettype none
module tb_thermo5_unified_dsm_backend #(
  parameter int DSM_ARCH = 0,
  parameter int WORDS = 128
);
  localparam int W=16, CHANNELS=32;
  logic clk=0, rst_n=0, stop_req=0, in_valid=0;
  logic signed [CHANNELS*W-1:0] in_i='0, in_q='0;
  logic [15:0] config_id=16'h33, epoch=16'd7;
  logic frame_start=0, frame_end=0, tail=0;
  wire in_ready, drain_done, overflow_error, weighted;
  wire [3:0] pa_valid;
  logic [3:0] pa_ready=4'hf;
  wire [63:0] pa_data[0:3];
  wire out_frame_start, out_frame_end, out_tail;
  wire [15:0] out_config_id, out_epoch;
  integer accepted=0, produced=0, cycles=0, last_accept=-1, ii_errors=0;
  integer start_count=0, end_count=0, tail_count=0;
  integer start_index[0:1], end_index[0:1], tail_index[0:1];
  integer n, lane;

  thermo5_unified_dsm_backend #(.DSM_ARCH(DSM_ARCH)) dut (
    .clk,.rst_n,.stop_req,.drain_done,.in_valid,.in_ready,
    .in_i_vec(in_i),.in_q_vec(in_q),.in_config_id(config_id),
    .in_reset_epoch(epoch),.in_frame_start(frame_start),.in_frame_end(frame_end),
    .in_tail(tail),.pa_valid,.pa_ready,.pa_data,
    .pa_contract_weighted(weighted),.out_frame_start,.out_frame_end,.out_tail,
    .out_config_id,.out_reset_epoch(out_epoch),.overflow_error
  );
  always #5 clk=~clk;

  always @(posedge clk) begin
    cycles=cycles+1;
    if (rst_n && in_valid && in_ready) begin
      if (last_accept>=0 && cycles-last_accept!=1) ii_errors=ii_errors+1;
      last_accept=cycles;
      accepted=accepted+1;
    end
    if (rst_n && (|pa_valid) && (&pa_ready)) begin
      if (DSM_ARCH==2) begin
        if (pa_valid!==4'b0011 || !weighted) $fatal(1,"MASH PA contract mismatch valid=%b",pa_valid);
      end else if (pa_valid!==4'b1111 || weighted) begin
        $fatal(1,"equal-plane PA contract mismatch valid=%b weighted=%b",pa_valid,weighted);
      end
      for (int p=0;p<((DSM_ARCH==2)?2:4);p++)
        if ($isunknown(pa_data[p])) $fatal(1,"unknown PA data arch=%0d plane=%0d word=%0d",DSM_ARCH,p,produced);
      if (out_config_id !== (16'h3300 + produced) || out_epoch !== 16'd7)
        $fatal(1,"backend metadata mismatch arch=%0d word=%0d config=%h expected=%h epoch=%h",
          DSM_ARCH,produced,out_config_id,(16'h3300 + produced),out_epoch);
      if (out_frame_start) begin
        if (produced != 0 && produced != WORDS/2)
          $fatal(1,"unexpected frame_start arch=%0d word=%0d",DSM_ARCH,produced);
        start_index[start_count]=produced;
        start_count=start_count+1;
      end
      if (out_frame_end) begin
        if (produced != WORDS/2-1 && produced != WORDS-1)
          $fatal(1,"unexpected frame_end arch=%0d word=%0d",DSM_ARCH,produced);
        end_index[end_count]=produced;
        end_count=end_count+1;
      end
      if (out_tail) begin
        if (produced != WORDS/2-1 && produced != WORDS-1)
          $fatal(1,"unexpected tail arch=%0d word=%0d",DSM_ARCH,produced);
        tail_index[tail_count]=produced;
        tail_count=tail_count+1;
      end
      produced=produced+1;
    end
  end

  initial begin
    repeat(3) @(negedge clk); rst_n=1;
    @(negedge clk); in_valid=1;
    config_id=16'h3300;
    for (n=0;n<WORDS;n=n+1) begin
      frame_start=(n==0 || n==WORDS/2);
      frame_end=(n==WORDS/2-1 || n==WORDS-1);
      tail=frame_end;
      config_id=16'h3300+n;
      for (lane=0;lane<CHANNELS;lane=lane+1) begin
        in_i[lane*W+:W]=$signed((n*37+lane*101)%12000-6000);
        in_q[lane*W+:W]=$signed((n*71-lane*53)%10000-5000);
      end
      do @(posedge clk); while (!in_ready);
      @(negedge clk);
    end
    in_valid=0; frame_start=0; frame_end=0; tail=0;
    wait(produced==WORDS);
    if (accepted!=WORDS || ii_errors!=0 || overflow_error || start_count!=2 || end_count!=2 || tail_count!=2 ||
        start_index[0]!=0 || start_index[1]!=WORDS/2 ||
        end_index[0]!=WORDS/2-1 || end_index[1]!=WORDS-1 ||
        tail_index[0]!=WORDS/2-1 || tail_index[1]!=WORDS-1)
      $fatal(1,"backend stream mismatch arch=%0d accepted=%0d produced=%0d II_errors=%0d markers=%0d/%0d/%0d starts=%0d,%0d ends=%0d,%0d tails=%0d,%0d overflow=%b",
        DSM_ARCH,accepted,produced,ii_errors,start_count,end_count,tail_count,
        start_index[0],start_index[1],end_index[0],end_index[1],
        tail_index[0],tail_index[1],overflow_error);
    stop_req=1;
    wait(drain_done);
    $display("THERMO5_UNIFIED_BACKEND_PASS arch=%0d contract=%s accepted=%0d produced=%0d II=1",
      DSM_ARCH,weighted?"weighted_1_to_2":"four_equal",accepted,produced);
    $finish;
  end
endmodule
`default_nettype wire
