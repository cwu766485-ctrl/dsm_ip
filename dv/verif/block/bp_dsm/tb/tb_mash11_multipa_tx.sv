`timescale 1ns/1ps
`default_nettype none

module tb_mash11_multipa_tx;
  logic clk = 1'b0, rst_n = 1'b0, in_valid = 1'b0;
  logic signed [15:0] if_sample = '0;
  wire out_valid, pa_stage1_bit, pa_stage2_bit;
  wire signed [2:0] combined_level;
  integer checked = 0;

  mash11_multipa_tx dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .if_sample(if_sample),
    .out_valid(out_valid), .pa_stage1_bit(pa_stage1_bit),
    .pa_stage2_bit(pa_stage2_bit), .combined_level(combined_level)
  );
  always #5 clk = ~clk;

  initial begin
    repeat (3) @(negedge clk); rst_n = 1'b1;
    for (int n = 0; n < 128; n++) begin
      @(negedge clk); in_valid = 1'b1; if_sample = (n[0] ? 16'sd8192 : -16'sd8192);
      @(posedge clk); #1;
      if (out_valid) begin
        // The P0 model defines the reset cancellation delay as zero; only the
        // first valid output can therefore be +/-2.  Subsequent symbols are
        // the normal four-level MASH codes.
        if ((checked != 0 && !((combined_level == -3) || (combined_level == -1) ||
                               (combined_level == 1) || (combined_level == 3))) ||
            (checked == 0 && !((combined_level == -2) || (combined_level == 2))))
          $fatal(1, "invalid MASH level %0d", combined_level);
        checked = checked + 1;
      end
    end
    if (checked != 128) $fatal(1, "checked=%0d", checked);
    $display("MASH11_MULTIPA_INTERFACE_PASS samples=%0d", checked);
    $finish;
  end
endmodule

`default_nettype wire
