`timescale 1ns/1ps
`default_nettype none

module tb_dsm_ip_axi_smoke;
  localparam int W = 16;
  localparam int RF_W = 16;

  reg aclk;
  reg aresetn;

  reg [5:0] s_axi_awaddr;
  reg s_axi_awvalid;
  wire s_axi_awready;
  reg [31:0] s_axi_wdata;
  reg [3:0] s_axi_wstrb;
  reg s_axi_wvalid;
  wire s_axi_wready;
  wire [1:0] s_axi_bresp;
  wire s_axi_bvalid;
  reg s_axi_bready;

  reg [5:0] s_axi_araddr;
  reg s_axi_arvalid;
  wire s_axi_arready;
  wire [31:0] s_axi_rdata;
  wire [1:0] s_axi_rresp;
  wire s_axi_rvalid;
  reg s_axi_rready;

  reg [31:0] s_axis_tdata;
  reg s_axis_tvalid;
  wire s_axis_tready;

  wire dsm_valid;
  wire i_bit;
  wire q_bit;
  wire signed [3:0] i_yout;
  wire signed [3:0] q_yout;
  wire rf_valid;
  wire rf_bit;
  wire signed [RF_W-1:0] rf_signed;
  wire [23:0] phase_acc_dbg;

  dsm_ip_axi_top #(
    .W(W),
    .RF_W(RF_W),
    .PHASE_W(24),
    .ALGORITHM(2),
    .DUC_MODE(0)
  ) dut (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .dsm_valid(dsm_valid),
    .i_bit(i_bit),
    .q_bit(q_bit),
    .i_yout(i_yout),
    .q_yout(q_yout),
    .rf_valid(rf_valid),
    .rf_bit(rf_bit),
    .rf_signed(rf_signed),
    .phase_acc_dbg(phase_acc_dbg)
  );

  initial aclk = 1'b0;
  always #5 aclk = ~aclk;

  int valid_count;
  int n;

  task axi_write;
    input [5:0] addr;
    input [31:0] data;
    begin
      @(posedge aclk);
      s_axi_awaddr <= addr;
      s_axi_awvalid <= 1'b1;
      s_axi_wdata <= data;
      s_axi_wstrb <= 4'hf;
      s_axi_wvalid <= 1'b1;
      wait (s_axi_awready && s_axi_wready);
      @(posedge aclk);
      s_axi_awvalid <= 1'b0;
      s_axi_wvalid <= 1'b0;
      wait (s_axi_bvalid);
      @(posedge aclk);
    end
  endtask

  initial begin
    aresetn = 1'b0;
    s_axi_awaddr = 6'd0;
    s_axi_awvalid = 1'b0;
    s_axi_wdata = 32'd0;
    s_axi_wstrb = 4'h0;
    s_axi_wvalid = 1'b0;
    s_axi_bready = 1'b1;
    s_axi_araddr = 6'd0;
    s_axi_arvalid = 1'b0;
    s_axi_rready = 1'b1;
    s_axis_tdata = 32'd0;
    s_axis_tvalid = 1'b0;
    valid_count = 0;

    repeat (8) @(posedge aclk);
    aresetn = 1'b1;

    axi_write(6'h08, 32'h0040_0000);
    axi_write(6'h00, 32'h0000_0001);

    for (n = 0; n < 64; n++) begin
      @(posedge aclk);
      s_axis_tdata <= {$signed(16'sd512 + n), $signed(16'sd1024 + n)};
      s_axis_tvalid <= 1'b1;
      wait (s_axis_tready);
    end

    @(posedge aclk);
    s_axis_tvalid <= 1'b0;
    repeat (8) @(posedge aclk);

    if (valid_count == 0) $fatal(1, "dsm_ip_axi_top produced no rf_valid");
    $display("DSM IP AXI smoke PASS: rf_valid=%0d", valid_count);
    $finish;
  end

  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      valid_count <= 0;
    end else if (rf_valid) begin
      valid_count <= valid_count + 1;
    end
  end
endmodule

`default_nettype wire
