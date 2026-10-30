`timescale 1ns/1ps
`default_nettype none

module thermo5_axil_cfg_coverage_harness (
  input logic axil_clk,
  input logic axil_rst_n,
  input logic core_clk,
  input logic core_rst_n,
  input logic [7:0] awaddr,
  input logic awvalid,
  input logic [31:0] wdata,
  input logic [3:0] wstrb,
  input logic wvalid,
  input logic bready,
  input logic [7:0] araddr,
  input logic arvalid,
  input logic rready,
  input logic dpd_config_boundary
);
  logic awready;
  logic wready;
  logic [1:0] bresp;
  logic bvalid;
  logic arready;
  logic [31:0] rdata;
  logic [1:0] rresp;
  logic rvalid;
  logic core_enable;
  logic [2:0] active_taps;
  logic signed [63:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im;
  logic cfg_busy, cfg_done, cfg_error;

  thermo5_dpd_axi_lite_cfg #(.MAX_TAPS(1)) dut (
    .s_axil_aclk(axil_clk), .s_axil_aresetn(axil_rst_n),
    .s_axil_awaddr(awaddr), .s_axil_awvalid(awvalid), .s_axil_awready(awready),
    .s_axil_wdata(wdata), .s_axil_wstrb(wstrb), .s_axil_wvalid(wvalid), .s_axil_wready(wready),
    .s_axil_bresp(bresp), .s_axil_bvalid(bvalid), .s_axil_bready(bready),
    .s_axil_araddr(araddr), .s_axil_arvalid(arvalid), .s_axil_arready(arready),
    .s_axil_rdata(rdata), .s_axil_rresp(rresp), .s_axil_rvalid(rvalid), .s_axil_rready(rready),
    .core_clk(core_clk), .core_aresetn(core_rst_n),
    .dpd_config_boundary(dpd_config_boundary), .core_tx_active(1'b0),
    .core_draining(1'b0), .core_enable(core_enable), .run_request(),
    .dpd_active_taps(active_taps), .c1_re(c1_re), .c1_im(c1_im),
    .c3_re(c3_re), .c3_im(c3_im), .c5_re(c5_re), .c5_im(c5_im),
    .cfg_busy(cfg_busy), .cfg_done(cfg_done), .cfg_error(cfg_error)
  );

  // No protocol or reset assumptions are imposed here. VC Formal's saved
  // reset state is the only initialization; the two reset-coupling assumptions
  // used by an earlier revision were vacuous and are intentionally removed.

  // These properties are deliberately bound to the production RTL instance.
  // They justify only the exact condition bins named in the coverage ledger.
  a_bvalid_clears_pending:
    assert property (@(posedge axil_clk) disable iff (!axil_rst_n)
      bvalid |-> (!dut.aw_pending && !dut.w_pending));

  a_line88_tuple_unreachable:
    assert property (@(posedge axil_clk) disable iff (!axil_rst_n)
      !(bvalid && (dut.aw_pending || dut.aw_take) && (dut.w_pending || dut.w_take)));
  c_line88_tuple_unreachable:
    cover property (@(posedge axil_clk) disable iff (!axil_rst_n)
      bvalid && (dut.aw_pending || dut.aw_take) && (dut.w_pending || dut.w_take));

  // The sequential OKAY-only write case is reached only after write_resp
  // has decoded an explicit register address. This proves the case default
  // cannot be selected by a legal external AXI-Lite write.
  a_write_case_default_unreachable:
    assert property (@(posedge axil_clk) disable iff (!axil_rst_n)
      (dut.write_fire && dut.write_resp == 2'b00) |->
        (dut.write_addr == 8'h00 || dut.write_addr == 8'h04 ||
         dut.write_addr == 8'h08 || dut.write_addr == 8'h10 ||
         dut.write_addr == 8'h14 || dut.write_addr == 8'h18 ||
         dut.write_addr == 8'h1c || dut.write_addr == 8'h20 ||
         dut.write_addr == 8'h24 || dut.write_addr == 8'h28 ||
         dut.write_addr == 8'h2c || dut.write_addr == 8'h30 ||
         dut.write_addr == 8'h34 || dut.write_addr == 8'h38 ||
         dut.write_addr == 8'h3c));
  c_write_case_default_unreachable:
    cover property (@(posedge axil_clk) disable iff (!axil_rst_n)
      dut.write_fire && dut.write_resp == 2'b00 &&
      !(dut.write_addr == 8'h00 || dut.write_addr == 8'h04 ||
        dut.write_addr == 8'h08 || dut.write_addr == 8'h10 ||
        dut.write_addr == 8'h14 || dut.write_addr == 8'h18 ||
        dut.write_addr == 8'h1c || dut.write_addr == 8'h20 ||
        dut.write_addr == 8'h24 || dut.write_addr == 8'h28 ||
        dut.write_addr == 8'h2c || dut.write_addr == 8'h30 ||
        dut.write_addr == 8'h34 || dut.write_addr == 8'h38 ||
        dut.write_addr == 8'h3c));

  // The coefficient-address decoder admits only the six aligned coefficient
  // words and their high-word aliases. Therefore the masked address entering
  // coeff_read_word can never select that function's default arm (line 142).
  a_coeff_read_default_unreachable:
    assert property (@(posedge axil_clk) disable iff (!axil_rst_n)
      dut.coeff_word_addr(dut.s_axil_araddr) |->
        ((dut.s_axil_araddr & 8'hf8) inside
          {8'h10,8'h18,8'h20,8'h28,8'h30,8'h38}));
  c_coeff_read_default_arm_unreachable:
    cover property (@(posedge axil_clk) disable iff (!axil_rst_n)
      dut.coeff_word_addr(dut.s_axil_araddr) &&
      !((dut.s_axil_araddr & 8'hf8) inside
        {8'h10,8'h18,8'h20,8'h28,8'h30,8'h38}));

  // MAX_TAPS is tied to 1 in this harness. Its initial guard is a static
  // configuration fact, not a non-tautological Formal reachability property;
  // the corresponding Raw code bin is reviewed separately and stays OPEN.

  // Ensure the reachability assertion is not vacuous: a legal coefficient
  // read transaction can enter the function through the production mux.
  c_coeff_read_transaction:
    cover property (@(posedge axil_clk) disable iff (!axil_rst_n)
      dut.s_axil_arvalid && dut.s_axil_arready &&
      dut.coeff_word_addr(dut.s_axil_araddr));

endmodule

`default_nettype wire
