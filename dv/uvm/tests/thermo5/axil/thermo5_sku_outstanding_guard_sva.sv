// Assertions observe the real product counter and never drive DUT state.
module thermo5_sku_outstanding_guard_sva (
  input logic       clk,
  input logic       rst_n,
  input logic [7:0] outstanding_words,
  input logic       core_accept,
  input logic       output_accept
);
  ap_outstanding_saturation_guard_not_taken:
    assert property (@(posedge clk) disable iff (!rst_n)
      !(core_accept && !output_accept && (&outstanding_words)))
    else $error("outstanding counter saturation guard was taken");

  ap_outstanding_underflow_guard_not_taken:
    assert property (@(posedge clk) disable iff (!rst_n)
      !(!core_accept && output_accept && (outstanding_words == 0)))
    else $error("outstanding counter underflow guard was taken");
endmodule

bind thermo5_sku_uvm_tb thermo5_sku_outstanding_guard_sva
  u_outstanding_guard_sva (
    .clk(core_clk),
    .rst_n(bus.core_rst_n),
    .outstanding_words(dut.outstanding_words_q),
    .core_accept(dut.core_accept),
    .output_accept(dut.output_accept)
  );
