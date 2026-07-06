`timescale 1ns/1ps
`default_nettype none

module dsm_ip_axi_top #(
  parameter integer W = 16,
  parameter integer DSM_OUT_W = 8,
  parameter integer RF_W = 16,
  parameter integer PHASE_W = 24,
  parameter integer LUT_AW = 10,
  parameter integer TW_W = 16,
  parameter integer ALGORITHM = 2,
  parameter integer DUC_MODE = 0,
  parameter integer INTERP_MODE = 0,
  parameter integer CLK_FREQ_HZ = 100000000,
  parameter integer BB_SAMPLE_RATE_HZ = 3125000,
  parameter integer SIGNAL_BW_HZ = 2539062,
  parameter integer C_S_AXI_ADDR_WIDTH = 6,
  parameter integer C_S_AXI_DATA_WIDTH = 32,
  parameter integer C_S_AXIS_TDATA_WIDTH = 32,
  parameter integer C_S_AXIS_TUSER_WIDTH = 1
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
  input wire s_axis_tlast,
  input wire [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
  input wire s_axis_tvalid,
  output wire s_axis_tready,

  output wire dsm_valid,
  output wire i_bit,
  output wire q_bit,
  output wire signed [DSM_OUT_W-1:0] i_yout,
  output wire signed [DSM_OUT_W-1:0] q_yout,
  output wire rf_valid,
  output wire rf_bit,
  output wire signed [RF_W-1:0] rf_signed,
  output wire [PHASE_W-1:0] phase_acc_dbg
);

  localparam [31:0] CORE_VERSION = 32'h0001_0000;
  localparam [3:0] ADDR_CTRL       = 4'h0;
  localparam [3:0] ADDR_STATUS     = 4'h1;
  localparam [3:0] ADDR_PHASE_INC  = 4'h2;
  localparam [3:0] ADDR_ALGORITHM  = 4'h3;
  localparam [3:0] ADDR_DUC_MODE   = 4'h4;
  localparam [3:0] ADDR_VERSION    = 4'h5;
  localparam [3:0] ADDR_IN_COUNT   = 4'h6;
  localparam [3:0] ADDR_OUT_COUNT  = 4'h7;
  localparam [3:0] ADDR_RESET_CNT  = 4'h8;
  localparam [3:0] ADDR_ERROR      = 4'h9;
  localparam [3:0] ADDR_FRONT_COUNT = 4'ha;
  localparam [3:0] ADDR_STALL_COUNT = 4'hb;
  localparam [3:0] ADDR_INTERP_MODE = 4'hc;
  localparam [3:0] ADDR_FRAME_COUNT = 4'hd;
  localparam [3:0] ADDR_LAST_TUSER  = 4'he;
  localparam [3:0] ADDR_USER_ERR_COUNT = 4'hf;

  reg [31:0] ctrl_reg;
  reg [PHASE_W-1:0] phase_inc_reg;
  reg soft_reset_pulse;
  reg [31:0] input_sample_count;
  reg [31:0] frontend_sample_count;
  reg [31:0] output_sample_count;
  reg [31:0] input_stall_count;
  reg [31:0] software_reset_count;
  reg [31:0] error_status_reg;
  reg [31:0] input_frame_count;
  reg [31:0] user_error_count;
  reg [C_S_AXIS_TUSER_WIDTH-1:0] last_tuser_reg;

  wire core_enable = ctrl_reg[0];
  wire soft_reset = soft_reset_pulse;
  wire core_rst_n = aresetn & ~soft_reset;
  wire axis_fire = s_axis_tvalid & s_axis_tready;
  wire frontend_fire;
  wire clear_status_req = s_axi_awvalid & s_axi_wvalid &
                          (s_axi_awaddr[5:2] == 4'h0) &
                          s_axi_wstrb[0] & s_axi_wdata[2];
  wire stream_while_disabled = s_axis_tvalid & (!core_enable | !core_rst_n);
  wire stream_stall = s_axis_tvalid & !s_axis_tready & core_enable & core_rst_n;

  wire [C_S_AXIS_TDATA_WIDTH-1:0] axis_buf_tdata;
  wire axis_buf_tlast;
  wire [C_S_AXIS_TUSER_WIDTH-1:0] axis_buf_tuser;
  wire axis_buf_valid;
  wire axis_buf_ready;
  wire axis_buf_full;
  wire axis_user_error = |s_axis_tuser;
  wire signed [W-1:0] axis_i = axis_buf_tdata[W-1:0];
  wire signed [W-1:0] axis_q = axis_buf_tdata[(2*W)-1:W];

  wire dsm_input_ready;

  axis_skid_buffer #(
    .DATA_W(C_S_AXIS_TDATA_WIDTH),
    .USER_W(C_S_AXIS_TUSER_WIDTH)
  ) u_axis_skid (
    .clk(aclk),
    .rst_n(aresetn),
    .clear(!core_rst_n),
    .s_data(s_axis_tdata),
    .s_last(s_axis_tlast),
    .s_user(s_axis_tuser),
    .s_valid(s_axis_tvalid & core_enable & core_rst_n),
    .s_ready(axis_buf_ready),
    .m_data(axis_buf_tdata),
    .m_last(axis_buf_tlast),
    .m_user(axis_buf_tuser),
    .m_valid(axis_buf_valid),
    .m_ready(dsm_input_ready & core_enable & core_rst_n),
    .full(axis_buf_full)
  );

  assign s_axis_tready = core_enable & core_rst_n & axis_buf_ready;
  assign frontend_fire = axis_buf_valid & dsm_input_ready & core_enable & core_rst_n;

  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      s_axi_awready <= 1'b0;
      s_axi_wready <= 1'b0;
      s_axi_bresp <= 2'b00;
      s_axi_bvalid <= 1'b0;
      ctrl_reg <= 32'h0000_0000;
      phase_inc_reg <= {{(PHASE_W-24){1'b0}}, 24'h400000};
      soft_reset_pulse <= 1'b0;
      input_sample_count <= 32'd0;
      frontend_sample_count <= 32'd0;
      output_sample_count <= 32'd0;
      input_stall_count <= 32'd0;
      software_reset_count <= 32'd0;
      error_status_reg <= 32'd0;
      input_frame_count <= 32'd0;
      user_error_count <= 32'd0;
      last_tuser_reg <= {C_S_AXIS_TUSER_WIDTH{1'b0}};
    end else begin
      s_axi_awready <= 1'b0;
      s_axi_wready <= 1'b0;
      soft_reset_pulse <= 1'b0;

      if (axis_fire) begin
        input_sample_count <= input_sample_count + 32'd1;
        last_tuser_reg <= s_axis_tuser;
        if (s_axis_tlast) begin
          input_frame_count <= input_frame_count + 32'd1;
        end
        if (axis_user_error) begin
          error_status_reg[1] <= 1'b1;
          user_error_count <= user_error_count + 32'd1;
        end
      end

      if (frontend_fire) begin
        frontend_sample_count <= frontend_sample_count + 32'd1;
      end

      if (rf_valid) begin
        output_sample_count <= output_sample_count + 32'd1;
      end

      if (stream_stall) begin
        input_stall_count <= input_stall_count + 32'd1;
      end

      if (stream_while_disabled) begin
        error_status_reg[0] <= 1'b1;
      end

      if (clear_status_req) begin
        input_sample_count <= 32'd0;
        frontend_sample_count <= 32'd0;
        output_sample_count <= 32'd0;
        input_stall_count <= 32'd0;
        error_status_reg <= 32'd0;
        input_frame_count <= 32'd0;
        user_error_count <= 32'd0;
        last_tuser_reg <= {C_S_AXIS_TUSER_WIDTH{1'b0}};
      end

      if (!s_axi_bvalid && s_axi_awvalid && s_axi_wvalid) begin
        s_axi_awready <= 1'b1;
        s_axi_wready <= 1'b1;
        s_axi_bvalid <= 1'b1;
        s_axi_bresp <= 2'b00;

        case (s_axi_awaddr[5:2])
          ADDR_CTRL: begin
            if (s_axi_wstrb[0]) begin
              ctrl_reg[0] <= s_axi_wdata[0];
              if (s_axi_wdata[1]) begin
                soft_reset_pulse <= 1'b1;
                software_reset_count <= software_reset_count + 32'd1;
              end
            end
            if (s_axi_wstrb[1]) ctrl_reg[15:8] <= s_axi_wdata[15:8];
            if (s_axi_wstrb[2]) ctrl_reg[23:16] <= s_axi_wdata[23:16];
            if (s_axi_wstrb[3]) ctrl_reg[31:24] <= s_axi_wdata[31:24];
          end
          ADDR_PHASE_INC: begin
            if (PHASE_W <= 32) begin
              phase_inc_reg <= s_axi_wdata[PHASE_W-1:0];
            end
          end
          ADDR_ERROR: begin
            error_status_reg <= error_status_reg & ~s_axi_wdata;
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
          ADDR_CTRL:      s_axi_rdata <= ctrl_reg;
          ADDR_STATUS:    s_axi_rdata <= {25'b0, axis_buf_full, |error_status_reg, s_axis_tready, rf_valid, dsm_valid, soft_reset, core_enable};
          ADDR_PHASE_INC: s_axi_rdata <= {{(32-PHASE_W){1'b0}}, phase_inc_reg};
          ADDR_ALGORITHM: s_axi_rdata <= ALGORITHM[31:0];
          ADDR_DUC_MODE:  s_axi_rdata <= DUC_MODE[31:0];
          ADDR_VERSION:   s_axi_rdata <= CORE_VERSION;
          ADDR_IN_COUNT:  s_axi_rdata <= input_sample_count;
          ADDR_OUT_COUNT: s_axi_rdata <= output_sample_count;
          ADDR_RESET_CNT: s_axi_rdata <= software_reset_count;
          ADDR_ERROR:     s_axi_rdata <= error_status_reg;
          ADDR_FRONT_COUNT: s_axi_rdata <= frontend_sample_count;
          ADDR_STALL_COUNT: s_axi_rdata <= input_stall_count;
          ADDR_INTERP_MODE: s_axi_rdata <= INTERP_MODE[31:0];
          ADDR_FRAME_COUNT: s_axi_rdata <= input_frame_count;
          ADDR_LAST_TUSER:  s_axi_rdata <= {{(32-C_S_AXIS_TUSER_WIDTH){1'b0}}, last_tuser_reg};
          ADDR_USER_ERR_COUNT: s_axi_rdata <= user_error_count;
          default: s_axi_rdata <= 32'h0000_0000;
        endcase
      end else if (s_axi_rvalid && s_axi_rready) begin
        s_axi_rvalid <= 1'b0;
      end
    end
  end

  dsm_ip_top #(
    .W(W),
    .DSM_OUT_W(DSM_OUT_W),
    .RF_W(RF_W),
    .PHASE_W(PHASE_W),
    .LUT_AW(LUT_AW),
    .TW_W(TW_W),
    .ALGORITHM(ALGORITHM),
    .DUC_MODE(DUC_MODE),
    .INTERP_MODE(INTERP_MODE),
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .BB_SAMPLE_RATE_HZ(BB_SAMPLE_RATE_HZ),
    .SIGNAL_BW_HZ(SIGNAL_BW_HZ)
  ) u_dsm_ip_top (
    .clk(aclk),
    .rst_n(core_rst_n),
    .in_valid(frontend_fire),
    .cfg_phase_inc(phase_inc_reg),
    .i_in(axis_i),
    .q_in(axis_q),
    .in_ready(dsm_input_ready),
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
