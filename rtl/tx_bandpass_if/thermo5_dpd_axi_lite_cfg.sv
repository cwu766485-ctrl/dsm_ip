`timescale 1ns/1ps
`default_nettype none

// AXI4-Lite register bank and bundled-data request/acknowledge CDC for the
// thermo5 memory-DPD configuration. Coefficients remain stable in the AXI
// domain until the core applies the complete bundle at a DPD input frame
// boundary and returns the four-phase acknowledgement.
module thermo5_dpd_axi_lite_cfg #(
  parameter int MAX_TAPS = 4
) (
  input  wire logic         s_axil_aclk,
  input  wire logic         s_axil_aresetn,
  input  wire logic [7:0]   s_axil_awaddr,
  input  wire logic         s_axil_awvalid,
  output wire logic         s_axil_awready,
  input  wire logic [31:0]  s_axil_wdata,
  input  wire logic [3:0]   s_axil_wstrb,
  input  wire logic         s_axil_wvalid,
  output wire logic         s_axil_wready,
  output logic [1:0]        s_axil_bresp,
  output logic              s_axil_bvalid,
  input  wire logic         s_axil_bready,
  input  wire logic [7:0]   s_axil_araddr,
  input  wire logic         s_axil_arvalid,
  output wire logic         s_axil_arready,
  output logic [31:0]       s_axil_rdata,
  output logic [1:0]        s_axil_rresp,
  output logic              s_axil_rvalid,
  input  wire logic         s_axil_rready,

  input  wire logic         core_clk,
  input  wire logic         core_aresetn,
  input  wire logic         dpd_config_boundary,
  output logic              core_enable,
  output logic [2:0]        dpd_active_taps,
  output logic signed [63:0] c1_re,
  output logic signed [63:0] c1_im,
  output logic signed [63:0] c3_re,
  output logic signed [63:0] c3_im,
  output logic signed [63:0] c5_re,
  output logic signed [63:0] c5_im,
  output logic              cfg_busy,
  output logic              cfg_done,
  output logic              cfg_error
);
  localparam logic [7:0] REG_CONTROL = 8'h00;
  localparam logic [7:0] REG_STATUS  = 8'h04;
  localparam logic [7:0] REG_TAPS    = 8'h08;
  localparam logic [7:0] REG_ID      = 8'h0c;
  localparam logic [7:0] REG_C1_RE   = 8'h10;
  localparam logic [7:0] REG_C1_IM   = 8'h18;
  localparam logic [7:0] REG_C3_RE   = 8'h20;
  localparam logic [7:0] REG_C3_IM   = 8'h28;
  localparam logic [7:0] REG_C5_RE   = 8'h30;
  localparam logic [7:0] REG_C5_IM   = 8'h38;
  localparam logic [31:0] IP_ID      = 32'h5448_3501;

  // {tap_count, c1_re, c1_im, c3_re, c3_im, c5_re, c5_im} = 387 bits.
  localparam int CFG_W = 3 + 6*64;

  logic aw_pending, w_pending;
  logic [7:0] awaddr_q;
  logic [31:0] wdata_q;
  logic [3:0] wstrb_q;
  logic [63:0] shadow_c1_re, shadow_c1_im;
  logic [63:0] shadow_c3_re, shadow_c3_im;
  logic [63:0] shadow_c5_re, shadow_c5_im;
  logic [2:0] shadow_taps;
  logic run_request_q;
  logic [CFG_W-1:0] cfg_mailbox_q;
  logic cfg_req_q, cfg_seen_ack_q;

  logic cfg_ack_core;
  (* ASYNC_REG = "TRUE" *) logic cfg_req_sync1, cfg_req_sync2;
  (* ASYNC_REG = "TRUE" *) logic cfg_ack_sync1, cfg_ack_sync2;
  (* ASYNC_REG = "TRUE" *) logic run_sync1, run_sync2;
  logic cfg_pending_valid;
  logic [CFG_W-1:0] cfg_pending_core;
  logic [CFG_W-1:0] cfg_active_core;
  logic [CFG_W-1:0] cfg_for_dpd;
  logic cfg_busy_q, cfg_done_q, cfg_error_q;

  wire logic aw_take = s_axil_awvalid && s_axil_awready;
  wire logic w_take = s_axil_wvalid && s_axil_wready;
  wire logic [7:0] write_addr = aw_pending ? awaddr_q : s_axil_awaddr;
  wire logic [31:0] write_data = w_pending ? wdata_q : s_axil_wdata;
  wire logic [3:0] write_strb = w_pending ? wstrb_q : s_axil_wstrb;
  wire logic write_fire = !s_axil_bvalid && (aw_pending || aw_take) && (w_pending || w_take);
  wire logic tap_count_legal = (shadow_taps >= 1) && (shadow_taps <= MAX_TAPS);
  logic [1:0] write_resp;
  logic [31:0] read_data_mux;
  logic [1:0] read_resp_mux;

  assign s_axil_awready = !aw_pending && !s_axil_bvalid;
  assign s_axil_wready  = !w_pending && !s_axil_bvalid;
  assign s_axil_arready = !s_axil_rvalid;
  assign core_enable = run_sync2;
  assign cfg_busy = cfg_busy_q;
  assign cfg_done = cfg_done_q;
  assign cfg_error = cfg_error_q;

  function automatic logic [31:0] merge_bytes(
    input logic [31:0] old_value,
    input logic [31:0] new_value,
    input logic [3:0] strobe
  );
    logic [31:0] result;
    begin
      result = old_value;
      for (int b = 0; b < 4; b++)
        if (strobe[b]) result[b*8 +: 8] = new_value[b*8 +: 8];
      return result;
    end
  endfunction

  function automatic logic coeff_word_addr(input logic [7:0] addr);
    begin
      case (addr)
        8'h10,8'h14,8'h18,8'h1c,8'h20,8'h24,
        8'h28,8'h2c,8'h30,8'h34,8'h38,8'h3c: coeff_word_addr = 1'b1;
        default: coeff_word_addr = 1'b0;
      endcase
    end
  endfunction

  function automatic logic [31:0] coeff_read_word(input logic [7:0] addr);
    logic [63:0] selected;
    begin
      case (addr & 8'hf8)
        REG_C1_RE: selected = shadow_c1_re;
        REG_C1_IM: selected = shadow_c1_im;
        REG_C3_RE: selected = shadow_c3_re;
        REG_C3_IM: selected = shadow_c3_im;
        REG_C5_RE: selected = shadow_c5_re;
        REG_C5_IM: selected = shadow_c5_im;
        default: selected = '0;
      endcase
      return addr[2] ? selected[63:32] : selected[31:0];
    end
  endfunction

  always_comb begin
    write_resp = 2'b00; // OKAY
    if (write_addr == REG_CONTROL) begin
      if (write_strb[0] && write_data[1] &&
          (cfg_busy_q || !tap_count_legal))
        write_resp = 2'b10; // SLVERR: busy or illegal active tap count
    end else if (write_addr == REG_STATUS || write_addr == REG_TAPS ||
                 coeff_word_addr(write_addr)) begin
      write_resp = 2'b00;
    end else begin
      write_resp = 2'b11; // DECERR
    end
  end

  always_comb begin
    read_data_mux = 32'd0;
    read_resp_mux = 2'b00;
    case (s_axil_araddr)
      REG_CONTROL: read_data_mux = {31'd0,run_request_q};
      REG_STATUS: begin
        read_data_mux[0] = cfg_busy_q;
        read_data_mux[1] = cfg_done_q;
        read_data_mux[2] = cfg_error_q;
      end
      REG_TAPS: read_data_mux = {29'd0,shadow_taps};
      REG_ID: read_data_mux = IP_ID;
      default: begin
        if (coeff_word_addr(s_axil_araddr))
          read_data_mux = coeff_read_word(s_axil_araddr);
        else
          read_resp_mux = 2'b11;
      end
    endcase
  end

  // AXI-Lite slave and source-domain shadow register bank. AW and W are
  // independently buffered; one write response is outstanding at a time.
  always_ff @(posedge s_axil_aclk or negedge s_axil_aresetn) begin
    if (!s_axil_aresetn) begin
      aw_pending <= 1'b0;
      w_pending <= 1'b0;
      awaddr_q <= '0;
      wdata_q <= '0;
      wstrb_q <= '0;
      s_axil_bresp <= 2'b00;
      s_axil_bvalid <= 1'b0;
      s_axil_rdata <= '0;
      s_axil_rresp <= 2'b00;
      s_axil_rvalid <= 1'b0;
      shadow_taps <= 3'd1;
      shadow_c1_re <= 32'h0000_4000;
      shadow_c1_im <= '0;
      shadow_c3_re <= '0;
      shadow_c3_im <= '0;
      shadow_c5_re <= '0;
      shadow_c5_im <= '0;
      run_request_q <= 1'b0;
      cfg_mailbox_q <= {3'd1,64'h0000_0000_0000_4000,64'd0,64'd0,64'd0,64'd0,64'd0};
      cfg_req_q <= 1'b0;
      cfg_seen_ack_q <= 1'b0;
      cfg_ack_sync1 <= 1'b0;
      cfg_ack_sync2 <= 1'b0;
      cfg_busy_q <= 1'b0;
      cfg_done_q <= 1'b0;
      cfg_error_q <= 1'b0;
    end else begin
      cfg_ack_sync1 <= cfg_ack_core;
      cfg_ack_sync2 <= cfg_ack_sync1;

      if (s_axil_bvalid && s_axil_bready) s_axil_bvalid <= 1'b0;
      if (s_axil_rvalid && s_axil_rready) s_axil_rvalid <= 1'b0;
      if (aw_take) begin
        aw_pending <= 1'b1;
        awaddr_q <= s_axil_awaddr;
      end
      if (w_take) begin
        w_pending <= 1'b1;
        wdata_q <= s_axil_wdata;
        wstrb_q <= s_axil_wstrb;
      end

      if (write_fire) begin
        aw_pending <= 1'b0;
        w_pending <= 1'b0;
        s_axil_bvalid <= 1'b1;
        s_axil_bresp <= write_resp;
        if (write_resp != 2'b00) begin
          if (write_addr == REG_CONTROL) cfg_error_q <= 1'b1;
        end else begin
          case (write_addr)
            REG_CONTROL: begin
              if (write_strb[0]) begin
                run_request_q <= write_data[0];
                if (write_data[1]) begin
                  cfg_mailbox_q <= {shadow_taps, shadow_c1_re, shadow_c1_im,
                    shadow_c3_re, shadow_c3_im, shadow_c5_re, shadow_c5_im};
                  cfg_req_q <= 1'b1;
                  cfg_busy_q <= 1'b1;
                  cfg_done_q <= 1'b0;
                  cfg_seen_ack_q <= 1'b0;
                end
              end
            end
            REG_STATUS: begin
              if (write_strb[0] && write_data[1]) cfg_done_q <= 1'b0;
              if (write_strb[0] && write_data[2]) cfg_error_q <= 1'b0;
            end
            REG_TAPS: begin
              if (write_strb[0]) shadow_taps <= write_data[2:0];
            end
            REG_C1_RE: shadow_c1_re[31:0] <= merge_bytes(shadow_c1_re[31:0],write_data,write_strb);
            REG_C1_RE+8'h04: shadow_c1_re[63:32] <= merge_bytes(shadow_c1_re[63:32],write_data,write_strb);
            REG_C1_IM: shadow_c1_im[31:0] <= merge_bytes(shadow_c1_im[31:0],write_data,write_strb);
            REG_C1_IM+8'h04: shadow_c1_im[63:32] <= merge_bytes(shadow_c1_im[63:32],write_data,write_strb);
            REG_C3_RE: shadow_c3_re[31:0] <= merge_bytes(shadow_c3_re[31:0],write_data,write_strb);
            REG_C3_RE+8'h04: shadow_c3_re[63:32] <= merge_bytes(shadow_c3_re[63:32],write_data,write_strb);
            REG_C3_IM: shadow_c3_im[31:0] <= merge_bytes(shadow_c3_im[31:0],write_data,write_strb);
            REG_C3_IM+8'h04: shadow_c3_im[63:32] <= merge_bytes(shadow_c3_im[63:32],write_data,write_strb);
            REG_C5_RE: shadow_c5_re[31:0] <= merge_bytes(shadow_c5_re[31:0],write_data,write_strb);
            REG_C5_RE+8'h04: shadow_c5_re[63:32] <= merge_bytes(shadow_c5_re[63:32],write_data,write_strb);
            REG_C5_IM: shadow_c5_im[31:0] <= merge_bytes(shadow_c5_im[31:0],write_data,write_strb);
            REG_C5_IM+8'h04: shadow_c5_im[63:32] <= merge_bytes(shadow_c5_im[63:32],write_data,write_strb);
            default: begin end
          endcase
        end
      end

      if (cfg_busy_q) begin
        if (cfg_ack_sync2) begin
          cfg_req_q <= 1'b0;
          cfg_seen_ack_q <= 1'b1;
        end else if (cfg_seen_ack_q) begin
          cfg_busy_q <= 1'b0;
          cfg_done_q <= 1'b1;
          cfg_seen_ack_q <= 1'b0;
        end
      end

      if (s_axil_arvalid && s_axil_arready) begin
        s_axil_rvalid <= 1'b1;
        s_axil_rdata <= read_data_mux;
        s_axil_rresp <= read_resp_mux;
      end
    end
  end

  // Core-domain request synchronizer and pending/active banks. The source
  // mailbox is held stable for the full four-phase handshake. The pending
  // bundle is applied to the very frame-start word as it enters the DPD.
  always_ff @(posedge core_clk or negedge core_aresetn) begin
    if (!core_aresetn) begin
      cfg_req_sync1 <= 1'b0;
      cfg_req_sync2 <= 1'b0;
      run_sync1 <= 1'b0;
      run_sync2 <= 1'b0;
      cfg_ack_core <= 1'b0;
      cfg_pending_valid <= 1'b0;
      cfg_pending_core <= {3'd1,64'h0000_0000_0000_4000,64'd0,64'd0,64'd0,64'd0,64'd0};
      cfg_active_core <= {3'd1,64'h0000_0000_0000_4000,64'd0,64'd0,64'd0,64'd0,64'd0};
    end else begin
      cfg_req_sync1 <= cfg_req_q;
      cfg_req_sync2 <= cfg_req_sync1;
      run_sync1 <= run_request_q;
      run_sync2 <= run_sync1;

      if (!cfg_req_sync2) begin
        cfg_ack_core <= 1'b0;
        cfg_pending_valid <= 1'b0;
      end else if (!cfg_ack_core && !cfg_pending_valid) begin
        cfg_pending_core <= cfg_mailbox_q;
        cfg_pending_valid <= 1'b1;
      end

      if (cfg_req_sync2 && cfg_pending_valid && dpd_config_boundary) begin
        cfg_active_core <= cfg_pending_core;
        cfg_pending_valid <= 1'b0;
        cfg_ack_core <= 1'b1;
      end
    end
  end

  always_comb begin
    cfg_for_dpd = (cfg_pending_valid && dpd_config_boundary) ?
                  cfg_pending_core : cfg_active_core;
    {dpd_active_taps,c1_re,c1_im,c3_re,c3_im,c5_re,c5_im} = cfg_for_dpd;
  end

  initial begin
    if (MAX_TAPS < 1 || MAX_TAPS > 4)
      $error("MAX_TAPS must be in [1,4]; got %0d",MAX_TAPS);
  end

`ifndef SYNTHESIS
  // The bundled payload must not change while the request is outstanding.
  logic [CFG_W-1:0] mailbox_hold;
  logic mailbox_tracking;
  always_ff @(posedge s_axil_aclk or negedge s_axil_aresetn) begin
    if (!s_axil_aresetn) begin
      mailbox_hold <= '0;
      mailbox_tracking <= 1'b0;
    end else begin
      if (cfg_req_q && !mailbox_tracking) begin
        mailbox_hold <= cfg_mailbox_q;
        mailbox_tracking <= 1'b1;
      end else if (cfg_req_q && mailbox_tracking && cfg_mailbox_q !== mailbox_hold) begin
        $error("thermo5 DPD CDC mailbox changed before acknowledgement");
      end else if (!cfg_req_q) begin
        mailbox_tracking <= 1'b0;
      end
    end
  end
`endif
endmodule

`default_nettype wire
