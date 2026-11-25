`timescale 1ns/1ps

// One elaboration-selected UVM shell for EF1, EF2, and MASH 1-1 Product.
// Exactly one Product DUT is instantiated for each DSM_ARCH value:
//   1 = Thermo5 EF1, 2 = Thermo5 EF2, 3 = MASH 1-1 Product.
module dsm_v13_multi_sku_uvm_tb #(
  parameter int DSM_ARCH = 2
);
  generate
    if (DSM_ARCH == 1 || DSM_ARCH == 2 || DSM_ARCH == 3) begin : g_product
      thermo5_sku_uvm_tb #(.DSM_ARCH(DSM_ARCH)) selected_product_sku();
    end else begin : g_invalid_arch
      initial $fatal(1,"DSM_ARCH must be 1 (EF1), 2 (EF2), or 3 (MASH Product)");
    end
  endgenerate
endmodule
