`timescale 1ns/1ps
`default_nettype none

// AXI4-Lite register bank and bundled-data request/acknowledge CDC for the
// thermo5 memory-DPD configuration. Coefficients remain stable in the AXI
// domain until the core applies the complete bundle at a DPD input frame
// boundary and returns the four-phase acknowledgement.
module thermo5_dpd_axi_lite_cfg_epoch_candidate2 #(
  parameter int MAX_TAPS = 4,
  parameter bit ENABLE_RUNTIME_DSM = 1'b0
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
  input  wire logic         core_tx_active,
  input  wire logic         core_draining,
  output logic              core_enable,
  output logic              run_request,
  output logic [2:0]        dpd_active_taps,
  output logic signed [63:0] c1_re,
  output logic signed [63:0] c1_im,
  output logic signed [63:0] c3_re,
  output logic signed [63:0] c3_im,
  output logic signed [63:0] c5_re,
  output logic signed [63:0] c5_im,
  output logic              cfg_busy,
  output logic              cfg_done,
  output logic              cfg_error,
  input  wire logic         dsm_switch_idle,
  input  wire logic         dsm_source_locked,
  output wire logic         dsm_switch_pending,
  output wire logic         dsm_switch_busy,
  output logic [1:0]        dsm_arch,
  output logic              dsm_reset_pulse,
  output logic [15:0]       dsm_config_id
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
  localparam logic [7:0] REG_DSM_ARCH = 8'h40;
  localparam logic [7:0] REG_DSM_STATUS = 8'h44;
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
  (* ASYNC_REG = "TRUE" *) logic tx_active_sync1, tx_active_sync2;
  (* ASYNC_REG = "TRUE" *) logic draining_sync1, draining_sync2;
  logic cfg_pending_valid;
  logic [CFG_W-1:0] cfg_pending_core;
  logic [CFG_W-1:0] cfg_active_core;
  logic [CFG_W-1:0] cfg_for_dpd;
  logic cfg_busy_q, cfg_done_q, cfg_error_q;
  wire logic cfg_epoch_arst_n = core_aresetn && s_axil_aresetn;
  wire logic cfg_epoch_axil_n, cfg_epoch_core_n;
  logic epoch_abort_write_q;
  dsm_reset_sync cfg_epoch_source_sync (.clk(s_axil_aclk), .arst_n(cfg_epoch_arst_n), .srst_n(cfg_epoch_axil_n));
  dsm_reset_sync cfg_epoch_core_sync (.clk(core_clk), .arst_n(cfg_epoch_axil_n), .srst_n(cfg_epoch_core_n));

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
  logic [1:0] arch_mailbox,arch_pending_core;
  logic arch_req_q,arch_seen_ack,arch_busy_q,arch_done_q,arch_error_q;
  logic arch_ack_core,arch_error_core;
  (* ASYNC_REG="TRUE" *) logic arch_req_c1,arch_req_c2;
  (* ASYNC_REG="TRUE" *) logic arch_ack_a1,arch_ack_a2;
  (* ASYNC_REG="TRUE" *) logic arch_error_a1,arch_error_a2;
  logic [1:0] arch_active_status;
  logic [1:0] arch_phase;
  assign dsm_switch_pending = ENABLE_RUNTIME_DSM && arch_busy_q;
  assign dsm_switch_busy = ENABLE_RUNTIME_DSM && arch_busy_q;

  assign s_axil_awready = !aw_pending && !s_axil_bvalid;
  assign s_axil_wready  = !w_pending && !s_axil_bvalid;
  assign s_axil_arready = !s_axil_rvalid;
  assign core_enable = run_sync2;
  assign run_request = run_request_q;
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
    if (epoch_abort_write_q || (!cfg_epoch_axil_n &&
        ((write_addr == REG_CONTROL && write_strb[0] && write_data[1]) ||
         (ENABLE_RUNTIME_DSM && write_addr == REG_DSM_ARCH && write_strb[0])))) begin
      write_resp = 2'b10;
    end else if (write_addr == REG_CONTROL) begin
      if (write_strb[0] && write_data[1] &&
          (cfg_busy_q || !tap_count_legal))
        write_resp = 2'b10; // SLVERR: busy or illegal active tap count
      if (ENABLE_RUNTIME_DSM && write_strb[0] && (|write_data[1:0]) && arch_busy_q)
        write_resp = 2'b10;
    end else if (ENABLE_RUNTIME_DSM && write_addr==REG_DSM_ARCH) begin
      if(write_strb[0] && (write_data[7:0]>2 || run_request_q ||
          tx_active_sync2 || draining_sync2 || arch_busy_q || cfg_busy_q))
        write_resp = 2'b10;
    end else if(ENABLE_RUNTIME_DSM && write_addr==REG_DSM_STATUS) begin
      write_resp=2'b00;
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
        // These are synchronized status levels from the graceful-stop core.
        read_data_mux[3] = tx_active_sync2;
        read_data_mux[4] = draining_sync2;
      end
      REG_TAPS: read_data_mux = {29'd0,shadow_taps};
      REG_ID: read_data_mux = ENABLE_RUNTIME_DSM ? 32'h5448_3502 : IP_ID;
      REG_DSM_ARCH: begin
        if(ENABLE_RUNTIME_DSM) read_data_mux={30'd0,arch_active_status};
        else read_resp_mux=2'b11;
      end
      REG_DSM_STATUS: begin
        if(ENABLE_RUNTIME_DSM) begin
          read_data_mux[1:0]=arch_active_status;
          read_data_mux[8]=arch_busy_q;
          read_data_mux[9]=arch_done_q;
          read_data_mux[10]=arch_error_q;
        end else read_resp_mux=2'b11;
      end
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
      epoch_abort_write_q <= 1'b0;
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
      tx_active_sync1 <= 1'b0;
      tx_active_sync2 <= 1'b0;
      draining_sync1 <= 1'b0;
      draining_sync2 <= 1'b0;
      cfg_busy_q <= 1'b0;
      cfg_done_q <= 1'b0;
      cfg_error_q <= 1'b0;
      arch_mailbox<=1;arch_req_q<=0;arch_seen_ack<=0;
      arch_busy_q<=0;arch_done_q<=0;arch_error_q<=0;
      arch_ack_a1<=0;arch_ack_a2<=0;arch_error_a1<=0;arch_error_a2<=0;
      arch_active_status<=1;
    end else begin
      arch_ack_a1<=arch_ack_core;arch_ack_a2<=arch_ack_a1;
      arch_error_a1<=arch_error_core;arch_error_a2<=arch_error_a1;
      cfg_ack_sync1 <= cfg_ack_core;
      cfg_ack_sync2 <= cfg_ack_sync1;
      tx_active_sync1 <= core_tx_active;
      tx_active_sync2 <= tx_active_sync1;
      draining_sync1 <= core_draining;
      draining_sync2 <= draining_sync1;
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

      if (!cfg_epoch_axil_n && (aw_pending || w_pending || aw_take || w_take))
        epoch_abort_write_q <= 1'b1;
      if (write_fire) begin
        epoch_abort_write_q <= 1'b0;
        aw_pending <= 1'b0;
        w_pending <= 1'b0;
        s_axil_bvalid <= 1'b1;
        s_axil_bresp <= write_resp;
        if (write_resp != 2'b00) begin
          if (write_addr == REG_CONTROL) cfg_error_q <= 1'b1;
          if (ENABLE_RUNTIME_DSM && write_addr==REG_DSM_ARCH) arch_error_q<=1;
        end else begin
          case (write_addr)
            REG_DSM_ARCH: if(ENABLE_RUNTIME_DSM && write_strb[0]) begin
              arch_mailbox<=write_data[1:0];arch_req_q<=1;arch_seen_ack<=0;
              arch_busy_q<=1;arch_done_q<=0;arch_error_q<=0;
            end
            REG_DSM_STATUS: if(ENABLE_RUNTIME_DSM && write_strb[1]) begin
              if(write_data[9]) arch_done_q<=0;
              if(write_data[10]) arch_error_q<=0;
            end
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

      // Four-phase bundled-data transfer. The selected architecture is never
      // a directly synchronized multi-bit bus. ACK follows the decision by a
      // core cycle; the source mailbox stays fixed until ACK returns low.
      if(ENABLE_RUNTIME_DSM && arch_busy_q) begin
        if(arch_ack_a2) begin
          arch_req_q<=0;arch_seen_ack<=1;
          arch_error_q<=arch_error_q || arch_error_a2;
          if(!arch_error_a2) arch_active_status<=arch_mailbox;
        end else if(arch_seen_ack) begin
          arch_busy_q<=0;arch_done_q<=!arch_error_a2;arch_seen_ack<=0;
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

      // Keep AXI-Lite transport and any presented B response intact. A Core
      // reset aborts outstanding mailbox requests and raises sticky status.
      if (!cfg_epoch_axil_n) begin
        if (cfg_busy_q) cfg_error_q <= 1'b1;
        cfg_req_q <= 1'b0; cfg_busy_q <= 1'b0; cfg_seen_ack_q <= 1'b0; cfg_done_q <= 1'b0;
        if (ENABLE_RUNTIME_DSM && arch_busy_q) arch_error_q <= 1'b1;
        arch_req_q <= 1'b0; arch_busy_q <= 1'b0; arch_seen_ack <= 1'b0; arch_done_q <= 1'b0;
        run_request_q <= 1'b0;
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
  // Research candidate: assertion of either control or core reset aborts the
  // DPD mailbox epoch; deassertion is synchronized to the core clock.
  // This does not yet protect the separate runtime-mode mailbox or arrange
  // system-wide traffic abort and is not approved as product RTL.
  always_ff @(posedge core_clk or negedge cfg_epoch_core_n) begin
    if (!cfg_epoch_core_n) begin
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
    cfg_for_dpd = (cfg_epoch_core_n && cfg_pending_valid && dpd_config_boundary) ?
                  cfg_pending_core : cfg_active_core;
    {dpd_active_taps,c1_re,c1_im,c3_re,c3_im,c5_re,c5_im} = cfg_for_dpd;
  end

  always_ff @(posedge core_clk or negedge cfg_epoch_core_n) begin
    if(!cfg_epoch_core_n) begin
      arch_req_c1<=0;arch_req_c2<=0;arch_phase<=0;
      arch_ack_core<=0;arch_error_core<=0;arch_pending_core<=1;
      dsm_arch<=1;dsm_reset_pulse<=0;dsm_config_id<=0;
    end else begin
      arch_req_c1<=arch_req_q;arch_req_c2<=arch_req_c1;
      dsm_reset_pulse<=0;
      if(ENABLE_RUNTIME_DSM) begin
        case(arch_phase)
          0: if(arch_req_c2) begin
            arch_pending_core<=arch_mailbox;arch_phase<=1;
          end
          1: if(dsm_source_locked) begin
            arch_error_core<=!dsm_switch_idle || arch_pending_core>2;
            if(dsm_switch_idle && arch_pending_core<=2) begin
              dsm_arch<=arch_pending_core;dsm_reset_pulse<=1;
              dsm_config_id<=dsm_config_id+1'b1;
            end
            arch_phase<=2;
          end
          2: begin arch_ack_core<=1;arch_phase<=3;end
          3: if(!arch_req_c2) begin arch_ack_core<=0;arch_phase<=0;end
          default:arch_phase<=0;
        endcase
      end
    end
  end

  initial begin
    if (MAX_TAPS < 1 || MAX_TAPS > 4)
      $error("MAX_TAPS must be in [1,4]; got %0d",MAX_TAPS);
  end

`ifndef SYNTHESIS
  logic [1:0] arch_mailbox_hold,arch_previous;
  logic arch_tracking,arch_commit_allowed;
  always_ff @(posedge s_axil_aclk or negedge s_axil_aresetn) begin
    if(!s_axil_aresetn) begin arch_tracking<=0;arch_mailbox_hold<=1;end
    else if(ENABLE_RUNTIME_DSM) begin
      if(arch_req_q && !arch_tracking) begin
        arch_tracking<=1;arch_mailbox_hold<=arch_mailbox;
      end else if(arch_req_q && arch_mailbox!==arch_mailbox_hold)
        $error("thermo5 architecture mailbox changed before acknowledgement");
      else if(!arch_req_q) arch_tracking<=0;
    end
  end
  always_ff @(posedge core_clk or negedge core_aresetn) begin
    if(!core_aresetn) begin arch_previous<=1;arch_commit_allowed<=0;end
    else if(ENABLE_RUNTIME_DSM) begin
      if(dsm_reset_pulse && !arch_commit_allowed)
        $error("thermo5 architecture committed without locked idle decision");
      if(dsm_arch!==arch_previous && !dsm_reset_pulse)
        $error("thermo5 architecture changed without backend reset");
      arch_previous<=dsm_arch;
      arch_commit_allowed<=(arch_phase==1 && dsm_source_locked &&
                            dsm_switch_idle && arch_pending_core<=2);
    end
  end
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
