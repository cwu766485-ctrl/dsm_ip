`timescale 1ns/1ps
`default_nettype none

// Small block-level coverage test for the AXI-Lite configuration endpoint.
// It deliberately exercises the standalone reset-port contract: AXI-Lite
// reset may assert while the core has a pending, not-yet-applied mailbox.
module thermo5_axil_cfg_coverage_tb;
  logic axil_clk = 1'b0;
  logic core_clk = 1'b0;
  logic axil_rst_n = 1'b0;
  logic core_rst_n = 1'b0;
  logic dpd_config_boundary = 1'b0;
  logic [7:0] awaddr = '0;
  logic awvalid = 1'b0;
  wire awready;
  logic [31:0] wdata = '0;
  logic [3:0] wstrb = 4'hf;
  logic wvalid = 1'b0;
  wire wready;
  wire [1:0] bresp;
  wire bvalid;
  logic bready = 1'b0;
  logic [7:0] araddr = '0;
  logic arvalid = 1'b0;
  wire arready;
  wire [31:0] rdata;
  wire [1:0] rresp;
  wire rvalid;
  logic rready = 1'b0;
  wire core_enable;
  wire [2:0] dpd_active_taps;
  wire signed [63:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im;
  wire cfg_busy, cfg_done, cfg_error;

  always #5.000 axil_clk = ~axil_clk;
  always #2.286 core_clk = ~core_clk;

  thermo5_dpd_axi_lite_cfg #(.MAX_TAPS(4)) dut (
    .s_axil_aclk(axil_clk), .s_axil_aresetn(axil_rst_n),
    .s_axil_awaddr(awaddr), .s_axil_awvalid(awvalid), .s_axil_awready(awready),
    .s_axil_wdata(wdata), .s_axil_wstrb(wstrb), .s_axil_wvalid(wvalid), .s_axil_wready(wready),
    .s_axil_bresp(bresp), .s_axil_bvalid(bvalid), .s_axil_bready(bready),
    .s_axil_araddr(araddr), .s_axil_arvalid(arvalid), .s_axil_arready(arready),
    .s_axil_rdata(rdata), .s_axil_rresp(rresp), .s_axil_rvalid(rvalid), .s_axil_rready(rready),
    .core_clk(core_clk), .core_aresetn(core_rst_n),
    .dpd_config_boundary(dpd_config_boundary), .core_enable(core_enable),
    .dpd_active_taps(dpd_active_taps), .c1_re(c1_re), .c1_im(c1_im),
    .c3_re(c3_re), .c3_im(c3_im), .c5_re(c5_re), .c5_im(c5_im),
    .cfg_busy(cfg_busy), .cfg_done(cfg_done), .cfg_error(cfg_error)
  );

  task automatic axil_write(input logic [7:0] addr, input logic [31:0] data);
    int unsigned timeout;
    @(negedge axil_clk);
    awaddr <= addr;
    wdata <= data;
    wstrb <= 4'hf;
    awvalid <= 1'b1;
    wvalid <= 1'b1;
    bready <= 1'b1;
    timeout = 0;
    do begin
      @(posedge axil_clk);
      if (++timeout > 100) $fatal(1,"AXI-Lite write address/data timeout");
    end while (!awready || !wready);
    @(negedge axil_clk);
    awvalid <= 1'b0;
    wvalid <= 1'b0;
    timeout = 0;
    do begin
      @(posedge axil_clk);
      if (++timeout > 100) $fatal(1,"AXI-Lite B response timeout");
    end while (!bvalid);
    if (bresp != 2'b00) $fatal(1,"Unexpected AXI-Lite response %b at %02x",bresp,addr);
    @(negedge axil_clk);
    bready <= 1'b0;
  endtask

  initial begin : run_test
    logic [386:0] reset_payload;
    int unsigned timeout;
    reset_payload = {3'd1,64'h0000_0000_0000_4000,64'd0,64'd0,64'd0,64'd0,64'd0};

    repeat (4) @(posedge axil_clk);
    @(negedge axil_clk);
    axil_rst_n = 1'b1;
    @(negedge core_clk);
    core_rst_n = 1'b1;

    // Change the shadow coefficient so an accidental apply is observable.
    axil_write(8'h10,32'h0000_4001);
    fork
      axil_write(8'h00,32'h0000_0002);
      begin
        timeout = 0;
        do begin
          @(negedge core_clk);
          if (++timeout > 100) $fatal(1,"Request synchronizer did not reach the pending-capture window");
        end while (dut.cfg_req_sync2 !== 1'b1 || dut.cfg_pending_valid !== 1'b0);

        // Hit line 315 condition tuple (1,0,1): request visible, pending bank
        // not captured yet, boundary asserted. This must not apply payload.
        dpd_config_boundary = 1'b1;
        @(posedge core_clk);
        @(negedge core_clk);
        dpd_config_boundary = 1'b0;
      end
    join
    if (dut.cfg_pending_valid !== 1'b1 || dut.cfg_active_core !== reset_payload)
      $fatal(1,"Configuration applied before the pending bank was captured");

    // Abort the pending transaction by asserting only the AXI-Lite reset.
    // This is a block-level reset-port test; the integrated SKU contract uses
    // common assertion of AXI-Lite and core resets.
    @(negedge axil_clk);
    axil_rst_n = 1'b0;
    #1ns;
    axil_rst_n = 1'b1;

    timeout = 0;
    while (dut.cfg_req_sync2 !== 1'b0 || dut.cfg_pending_valid !== 1'b1) begin
      @(negedge core_clk);
      if (++timeout > 100) $fatal(1,"Pending state did not overlap request deassertion after AXI-Lite reset");
    end

    // Hit line 315 condition tuple (0,1,1): the core must discard the stale
    // pending bundle without changing the active configuration.
    dpd_config_boundary = 1'b1;
    @(posedge core_clk);
    @(negedge core_clk);
    dpd_config_boundary = 1'b0;
    if (dut.cfg_pending_valid !== 1'b0 || dut.cfg_active_core !== reset_payload ||
        dut.cfg_ack_core !== 1'b0)
      $fatal(1,"AXI-Lite reset did not safely abort the unapplied configuration");

    @(negedge core_clk);
    core_rst_n = 1'b0;
    repeat (3) @(posedge core_clk);
    if (dut.cfg_active_core !== reset_payload)
      $fatal(1,"Core reset did not restore the reset payload");
    $display("THERMO5_AXIL_CFG_RESET_WINDOW_COVERAGE_PASS tuples=101,011 active_payload_unchanged=1");
    $finish;
  end
endmodule

`default_nettype wire
