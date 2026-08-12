`timescale 1ns/1ps
`default_nettype none

module tb_dsm_ip_bp_axi_smoke;
  localparam int W = 16;
  reg aclk = 1'b0;
  reg aresetn = 1'b0;
  reg [8:0] s_axi_awaddr = '0;
  reg s_axi_awvalid = 1'b0;
  wire s_axi_awready;
  reg [31:0] s_axi_wdata = '0;
  reg [3:0] s_axi_wstrb = 4'h0;
  reg s_axi_wvalid = 1'b0;
  wire s_axi_wready;
  wire [1:0] s_axi_bresp;
  wire s_axi_bvalid;
  reg s_axi_bready = 1'b1;
  reg [8:0] s_axi_araddr = '0;
  reg s_axi_arvalid = 1'b0;
  wire s_axi_arready;
  wire [31:0] s_axi_rdata;
  wire [1:0] s_axi_rresp;
  wire s_axi_rvalid;
  reg s_axi_rready = 1'b1;
  reg [31:0] s_axis_tdata = '0;
  reg s_axis_tlast = 1'b0;
  reg [0:0] s_axis_tuser = 1'b0;
  reg s_axis_tvalid = 1'b0;
  wire s_axis_tready;
  reg [31:0] s_axis_obs_tdata = '0;
  reg s_axis_obs_tlast = 1'b0;
  reg [0:0] s_axis_obs_tuser = 1'b0;
  reg s_axis_obs_tvalid = 1'b0;
  wire s_axis_obs_tready;
  wire obs_irq;
  wire dsm_valid;
  wire i_bit;
  wire q_bit;
  wire signed [7:0] i_yout;
  wire signed [7:0] q_yout;
  wire rf_valid;
  wire rf_bit;
  wire signed [15:0] rf_signed;
  wire [23:0] phase_acc_dbg;
  integer rf_count;
  integer one_count;
  integer zero_count;

  dsm_ip_axi_top #(
    .W(W),
    .DSM_OUT_W(8),
    .RF_W(16),
    .PHASE_W(24),
    .ALGORITHM(3),
    .DUC_MODE(3),
    .INTERP_MODE(4),
    .INTERP_IMPL(0),
    .C_S_AXI_ADDR_WIDTH(9)
  ) dut (
    .aclk(aclk), .aresetn(aresetn),
    .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
    .s_axis_tdata(s_axis_tdata), .s_axis_tlast(s_axis_tlast), .s_axis_tuser(s_axis_tuser),
    .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready),
    .s_axis_obs_tdata(s_axis_obs_tdata), .s_axis_obs_tlast(s_axis_obs_tlast),
    .s_axis_obs_tuser(s_axis_obs_tuser), .s_axis_obs_tvalid(s_axis_obs_tvalid),
    .s_axis_obs_tready(s_axis_obs_tready), .obs_irq(obs_irq),
    .dsm_valid(dsm_valid), .i_bit(i_bit), .q_bit(q_bit), .i_yout(i_yout), .q_yout(q_yout),
    .rf_valid(rf_valid), .rf_bit(rf_bit), .rf_signed(rf_signed), .phase_acc_dbg(phase_acc_dbg)
  );

  always #5 aclk = ~aclk;

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
    end
  endtask

  task axis_send;
    input signed [15:0] i_sample;
    input signed [15:0] q_sample;
    begin
      @(posedge aclk);
      s_axis_tdata <= {q_sample, i_sample};
      s_axis_tvalid <= 1'b1;
      while (!s_axis_tready) @(posedge aclk);
      @(posedge aclk);
      s_axis_tvalid <= 1'b0;
    end
  endtask

  initial begin
    repeat (8) @(posedge aclk);
    aresetn <= 1'b1;
    axi_write(9'h000, 32'h0000_0001);
    for (int n = 0; n < 12; n++) begin
      axis_send((n < 6) ? 16'sd4096 : -16'sd4096,
                (n[0]) ? 16'sd2048 : -16'sd2048);
    end
    repeat (1600) @(posedge aclk);
    if (rf_count == 0 || one_count == 0 || zero_count == 0)
      $fatal(1, "BP AXI smoke did not produce a toggling rf_bit stream");
    $display("BP AXI smoke PASS: rf_valid=%0d one=%0d zero=%0d", rf_count, one_count, zero_count);
    $finish;
  end

  always @(posedge aclk) begin
    if (!aresetn) begin
      rf_count <= 0;
      one_count <= 0;
      zero_count <= 0;
    end else if (rf_valid) begin
      rf_count <= rf_count + 1;
      if (rf_bit) one_count <= one_count + 1;
      else zero_count <= zero_count + 1;
      if (rf_signed != (rf_bit ? 16'sh7fff : -16'sh7fff))
        $fatal(1, "BP AXI rf_signed/rf_bit mismatch");
    end
  end
endmodule

`default_nettype wire
