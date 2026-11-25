`timescale 1ns/1ps

module dsm_v13_mash11_uvm_tb;
  import uvm_pkg::*;
  import mash11_sku_uvm_pkg::*;
  logic clk=1'b0;
  always #5 clk=~clk;
  mash11_sku_if bus(clk);

  mash11_multipa_tx #(
    .W(16), .ACC_W(18), .IN_SHIFT(0), .SATURATE(1'b1)
  ) dut (
    .clk(clk), .rst_n(bus.rst_n), .in_valid(bus.in_valid),
    .if_sample(bus.sample), .out_valid(bus.out_valid),
    .pa_stage1_bit(bus.stage1_bit), .pa_stage2_bit(bus.stage2_bit),
    .combined_level(bus.combined_level)
  );

  initial begin
    uvm_config_db#(virtual mash11_sku_if)::set(null,"*","vif",bus);
    run_test("mash11_vector_test");
  end
endmodule
