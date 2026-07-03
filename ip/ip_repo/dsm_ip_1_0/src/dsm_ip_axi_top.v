`timescale 1ns/1ps
`default_nettype none

module dsm_ip_axi_top #(
  parameter integer W = 16,
  parameter integer RF_W = 16,
  parameter integer PHASE_W = 24,
  parameter integer LUT_AW = 10,
  parameter integer TW_W = 16,
  parameter integer ALGORITHM = 2,
  parameter integer DUC_MODE = 0,
  parameter integer CLK_FREQ_HZ = 100000000,
  parameter integer BB_SAMPLE_RATE_HZ = 3125000,
  parameter integer SIGNAL_BW_HZ = 2539062,
  parameter integer C_S_AXI_ADDR_WIDTH = 6,
  parameter integer C_S_AXI_DATA_WIDTH = 32,
  parameter integer C_S_AXIS_TDATA_WIDTH = 32
) (
  input wire aclk,
  input wire aresetn,

  input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
  input wire s_axi_awvalid,
  output reg s_axi_awready,
  input wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
  input wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
  input wire s_axi_wvalid,
  output reg s_axi_wready,
  output reg [1:0] s_axi_bresp,
  output reg s_axi_bvalid,
  input wire s_axi_bready,

  input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
  input wire s_axi_arvalid,
  output reg s_axi_arready,
  output reg [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
  output reg [1:0] s_axi_rresp,
  output reg s_axi_rvalid,
  input wire s_axi_rready,

  input wire [C_S_AXIS_TDATA_WIDTH-1:0] s_axis_tdata,
  input wire s_axis_tvalid,
  output wire s_axis_tready,

  output wire dsm_valid,
  output wire i_bit,
  output wire q_bit,
  output wire signed [3:0] i_yout,
  output wire signed [3:0] q_yout,
  output wire rf_valid,
  output wire rf_bit,
  output wire signed [RF_W-1:0] rf_signed,
  output wire [PHASE_W-1:0] phase_acc_dbg
);

  localparam [31:0] CORE_VERSION = 32'h0001_0000;

  reg [31:0] ctrl_reg;
  reg [PHASE_W-1:0] phase_inc_reg;

  wire core_enable = ctrl_reg[0];
  wire soft_reset = ctrl_reg[1];
  wire core_rst_n = aresetn & ~soft_reset;
  wire axis_fire = s_axis_tvalid & s_axis_tready;

  wire signed [W-1:0] axis_i = s_axis_tdata[W-1:0];
  wire signed [W-1:0] axis_q = s_axis_tdata[(2*W)-1:W];

  assign s_axis_tready = core_enable & core_rst_n;

  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      s_axi_awready <= 1'b0;
      s_axi_wready <= 1'b0;
      s_axi_bresp <= 2'b00;
      s_axi_bvalid <= 1'b0;
      ctrl_reg <= 32'h0000_0000;
      phase_inc_reg <= {{(PHASE_W-24){1'b0}}, 24'h400000};
    end else begin
      s_axi_awready <= 1'b0;
      s_axi_wready <= 1'b0;

      if (!s_axi_bvalid && s_axi_awvalid && s_axi_wvalid) begin
        s_axi_awready <= 1'b1;
        s_axi_wready <= 1'b1;
        s_axi_bvalid <= 1'b1;
        s_axi_bresp <= 2'b00;

        case (s_axi_awaddr[5:2])
          4'h0: begin
            if (s_axi_wstrb[0]) ctrl_reg[7:0] <= s_axi_wdata[7:0];
            if (s_axi_wstrb[1]) ctrl_reg[15:8] <= s_axi_wdata[15:8];
            if (s_axi_wstrb[2]) ctrl_reg[23:16] <= s_axi_wdata[23:16];
            if (s_axi_wstrb[3]) ctrl_reg[31:24] <= s_axi_wdata[31:24];
          end
          4'h2: begin
            if (PHASE_W <= 32) begin
              phase_inc_reg <= s_axi_wdata[PHASE_W-1:0];
            end
          end
          default: begin
          end
        endcase
      end else if (s_axi_bvalid && s_axi_bready) begin
        s_axi_bvalid <= 1'b0;
      end
    end
  end

  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      s_axi_arready <= 1'b0;
      s_axi_rdata <= 32'h0000_0000;
      s_axi_rresp <= 2'b00;
      s_axi_rvalid <= 1'b0;
    end else begin
      s_axi_arready <= 1'b0;

      if (!s_axi_rvalid && s_axi_arvalid) begin
        s_axi_arready <= 1'b1;
        s_axi_rvalid <= 1'b1;
        s_axi_rresp <= 2'b00;
        case (s_axi_araddr[5:2])
          4'h0: s_axi_rdata <= ctrl_reg;
          4'h1: s_axi_rdata <= {27'b0, s_axis_tready, rf_valid, dsm_valid, soft_reset, core_enable};
          4'h2: s_axi_rdata <= {{(32-PHASE_W){1'b0}}, phase_inc_reg};
          4'h3: s_axi_rdata <= ALGORITHM[31:0];
          4'h4: s_axi_rdata <= DUC_MODE[31:0];
          4'h5: s_axi_rdata <= CORE_VERSION;
          default: s_axi_rdata <= 32'h0000_0000;
        endcase
      end else if (s_axi_rvalid && s_axi_rready) begin
        s_axi_rvalid <= 1'b0;
      end
    end
  end

  dsm_ip_top #(
    .W(W),
    .RF_W(RF_W),
    .PHASE_W(PHASE_W),
    .LUT_AW(LUT_AW),
    .TW_W(TW_W),
    .ALGORITHM(ALGORITHM),
    .DUC_MODE(DUC_MODE),
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .BB_SAMPLE_RATE_HZ(BB_SAMPLE_RATE_HZ),
    .SIGNAL_BW_HZ(SIGNAL_BW_HZ)
  ) u_dsm_ip_top (
    .clk(aclk),
    .rst_n(core_rst_n),
    .in_valid(axis_fire),
    .cfg_phase_inc(phase_inc_reg),
    .i_in(axis_i),
    .q_in(axis_q),
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

endmodule

`default_nettype wire
