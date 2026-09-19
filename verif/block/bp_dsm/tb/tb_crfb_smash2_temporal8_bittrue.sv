`timescale 1ns/1ps
`default_nettype none
module tb_crfb_smash2_temporal8_bittrue;
  localparam int W=16, MAX_WORDS=512;
  logic clk=0, rst_n=0, enable=0;
  logic signed [8*W-1:0] x_word;
  wire [7:0] y1_word,y2_word;
  wire signed [9*28-1:0] state_word;
  integer xv[0:MAX_WORDS*8-1], y1v[0:MAX_WORDS-1], y2v[0:MAX_WORDS-1];
  integer sv[0:MAX_WORDS*9-1];
  integer words=0, status, fd, index, mismatches=0;
  string header;
  crfb_smash2_temporal8 dut(.clk(clk),.rst_n(rst_n),.enable(enable),.x_word(x_word),
    .y1_word(y1_word),.y2_word(y2_word),.state_word(state_word));
  always #5 clk=~clk;
  initial begin
    fd=$fopen("crfb_temporal8_equivalence.csv","r");
    if(fd==0)$fatal(1,"cannot open CRFB temporal8 vectors");
    status=$fgets(header,fd);
    while(!$feof(fd) && words<MAX_WORDS) begin
      status=$fscanf(fd,"%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n",index,
        xv[words*8],xv[words*8+1],xv[words*8+2],xv[words*8+3],xv[words*8+4],xv[words*8+5],xv[words*8+6],xv[words*8+7],y1v[words],y2v[words],
        sv[words*9],sv[words*9+1],sv[words*9+2],sv[words*9+3],sv[words*9+4],sv[words*9+5],sv[words*9+6],sv[words*9+7],sv[words*9+8]);
      if(status==20)words++;
      else if(!$feof(fd))$fatal(1,"malformed vector row %0d",words);
    end
    $fclose(fd); if(words==0)$fatal(1,"no CRFB vectors loaded");
    repeat(4)@(negedge clk); rst_n=1;
    for(int w=0;w<words;w++) begin
      @(negedge clk); enable=1; x_word='0;
      for(int lane=0;lane<8;lane++) x_word[lane*W +: W]=xv[w*8+lane];
      @(posedge clk); #1;
      if(y1_word!==y1v[w][7:0] || y2_word!==y2v[w][7:0]) begin
        $error("CRFB temporal8 mismatch word=%0d got=%h/%h expected=%h/%h",w,y1_word,y2_word,y1v[w][7:0],y2v[w][7:0]); mismatches++;
      end
      for(int s=0;s<9;s++) begin
        if($signed(state_word[(9-s)*28-1 -: 28])!==sv[w*9+s]) begin
          $error("CRFB temporal8 state mismatch word=%0d state=%0d got=%0d expected=%0d",w,s,$signed(state_word[(9-s)*28-1 -: 28]),sv[w*9+s]); mismatches++;
        end
      end
    end
    if(mismatches!=0)$fatal(1,"CRFB temporal8 mismatches=%0d",mismatches);
    $display("CRFB_TEMPORAL8_BITTRUE_PASS words=%0d",words); $finish;
  end
endmodule
`default_nettype wire
