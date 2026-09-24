`timescale 1ns/1ps
`default_nettype none

// Verify that an AXI-Stream source can hold TVALID through CTRL.soft_reset
// and resume without a false disabled-stream error.
module tb_dsm_ip_axi_active_reset;
  localparam int W = 16;
  localparam int DSM_OUT_W = 8;
  localparam int RF_W = 16;
  localparam int INPUTS = 16;

  reg aclk;
  reg aresetn;
  reg [8:0] s_axi_awaddr;
  reg s_axi_awvalid;
  wire s_axi_awready;
  reg [31:0] s_axi_wdata;
  reg [3:0] s_axi_wstrb;
  reg s_axi_wvalid;
  wire s_axi_wready;
  wire [1:0] s_axi_bresp;
  wire s_axi_bvalid;
  reg s_axi_bready;
  reg [8:0] s_axi_araddr;
  reg s_axi_arvalid;
  wire s_axi_arready;
  wire [31:0] s_axi_rdata;
  wire [1:0] s_axi_rresp;
  wire s_axi_rvalid;
  reg s_axi_rready;
  reg [31:0] s_axis_tdata;
  reg s_axis_tlast;
  reg [0:0] s_axis_tuser;
  reg s_axis_tvalid;
  wire s_axis_tready;
  reg [31:0] s_axis_obs_tdata;
  reg s_axis_obs_tlast;
  reg [0:0] s_axis_obs_tuser;
  reg s_axis_obs_tvalid;
  wire s_axis_obs_tready;
  wire dsm_valid;
  wire i_bit;
  wire q_bit;
  wire signed [DSM_OUT_W-1:0] i_yout;
  wire signed [DSM_OUT_W-1:0] q_yout;
  wire rf_valid;
  wire rf_bit;
  wire signed [RF_W-1:0] rf_signed;
  wire [23:0] phase_acc_dbg;

  dsm_ip_axi_top #(
    .W(W), .DSM_OUT_W(DSM_OUT_W), .RF_W(RF_W), .PHASE_W(24),
    .ALGORITHM(2), .DUC_MODE(0), .INTERP_MODE(0), .C_S_AXI_ADDR_WIDTH(9)
  ) dut (
    .aclk(aclk), .aresetn(aresetn),
    .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready), .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready), .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready), .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .s_axis_tdata(s_axis_tdata), .s_axis_tlast(s_axis_tlast),
    .s_axis_tuser(s_axis_tuser), .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_obs_tdata(s_axis_obs_tdata), .s_axis_obs_tlast(s_axis_obs_tlast),
    .s_axis_obs_tuser(s_axis_obs_tuser), .s_axis_obs_tvalid(s_axis_obs_tvalid),
    .s_axis_obs_tready(s_axis_obs_tready),
    .dsm_valid(dsm_valid), .i_bit(i_bit), .q_bit(q_bit),
    .i_yout(i_yout), .q_yout(q_yout), .rf_valid(rf_valid),
    .rf_bit(rf_bit), .rf_signed(rf_signed), .phase_acc_dbg(phase_acc_dbg)
  );

  initial aclk = 1'b0;
  always #5 aclk = ~aclk;

  integer accepted_count;
  integer rf_after_reset;
  reg reset_requested;
  reg reset_window_seen;
  reg [31:0] rd;

  task axi_write;
    input [8:0] addr;
    input [31:0] data;
    begin
      @(posedge aclk);
      s_axi_awaddr <= addr;
      s_axi_awvalid <= 1'b1;
      s_axi_wdata <= data;
      s_axi_wstrb <= 4'hf;
      s_axi_wvalid <= 1'b1;
      while (!(s_axi_awready && s_axi_wready)) @(posedge aclk);
      @(posedge aclk);
      s_axi_awvalid <= 1'b0;
      s_axi_wvalid <= 1'b0;
      while (!s_axi_bvalid) @(posedge aclk);
      if (s_axi_bresp != 2'b00) $fatal(1, "AXI write response failure");
      @(posedge aclk);
    end
  endtask

  task axi_read;
    input [8:0] addr;
    output [31:0] data;
    begin
      @(posedge aclk);
      s_axi_araddr <= addr;
      s_axi_arvalid <= 1'b1;
      while (!s_axi_arready) @(posedge aclk);
      @(posedge aclk);
      s_axi_arvalid <= 1'b0;
      while (!s_axi_rvalid) @(posedge aclk);
      #1 data = s_axi_rdata;
      if (s_axi_rresp != 2'b00) $fatal(1, "AXI read response failure");
      @(posedge aclk);
    end
  endtask

  task axis_send;
    input signed [15:0] i_sample;
    input signed [15:0] q_sample;
    input last_sample;
    begin
      // Drive before the sampling edge and retire the item only on its
      // actual TVALID && TREADY handshake.  This remains correct if a
      // CTRL.soft_reset changes TREADY between successive clock edges.
      @(negedge aclk);
      s_axis_tdata <= {q_sample, i_sample};
      s_axis_tlast <= last_sample;
      s_axis_tvalid <= 1'b1;
      do @(posedge aclk); while (!s_axis_tready);
      @(negedge aclk);
      s_axis_tvalid <= 1'b0;
      s_axis_tlast <= 1'b0;
    end
  endtask

  initial begin
    aresetn = 1'b0;
    s_axi_awaddr = '0;
    s_axi_awvalid = 1'b0;
    s_axi_wdata = '0;
    s_axi_wstrb = '0;
    s_axi_wvalid = 1'b0;
    s_axi_bready = 1'b1;
    s_axi_araddr = '0;
    s_axi_arvalid = 1'b0;
    s_axi_rready = 1'b1;
    s_axis_tdata = '0;
    s_axis_tlast = 1'b0;
    s_axis_tuser = 1'b0;
    s_axis_tvalid = 1'b0;
    s_axis_obs_tdata = '0;
    s_axis_obs_tlast = 1'b0;
    s_axis_obs_tuser = 1'b0;
    s_axis_obs_tvalid = 1'b0;
    accepted_count = 0;
    rf_after_reset = 0;
    reset_requested = 1'b0;
    reset_window_seen = 1'b0;

    repeat (8) @(posedge aclk);
    aresetn = 1'b1;
    axi_write(9'h000, 32'h0000_0001);

    fork
      begin : stream_source
        integer n;
        for (n = 0; n < INPUTS; n = n + 1)
          axis_send($signed(16'sd256 + n), $signed(-16'sd512 - n), n == INPUTS-1);
      end
      begin : reset_controller
        wait (accepted_count == 4);
        reset_requested = 1'b1;
        axi_write(9'h000, 32'h0000_0003);
        axi_write(9'h000, 32'h0000_0001);
      end
    join

    repeat (160) @(posedge aclk);
    if (!reset_window_seen) $fatal(1, "CTRL.soft_reset did not create a reset window");
    if (accepted_count != INPUTS)
      $fatal(1, "AXI-Stream did not recover after reset: accepted=%0d expected=%0d",
             accepted_count, INPUTS);
    if (rf_after_reset == 0) $fatal(1, "No RF output observed after active-stream reset");
    axi_read(9'h020, rd);
    if (rd != 32'd1) $fatal(1, "software reset count mismatch: %0d", rd);
    axi_read(9'h018, rd);
    if (rd != INPUTS) $fatal(1, "input counter mismatch after reset: %0d", rd);
    axi_read(9'h024, rd);
    if (rd != 32'd0) $fatal(1, "unexpected sticky error after reset recovery: %08x", rd);

    $display("ACTIVE_STREAM_RESET_PASS inputs=%0d rf_after_reset=%0d", INPUTS, rf_after_reset);
    $finish;
  end

  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      accepted_count <= 0;
      rf_after_reset <= 0;
    end else begin
      if (s_axis_tvalid && s_axis_tready) accepted_count <= accepted_count + 1;
      if (reset_requested && rf_valid) rf_after_reset <= rf_after_reset + 1;
    end
  end

  always @(negedge aclk) begin
    if (aresetn && dut.soft_reset) begin
      reset_window_seen = 1'b1;
      if (s_axis_tready !== 1'b0) $fatal(1, "TREADY must deassert during CTRL.soft_reset");
    end
  end
endmodule

`default_nettype wire
