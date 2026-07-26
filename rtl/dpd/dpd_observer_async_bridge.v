`timescale 1ns/1ps
`default_nettype none

// Dual-clock AXI-Stream bridge for an external PA/ADC observation path.
// Reset must be asserted to both sides together. The source side either
// backpressures (default) or deliberately drops full-FIFO beats.
module dpd_axis_async_fifo #(
  parameter integer DATA_W = 32,
  parameter integer USER_W = 1,
  parameter integer ADDR_W = 4,
  parameter integer DROP_ON_FULL = 0
) (
  input wire s_clk,
  input wire s_rst_n,
  input wire [DATA_W-1:0] s_tdata,
  input wire s_tlast,
  input wire [USER_W-1:0] s_tuser,
  input wire s_tvalid,
  output wire s_tready,
  output reg [31:0] s_stall_count,
  output reg [31:0] s_drop_count,

  input wire m_clk,
  input wire m_rst_n,
  output wire [DATA_W-1:0] m_tdata,
  output wire m_tlast,
  output wire [USER_W-1:0] m_tuser,
  output wire m_tvalid,
  input wire m_tready
);

  localparam integer PTR_W = ADDR_W + 1;
  localparam integer DEPTH = (1 << ADDR_W);

  reg [DATA_W-1:0] data_mem [0:DEPTH-1];
  reg last_mem [0:DEPTH-1];
  reg [USER_W-1:0] user_mem [0:DEPTH-1];

  reg [PTR_W-1:0] wbin;
  reg [PTR_W-1:0] wgray;
  reg [PTR_W-1:0] rbin;
  reg [PTR_W-1:0] rgray;
  reg [PTR_W-1:0] rgray_s1;
  reg [PTR_W-1:0] rgray_s2;
  reg [PTR_W-1:0] wgray_m1;
  reg [PTR_W-1:0] wgray_m2;
  reg wfull;
  reg rempty;

  wire source_full = wfull;
  wire source_drop = s_tvalid && source_full && DROP_ON_FULL;
  wire source_stall = s_tvalid && source_full && !DROP_ON_FULL;
  wire source_store = s_tvalid && !source_full;
  wire source_ready_int = DROP_ON_FULL ? 1'b1 : !source_full;
  wire sink_fire = m_tvalid && m_tready;
  wire [PTR_W-1:0] wbin_next = wbin + source_store;
  wire [PTR_W-1:0] rbin_next = rbin + sink_fire;
  wire [PTR_W-1:0] wgray_next = (wbin_next >> 1) ^ wbin_next;
  wire [PTR_W-1:0] rgray_next = (rbin_next >> 1) ^ rbin_next;
  wire wfull_next = (wgray_next ==
      {~rgray_s2[PTR_W-1:PTR_W-2], rgray_s2[PTR_W-3:0]});
  wire rempty_next = (rgray_next == wgray_m2);

  assign s_tready = source_ready_int;
  assign m_tvalid = !rempty;
  assign m_tdata = data_mem[rbin[ADDR_W-1:0]];
  assign m_tlast = last_mem[rbin[ADDR_W-1:0]];
  assign m_tuser = user_mem[rbin[ADDR_W-1:0]];

  always @(posedge s_clk or negedge s_rst_n) begin
    if (!s_rst_n) begin
      wbin <= {PTR_W{1'b0}};
      wgray <= {PTR_W{1'b0}};
      rgray_s1 <= {PTR_W{1'b0}};
      rgray_s2 <= {PTR_W{1'b0}};
      wfull <= 1'b0;
      s_stall_count <= 32'd0;
      s_drop_count <= 32'd0;
    end else begin
      rgray_s1 <= rgray;
      rgray_s2 <= rgray_s1;
      wbin <= wbin_next;
      wgray <= wgray_next;
      wfull <= wfull_next;
      if (source_store) begin
        data_mem[wbin[ADDR_W-1:0]] <= s_tdata;
        last_mem[wbin[ADDR_W-1:0]] <= s_tlast;
        user_mem[wbin[ADDR_W-1:0]] <= s_tuser;
      end
      if (source_stall) s_stall_count <= s_stall_count + 32'd1;
      if (source_drop) s_drop_count <= s_drop_count + 32'd1;
    end
  end

  always @(posedge m_clk or negedge m_rst_n) begin
    if (!m_rst_n) begin
      rbin <= {PTR_W{1'b0}};
      rgray <= {PTR_W{1'b0}};
      wgray_m1 <= {PTR_W{1'b0}};
      wgray_m2 <= {PTR_W{1'b0}};
      rempty <= 1'b1;
    end else begin
      wgray_m1 <= wgray;
      wgray_m2 <= wgray_m1;
      rbin <= rbin_next;
      rgray <= rgray_next;
      rempty <= rempty_next;
    end
  end

endmodule

// Maps an asynchronous complex feedback stream to the synchronous observer
// contract used by dsm_ip_axi_top and dpd_observer.
module dpd_observer_async_bridge #(
  parameter integer W = 16,
  parameter integer USER_W = 1,
  parameter integer ADDR_W = 4,
  parameter integer DROP_ON_FULL = 0
) (
  input wire feedback_clk,
  input wire feedback_rst_n,
  input wire [(2*W)-1:0] s_axis_tdata,
  input wire s_axis_tlast,
  input wire [USER_W-1:0] s_axis_tuser,
  input wire s_axis_tvalid,
  output wire s_axis_tready,
  output wire [31:0] source_stall_count,
  output wire [31:0] source_drop_count,

  input wire aclk,
  input wire aresetn,
  output wire signed [W-1:0] obs_i,
  output wire signed [W-1:0] obs_q,
  output wire obs_last,
  output wire obs_invalid,
  output wire obs_valid,
  input wire obs_ready
);

  wire [(2*W)-1:0] bridge_tdata;
  wire bridge_tlast;
  wire [USER_W-1:0] bridge_tuser;

  dpd_axis_async_fifo #(
    .DATA_W(2*W),
    .USER_W(USER_W),
    .ADDR_W(ADDR_W),
    .DROP_ON_FULL(DROP_ON_FULL)
  ) u_fifo (
    .s_clk(feedback_clk),
    .s_rst_n(feedback_rst_n),
    .s_tdata(s_axis_tdata),
    .s_tlast(s_axis_tlast),
    .s_tuser(s_axis_tuser),
    .s_tvalid(s_axis_tvalid),
    .s_tready(s_axis_tready),
    .s_stall_count(source_stall_count),
    .s_drop_count(source_drop_count),
    .m_clk(aclk),
    .m_rst_n(aresetn),
    .m_tdata(bridge_tdata),
    .m_tlast(bridge_tlast),
    .m_tuser(bridge_tuser),
    .m_tvalid(obs_valid),
    .m_tready(obs_ready)
  );

  assign obs_i = bridge_tdata[W-1:0];
  assign obs_q = bridge_tdata[(2*W)-1:W];
  assign obs_last = bridge_tlast;
  assign obs_invalid = |bridge_tuser;

endmodule

`default_nettype wire
