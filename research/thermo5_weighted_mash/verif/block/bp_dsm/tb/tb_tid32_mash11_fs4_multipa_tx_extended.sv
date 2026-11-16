`timescale 1ns/1ps
`default_nettype none

module tb_tid32_mash11_fs4_multipa_tx_extended;
  localparam int W=16, LANES=32, WORDS=128, EXPECTED_LATENCY=6, EXPECTED_ALIGNMENT_WORDS=35;
  logic clk=1'b0, rst_n=1'b0, in_valid=1'b0;
  logic signed [LANES*W-1:0] in_i_poly_vec='0, in_q_poly_vec='0;
  wire in_ready, pa_valid;
  wire [2*LANES-1:0] pa_stage1_data, pa_stage2_data;
  logic [W-1:0] i_mem[0:LANES*WORDS-1], q_mem[0:LANES*WORDS-1];
  logic pa1_mem[0:2*LANES*WORDS-1], pa2_mem[0:2*LANES*WORDS-1];
  integer cycle_count=0, accepted=0, produced=0, errors=0;
  integer first_accept_cycle=-1, first_output_cycle=-1, previous_output_cycle=-1;
  integer lane, n;

  tid32_mash11_fs4_multipa_tx #(.W(W),.CHANNELS(LANES)) dut (
    .clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_ready(in_ready),
    .in_i_poly_vec(in_i_poly_vec),.in_q_poly_vec(in_q_poly_vec),
    .pa_valid(pa_valid),.pa_stage1_data(pa_stage1_data),.pa_stage2_data(pa_stage2_data)
  );
  always #5 clk=~clk;

  always @(posedge clk) begin
    cycle_count <= cycle_count + 1;
    if (rst_n && in_valid && in_ready) begin
      if (first_accept_cycle < 0) first_accept_cycle = cycle_count;
      accepted = accepted + 1;
    end
    if (rst_n && pa_valid) begin
      if (first_output_cycle < 0) first_output_cycle = cycle_count;
      if (previous_output_cycle >= 0 && cycle_count - previous_output_cycle != 1)
        $error("II violation: output gap after cycle %0d to %0d", previous_output_cycle, cycle_count);
      previous_output_cycle = cycle_count;
      for (lane=0; lane<2*LANES; lane=lane+1) begin
        if (pa_stage1_data[lane] !== pa1_mem[produced*2*LANES+lane]) begin
          $error("PA1 mismatch word=%0d bit=%0d", produced, lane); errors=errors+1;
        end
        if (pa_stage2_data[lane] !== pa2_mem[produced*2*LANES+lane]) begin
          $error("PA2 mismatch word=%0d bit=%0d", produced, lane); errors=errors+1;
        end
      end
      produced = produced + 1;
    end
  end

  initial begin
    $readmemh("tidmash_i.mem",i_mem); $readmemh("tidmash_q.mem",q_mem);
    $readmemh("tidmash_pa1.mem",pa1_mem); $readmemh("tidmash_pa2.mem",pa2_mem);
    if (dut.STAGE_DELAY_WORDS != EXPECTED_ALIGNMENT_WORDS)
      $fatal(1,"Alignment delay parameter %0d, expected %0d",dut.STAGE_DELAY_WORDS,EXPECTED_ALIGNMENT_WORDS);
    repeat(3) @(negedge clk); rst_n=1'b1;
    for(n=0; n<WORDS; n=n+1) begin
      @(negedge clk);
      if (!in_ready) $fatal(1,"Unexpected input backpressure at word %0d",n);
      for(lane=0; lane<LANES; lane=lane+1) begin
        in_i_poly_vec[lane*W +: W]=i_mem[n*LANES+lane];
        in_q_poly_vec[lane*W +: W]=q_mem[n*LANES+lane];
      end
      in_valid=1'b1;
    end
    @(negedge clk); in_valid=1'b0;
    wait(produced == WORDS);
    if (accepted != WORDS) $fatal(1,"Accepted %0d vectors, expected %0d",accepted,WORDS);
    if (first_output_cycle - first_accept_cycle != EXPECTED_LATENCY)
      $fatal(1,"Latency %0d cycles, expected %0d",first_output_cycle-first_accept_cycle,EXPECTED_LATENCY);
    if (errors != 0) $fatal(1,"Extended MASH mismatches=%0d",errors);
    $display("TID32_MASH11_FS4_MULTIPA_EXTENDED_PASS words=%0d accepted=%0d produced=%0d latency=%0d alignment_words=%0d II=1",
             WORDS,accepted,produced,first_output_cycle-first_accept_cycle,EXPECTED_ALIGNMENT_WORDS);
    $finish;
  end
endmodule

`default_nettype wire
