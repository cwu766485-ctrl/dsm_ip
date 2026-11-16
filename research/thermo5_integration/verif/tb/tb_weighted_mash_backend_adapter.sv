`timescale 1ns/1ps
`default_nettype none
module tb_weighted_mash_backend_adapter;
  localparam int W=16, L=32, N=256;
  logic clk=0, rst_n=0, stop_req=0, in_valid=0, out_ready=0;
  logic signed [L*W-1:0] ii='0, qq='0;
  logic [15:0] cfg=0, epoch=7; logic fs=0, fe=0, tail=0;
  wire in_ready, out_valid, overflow_error, drain_done;
  wire [2*L-1:0] s1,s2,pa0,pa1; wire [15:0] ocfg,oepoch; wire ofs,ofe,otail; wire [15:0] inflight;
  integer n, accepted=0, produced=0, cycles=0, errors=0;
  integer lane, q1i, q1q, q2i, q2q, expected_i, expected_q;
  integer prev_i=-1, prev_q=-1;
  logic held_valid=0;
  logic [2*L-1:0] held_pa0, held_pa1;
  logic [15:0] held_cfg, held_epoch;
  logic held_fs, held_fe, held_tail;
  int unsigned expected_cfg[$];

  task automatic send_range(input integer first_cfg, input integer count,
                            input integer send_epoch, input logic first_fs);
    integer idx;
    begin
      @(negedge clk);
      in_valid=1;
      cfg=first_cfg;
      epoch=send_epoch;
      fs=first_fs;
      fe=(first_cfg==N-1 || first_cfg==1031);
      tail=fe;
      for (idx=0; idx<count; idx=idx+1) begin
        do @(posedge clk); while (!in_ready);
        if (idx+1<count) begin
          @(negedge clk);
          cfg=first_cfg+idx+1;
          fs=0;
          fe=(first_cfg+idx+1==N-1 || first_cfg+idx+1==1031);
          tail=fe;
        end
      end
      @(negedge clk);
      in_valid=0;
      fs=0; fe=0; tail=0;
    end
  endtask

  initial begin : p_optional_vcd
    string vcd_path;
    if ($value$plusargs("vcd=%s", vcd_path)) begin
      $dumpfile(vcd_path);
      $dumpvars(0, tb_weighted_mash_backend_adapter);
    end
  end

  function automatic integer decode_fs4(input logic [2*L-1:0] word,
                                         input integer lane, input integer comp);
    logic b;
    begin
      b=word[2*lane+comp];
      if(comp==0) decode_fs4=((lane%2)==0) ? (b?1:-1) : (b?-1:1);
      else decode_fs4=((lane%2)==0) ? (b?-1:1) : (b?1:-1);
    end
  endfunction
  thermo5_weighted_mash_backend_adapter #(.FIFO_DEPTH(16)) dut(
    .clk,.rst_n,.stop_req,.drain_done,.in_valid,.in_ready,.in_i_poly_vec(ii),.in_q_poly_vec(qq),
    .in_config_id(cfg),.in_epoch(epoch),.in_frame_start(fs),.in_frame_end(fe),.in_tail(tail),
    .out_valid,.out_ready,.out_stage1_data(s1),.out_stage2_data(s2),.out_pa0_data(pa0),.out_pa1_data(pa1),.out_config_id(ocfg),.out_epoch(oepoch),
    .out_frame_start(ofs),.out_frame_end(ofe),.out_tail(otail),.overflow_error,.inflight_count(inflight));
  always #5 clk=~clk;
  always @(posedge clk) begin
    cycles <= cycles+1;
    if (rst_n && out_valid && !out_ready) begin
      if (held_valid && (pa0 !== held_pa0 || pa1 !== held_pa1 ||
                         ocfg !== held_cfg || oepoch !== held_epoch ||
                         ofs !== held_fs || ofe !== held_fe || otail !== held_tail))
        errors=errors+1;
      held_valid=1; held_pa0=pa0; held_pa1=pa1;
      held_cfg=ocfg; held_epoch=oepoch; held_fs=ofs; held_fe=ofe; held_tail=otail;
    end else held_valid=0;
    if (rst_n && in_valid && in_ready) begin
      accepted=accepted+1; expected_cfg.push_back(cfg);
      if(fs) $display("INPUT_FRAME_START accepted=%0d cfg=%0d",accepted,cfg);
    end
    if (rst_n && out_valid && out_ready) begin
      if (oepoch !== epoch) errors=errors+1;
      if (expected_cfg.size()==0 || ocfg !== expected_cfg[0]) errors=errors+1;
      else expected_cfg.pop_front();
      if (ofs !== (ocfg==0 || ocfg==1000)) begin
        $display("FRAME_START metadata mismatch cfg=%0d start=%0b",ocfg,ofs); errors=errors+1;
      end
      if (ofe !== (ocfg==N-1 || ocfg==1031)) begin
        $display("FRAME_END metadata mismatch cfg=%0d end=%0b",ocfg,ofe); errors=errors+1;
      end
      if (otail !== (ocfg==N-1 || ocfg==1031)) begin
        $display("TAIL metadata mismatch cfg=%0d tail=%0b",ocfg,otail); errors=errors+1;
      end
      for (lane=0; lane<L; lane=lane+1) begin
        q1i=decode_fs4(s1,lane,0); q1q=decode_fs4(s1,lane,1);
        q2i=decode_fs4(s2,lane,0); q2q=decode_fs4(s2,lane,1);
        expected_i=q1i+q2i-prev_i; expected_q=q1q+q2q-prev_q;
        if (decode_fs4(pa0,lane,0)+2*decode_fs4(pa1,lane,0) != expected_i) errors=errors+1;
        if (decode_fs4(pa0,lane,1)+2*decode_fs4(pa1,lane,1) != expected_q) errors=errors+1;
        prev_i=q2i; prev_q=q2q;
      end
      produced=produced+1;
    end
  end
  initial begin
    fork
      begin
        #200000;
        $fatal(1,"adapter bench watchdog cycles=%0d accepted=%0d produced=%0d inflight=%0d fifo=%0d pending=%0d encoder=%0b drain=%0b",cycles,accepted,produced,inflight,dut.fifo_count,dut.core_pending_count,dut.encoder_valid,drain_done);
      end
    join_none
    repeat(3) @(negedge clk); rst_n=1;
    // Hold the consumer stopped until the exact bounded capacity is reached.
    // The producer must stop at FIFO_DEPTH plus core and encoder in-flight
    // storage, not after a short
    // arbitrary stall that could miss a delayed core result.
    out_ready=0;
    send_range(0,17,7,1'b1);
    if (accepted != 17) $fatal(1,"bounded capacity accepted=%0d expected=17",accepted);
    $display("STALL_CAPACITY accepted=%0d produced=%0d fifo=%0d pending=%0d encoder=%0b",accepted,produced,dut.fifo_count,dut.core_pending_count,dut.encoder_valid);
    repeat(50) begin
      @(negedge clk);
      if (in_ready || overflow_error || dut.fifo_count > 16)
        $fatal(1,"long stall invariant failed accepted=%0d produced=%0d ready=%0b fifo=%0d pending=%0d encoder=%0b overflow=%0b",accepted,produced,in_ready,dut.fifo_count,dut.core_pending_count,dut.encoder_valid,overflow_error);
    end
    if (dut.fifo_count != 16) $fatal(1,"raw output FIFO did not reach full occupancy: %0d",dut.fifo_count);
    $display("STALL_DRAIN fifo=%0d",dut.fifo_count);
    out_ready=1;
    send_range(17,N-17,7,1'b0);
    repeat(12) begin @(negedge clk); out_ready = (cycles % 3 != 0); end
    out_ready=1;
    wait(produced==N);
    $display("FIRST_STREAM_DONE accepted=%0d produced=%0d inflight=%0d",accepted,produced,inflight);
    if (accepted!=N || errors!=0 || overflow_error) $fatal(1,"adapter failure accepted=%0d produced=%0d errors=%0d overflow=%0b",accepted,produced,errors,overflow_error);
    @(negedge clk); stop_req=1;
    wait(drain_done);
    if (in_ready || inflight!=0) $fatal(1,"STOP drain contract failed");
    @(negedge clk); stop_req=0; #1;
    if (!in_ready) $fatal(1,"adapter failed to restart after graceful STOP");
    // Fill part of the pipeline, reset while work is in flight, and prove the
    // new epoch cannot observe any old buffered transaction.
    out_ready=0;
    send_range(500,8,7,1'b0);
    repeat(4) @(negedge clk);
    if (inflight==0) $fatal(1,"reset-in-flight setup did not retain work");
    rst_n=0;
    repeat(2) @(negedge clk);
    if (out_valid || inflight!=0) $fatal(1,"reset failed to flush prior epoch");
    expected_cfg.delete(); accepted=0; produced=0; errors=0; prev_i=-1; prev_q=-1;
    epoch=8; out_ready=1; rst_n=1;
    send_range(1000,32,8,1'b1);
    wait(produced==32);
    if(accepted!=32 || errors!=0 || overflow_error)
      $fatal(1,"new epoch failure accepted=%0d produced=%0d errors=%0d",accepted,produced,errors);
    stop_req=1; wait(drain_done);
    $display("THERMO5_MASH_ADAPTER_PASS accepted=%0d produced=%0d II=1 bounded_fifo=16",accepted,produced);
    $finish;
  end
endmodule
`default_nettype wire
