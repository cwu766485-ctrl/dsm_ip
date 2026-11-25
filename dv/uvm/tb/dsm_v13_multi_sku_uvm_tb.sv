`timescale 1ns/1ps

// One elaboration-selected UVM shell for EF1, EF2, and MASH 1-1. Exactly one
// product datapath is instantiated for each DSM_ARCH value:
//   1 = Thermo5 EF1, 2 = Thermo5 EF2, 3 = MASH 1-1 block SKU.
module dsm_v13_multi_sku_uvm_tb #(
  parameter int DSM_ARCH = 2
);
  generate
    if (DSM_ARCH == 3) begin : g_mash11
      logic clk = 1'b0;
      always #5 clk = ~clk;
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
        uvm_pkg::uvm_config_db#(virtual mash11_sku_if)::set(null,"*","vif",bus);
        uvm_pkg::run_test("mash11_vector_test");
      end
    end else if (DSM_ARCH == 1 || DSM_ARCH == 2) begin : g_thermo5
      thermo5_sku_uvm_tb #(.DSM_ARCH(DSM_ARCH)) selected_thermo5_sku();
    end else begin : g_invalid_arch
      initial $fatal(1,"DSM_ARCH must be 1 (EF1), 2 (EF2), or 3 (MASH 1-1)");
    end
  endgenerate
endmodule
