`timescale 1ns/1ps
`default_nettype none

module tb_dsm_ip_axi_smoke;
  localparam int W = 16;
  localparam int DSM_OUT_W = 8;
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
  reg s_axis_tlast;
  reg [0:0] s_axis_tuser;
  reg s_axis_tvalid;
  wire s_axis_tready;

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
    .W(W),
    .DSM_OUT_W(DSM_OUT_W),
    .RF_W(RF_W),
    .PHASE_W(24),
    .ALGORITHM(2),
    .DUC_MODE(0),
    .INTERP_MODE(4)
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
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tuser(s_axis_tuser),
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
  reg [31:0] rd;

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

  task axi_read;
    input [5:0] addr;
    output [31:0] data;
    begin
      @(posedge aclk);
      s_axi_araddr <= addr;
      s_axi_arvalid <= 1'b1;
      wait (s_axi_arready);
      @(posedge aclk);
      s_axi_arvalid <= 1'b0;
      wait (s_axi_rvalid);
      data = s_axi_rdata;
      @(posedge aclk);
    end
  endtask

  task axis_send;
    input signed [15:0] i_sample;
    input signed [15:0] q_sample;
    input last_sample;
    input user_error;
    begin
      @(posedge aclk);
      s_axis_tdata <= {q_sample, i_sample};
      s_axis_tlast <= last_sample;
      s_axis_tuser <= user_error;
      s_axis_tvalid <= 1'b1;
      while (!s_axis_tready) begin
        @(posedge aclk);
      end
      @(posedge aclk);
      s_axis_tvalid <= 1'b0;
      s_axis_tlast <= 1'b0;
      s_axis_tuser <= 1'b0;
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
    s_axis_tlast = 1'b0;
    s_axis_tuser = 1'b0;
    s_axis_tvalid = 1'b0;
    valid_count = 0;

    repeat (8) @(posedge aclk);
    aresetn = 1'b1;

    s_axis_tdata <= {16'sd1, 16'sd2};
    s_axis_tvalid <= 1'b1;
    repeat (2) @(posedge aclk);
    s_axis_tvalid <= 1'b0;

    axi_read(6'h24, rd);
    if (rd[0] !== 1'b1) $fatal(1, "sticky error was not set while stream was not ready");
    axi_write(6'h24, 32'h0000_0001);
    axi_read(6'h24, rd);
    if (rd != 32'h0000_0000) $fatal(1, "sticky error did not clear");

    axi_write(6'h08, 32'h0040_0000);
    axi_read(6'h08, rd);
    if (rd[23:0] != 24'h400000) $fatal(1, "phase increment readback mismatch");
    axi_read(6'h30, rd);
    if (rd != 32'd4) $fatal(1, "compiled INTERP_MODE readback mismatch");

    axi_write(6'h00, 32'h0000_0001);
    axi_read(6'h00, rd);
    if (rd[0] !== 1'b1) $fatal(1, "enable readback mismatch");

    axi_write(6'h00, 32'h0000_0003);
    axi_read(6'h20, rd);
    if (rd != 32'd1) $fatal(1, "software reset count mismatch");
    axi_write(6'h00, 32'h0000_0001);

    for (n = 0; n < 64; n++) begin
      axis_send($signed(16'sd512 + n), $signed(16'sd1024 + n), (n == 31) || (n == 63), (n == 7));
    end

    repeat (2500) @(posedge aclk);

    if (valid_count == 0) $fatal(1, "dsm_ip_axi_top produced no rf_valid");
    axi_read(6'h18, rd);
    if (rd != 32'd64) $fatal(1, "input sample count mismatch");
    axi_read(6'h28, rd);
    if (rd != 32'd64) $fatal(1, "frontend sample count mismatch");
    axi_read(6'h2c, rd);
    if (rd == 32'd0) $fatal(1, "input stall count did not increment under INTERP_MODE=4 backpressure");
    axi_read(6'h34, rd);
    if (rd != 32'd2) $fatal(1, "AXI-Stream frame count mismatch");
    axi_read(6'h38, rd);
    if (rd[0] != 1'b0) $fatal(1, "last AXI-Stream tuser readback mismatch");
    axi_read(6'h3c, rd);
    if (rd != 32'd1) $fatal(1, "AXI-Stream tuser error count mismatch");
    axi_read(6'h24, rd);
    if (rd[1] !== 1'b1) $fatal(1, "AXI-Stream tuser sticky error bit was not set");
    axi_write(6'h24, 32'h0000_0002);
    axi_read(6'h24, rd);
    if (rd[1] !== 1'b0) $fatal(1, "AXI-Stream tuser sticky error bit did not clear");
    axi_read(6'h1c, rd);
    if (rd == 32'd0) $fatal(1, "output sample count did not increment");
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
