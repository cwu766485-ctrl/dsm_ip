`timescale 1ns/1ps
`default_nettype none

module tb_dsm_ip_axi_smoke;
  localparam int W = 16;
  localparam int DSM_OUT_W = 8;
  localparam int RF_W = 16;

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
    .W(W),
    .DSM_OUT_W(DSM_OUT_W),
    .RF_W(RF_W),
    .PHASE_W(24),
    .ALGORITHM(2),
    .DUC_MODE(0),
    .INTERP_MODE(4),
    .C_S_AXI_ADDR_WIDTH(9)
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
    .s_axis_obs_tdata(s_axis_obs_tdata),
    .s_axis_obs_tlast(s_axis_obs_tlast),
    .s_axis_obs_tuser(s_axis_obs_tuser),
    .s_axis_obs_tvalid(s_axis_obs_tvalid),
    .s_axis_obs_tready(s_axis_obs_tready),
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
    input [8:0] addr;
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

  // AXI4-Lite does not require AW and W to arrive together.  Exercise both
  // legal orderings, with a deliberate gap between the two handshakes.
  task axi_write_aw_first;
    input [8:0] addr;
    input [31:0] data;
    begin
      @(posedge aclk);
      s_axi_awaddr <= addr;
      s_axi_awvalid <= 1'b1;
      while (!s_axi_awready) @(posedge aclk);
      @(posedge aclk);
      s_axi_awvalid <= 1'b0;
      repeat (2) @(posedge aclk);
      s_axi_wdata <= data;
      s_axi_wstrb <= 4'hf;
      s_axi_wvalid <= 1'b1;
      while (!s_axi_wready) @(posedge aclk);
      @(posedge aclk);
      s_axi_wvalid <= 1'b0;
      while (!s_axi_bvalid) @(posedge aclk);
      @(posedge aclk);
    end
  endtask

  task axi_write_w_first;
    input [8:0] addr;
    input [31:0] data;
    begin
      @(posedge aclk);
      s_axi_wdata <= data;
      s_axi_wstrb <= 4'hf;
      s_axi_wvalid <= 1'b1;
      while (!s_axi_wready) @(posedge aclk);
      @(posedge aclk);
      s_axi_wvalid <= 1'b0;
      repeat (2) @(posedge aclk);
      s_axi_awaddr <= addr;
      s_axi_awvalid <= 1'b1;
      while (!s_axi_awready) @(posedge aclk);
      @(posedge aclk);
      s_axi_awvalid <= 1'b0;
      while (!s_axi_bvalid) @(posedge aclk);
      @(posedge aclk);
    end
  endtask

  task axi_write_strb;
    input [8:0] addr;
    input [31:0] data;
    input [3:0] strb;
    begin
      @(posedge aclk);
      s_axi_awaddr <= addr;
      s_axi_awvalid <= 1'b1;
      s_axi_wdata <= data;
      s_axi_wstrb <= strb;
      s_axi_wvalid <= 1'b1;
      wait (s_axi_awready && s_axi_wready);
      @(posedge aclk);
      s_axi_awvalid <= 1'b0;
      s_axi_wvalid <= 1'b0;
      wait (s_axi_bvalid);
      @(posedge aclk);
    end
  endtask

  task axi_write_bready_stall;
    input [8:0] addr;
    input [31:0] data;
    integer hold_cycle;
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
      s_axi_bready <= 1'b0;
      wait (s_axi_bvalid);
      for (hold_cycle = 0; hold_cycle < 3; hold_cycle = hold_cycle + 1) begin
        @(posedge aclk);
        if (!s_axi_bvalid || s_axi_bresp != 2'b00)
          $fatal(1, "B response did not remain stable while BREADY was low");
      end
      s_axi_bready <= 1'b1;
      @(posedge aclk);
    end
  endtask

  task axi_read_rready_stall;
    input [8:0] addr;
    input [31:0] expected;
    integer hold_cycle;
    begin
      s_axi_rready <= 1'b0;
      @(posedge aclk);
      s_axi_araddr <= addr;
      s_axi_arvalid <= 1'b1;
      wait (s_axi_arready);
      @(posedge aclk);
      s_axi_arvalid <= 1'b0;
      wait (s_axi_rvalid);
      #1;
      for (hold_cycle = 0; hold_cycle < 3; hold_cycle = hold_cycle + 1) begin
        if (s_axi_rdata !== expected || s_axi_rresp != 2'b00)
          $fatal(1, "R response changed while RREADY was low");
        @(posedge aclk);
      end
      s_axi_rready <= 1'b1;
      @(posedge aclk);
    end
  endtask

  task wait_mp_commit_ack;
    integer poll;
    begin
      for (poll = 0; poll < 32; poll = poll + 1) begin
        axi_read(9'h110, rd);
        if (rd[0]) begin
          poll = 32;
        end
      end
      if (!rd[0]) $fatal(1, "MP commit did not acknowledge: %08x", rd);
    end
  endtask

  task axi_read;
    input [8:0] addr;
    output [31:0] data;
    begin
      @(posedge aclk);
      s_axi_araddr <= addr;
      s_axi_arvalid <= 1'b1;
      wait (s_axi_arready);
       @(posedge aclk);
       s_axi_arvalid <= 1'b0;
       wait (s_axi_rvalid);
       // The RTL updates RVALID and RDATA with nonblocking assignments on
       // the accepting clock edge.  Sample after that NBA update.
       #1 data = s_axi_rdata;
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
      @(posedge aclk);
      while (!s_axis_tready) begin
        @(posedge aclk);
      end
      s_axis_tvalid <= 1'b0;
      s_axis_tlast <= 1'b0;
      s_axis_tuser <= 1'b0;
    end
  endtask

  task obs_send;
    input signed [15:0] i_sample;
    input signed [15:0] q_sample;
    input last_sample;
    input invalid_sample;
    begin
      @(posedge aclk);
      s_axis_obs_tdata <= {q_sample, i_sample};
      s_axis_obs_tlast <= last_sample;
      s_axis_obs_tuser <= invalid_sample;
      s_axis_obs_tvalid <= 1'b1;
      while (!s_axis_obs_tready) @(posedge aclk);
      @(posedge aclk);
      s_axis_obs_tvalid <= 1'b0;
      s_axis_obs_tlast <= 1'b0;
      s_axis_obs_tuser <= 1'b0;
    end
  endtask

  initial begin
    aresetn = 1'b0;
    s_axi_awaddr = 9'd0;
    s_axi_awvalid = 1'b0;
    s_axi_wdata = 32'd0;
    s_axi_wstrb = 4'h0;
    s_axi_wvalid = 1'b0;
    s_axi_bready = 1'b1;
    s_axi_araddr = 9'd0;
    s_axi_arvalid = 1'b0;
    s_axi_rready = 1'b1;
    s_axis_tdata = 32'd0;
    s_axis_tlast = 1'b0;
    s_axis_tuser = 1'b0;
    s_axis_tvalid = 1'b0;
    s_axis_obs_tdata = 32'd0;
    s_axis_obs_tlast = 1'b0;
    s_axis_obs_tuser = 1'b0;
    s_axis_obs_tvalid = 1'b0;
    valid_count = 0;

    repeat (8) @(posedge aclk);
    aresetn = 1'b1;

    s_axis_tdata <= {16'sd1, 16'sd2};
    s_axis_tvalid <= 1'b1;
    repeat (2) @(posedge aclk);
    s_axis_tvalid <= 1'b0;

    axi_read(7'h24, rd);
    if (rd[0] !== 1'b1) $fatal(1, "sticky error was not set while stream was not ready: rd=%h", rd);
    axi_write(7'h24, 32'h0000_0001);
    axi_read(7'h24, rd);
    if (rd != 32'h0000_0000) $fatal(1, "sticky error did not clear");

    axi_write(7'h08, 32'h0040_0000);
    axi_read(7'h08, rd);
    if (rd[23:0] != 24'h400000) $fatal(1, "phase increment readback mismatch");
    axi_read(7'h30, rd);
    if (rd != 32'd4) $fatal(1, "compiled INTERP_MODE readback mismatch");
    axi_read(7'h40, rd);
    if (rd[1:0] !== 2'b00) $fatal(1, "DPD default mode mismatch");
    axi_read(7'h14, rd);
    if (rd != 32'h0001_0005) $fatal(1, "TX frontend v1.5 version mismatch");
    axi_read(9'h108, rd);
    if (!rd[2] || !rd[18] || !rd[19] || rd[5:3] != 3'd4 ||
        rd[8:6] != 3'd5 || rd[12:9] != 4'd2 || rd[16:13] != 4'd4)
      $fatal(1, "capability register mismatch: %08x", rd);
    axi_write_aw_first(9'h104, 32'h0000_0003);
    axi_read(9'h104, rd);
    if (rd[3:0] != 4'd3) $fatal(1, "AW-first DSM control mismatch: %08x", rd);
    axi_write_strb(9'h104, 32'h0000_000f, 4'h0);
    axi_read(9'h104, rd);
    if (rd[3:0] != 4'd3) $fatal(1, "WSTRB=0 unexpectedly changed DSM control: %08x", rd);
    axi_write_w_first(9'h104, 32'h0000_0004);
    axi_read(9'h104, rd);
    if (rd[3:0] != 4'd4) $fatal(1, "W-first DSM control mismatch: %08x", rd);
    axi_write(9'h104, 32'h0000_0000);
    axi_write_bready_stall(9'h120, 32'hdead_beef);
    axi_read_rready_stall(9'h14, 32'h0001_0005);
    axi_read(7'h44, rd);
    if (rd != 32'h0000_4000) $fatal(1, "DPD default C1 coefficient mismatch");
    axi_write(7'h48, 32'hf1a4_1f6f);
    axi_read(7'h48, rd);
    if (rd != 32'hf1a4_1f6f) $fatal(1, "DPD C3 coefficient readback mismatch");
    axi_write(7'h58, 32'h0000_0003);
    axi_read(7'h58, rd);
    if (rd != 32'h0000_0003) $fatal(1, "DPD LUT address readback mismatch");
    axi_write(7'h5c, 32'hff00_4100);
    axi_read(7'h5c, rd);
    if (rd != 32'hff00_4100) $fatal(1, "DPD LUT data readback mismatch");
    axi_read(7'h60, rd);
    if (rd[0] != 1'b0) $fatal(1, "DPD LUT active bank default mismatch");
    axi_write(7'h60, 32'h0000_0001);
    axi_read(7'h60, rd);
    if (rd[0] != 1'b1) $fatal(1, "DPD LUT active bank did not toggle after commit");
    axi_write(7'h40, 32'h0000_0002);
    axi_read(7'h40, rd);
    if (rd[1:0] !== 2'b10) $fatal(1, "DPD LUT mode readback mismatch");
    axi_write(8'h90, 32'h0000_0201);
    axi_write(8'h94, 32'h0000_2000);
    axi_read(8'h94, rd);
    if (rd != 32'h0000_2000) $fatal(1, "MP shadow coefficient mismatch");
    axi_write(8'h98, 32'h0000_0001);
    wait_mp_commit_ack();
    axi_read(8'h98, rd);
    if (rd[0] != 1'b1) $fatal(1, "MP coefficient bank did not commit");
    axi_read(9'h10c, rd);
    if (rd[1:0] != 2'b10 || !rd[4])
      $fatal(1, "effective status does not report Memory-Poly bank 1: %08x", rd);

    axi_write(8'hbc, 32'h0000_0101);
    axi_write(8'hc0, 32'd16);
    axi_write(8'hc4, 32'd20000);
    axi_write(8'hc8, 32'd700000);
    axi_write(8'hcc, {16'sd6400, 16'sd0});
    axi_write(8'hd0, 32'd0);
    axi_read(8'hd4, rd);
    if (!rd[3] || rd[4] || !rd[5] || rd[2:0] != 3'd5)
      $fatal(1, "runtime seed predictor known-condition mismatch: %08x", rd);
    axi_write(8'hd0, 32'd1);
    axi_read(8'hd4, rd);
    if (!rd[4] || !rd[5]) $fatal(1, "monitor fault did not force search fallback");

    axi_write(7'h00, 32'h0000_0001);
    axi_read(7'h00, rd);
    if (rd[0] !== 1'b1) $fatal(1, "enable readback mismatch");

    axi_write(7'h00, 32'h0000_0003);
    axi_read(7'h20, rd);
    if (rd != 32'd1) $fatal(1, "software reset count mismatch");
    axi_write(7'h00, 32'h0000_0001);

    for (n = 0; n < 64; n++) begin
      axis_send($signed(16'sd512 + n), $signed(16'sd1024 + n), (n == 31) || (n == 63), (n == 7));
    end

    axi_write(8'ha0, 32'h0000_4000);
    axi_write(8'ha4, 32'd2);
    axi_write(8'h9c, 32'h0000_0103);
    obs_send(16'sd575, 16'sd1087, 1'b0, 1'b0);
    obs_send(16'sd575, 16'sd1087, 1'b1, 1'b0);
    axi_read(8'ha8, rd);
    $display("Observation status=%08x", rd);
    if (!rd[2] || rd[1] || !rd[4] || rd[5])
      $fatal(1, "observation training window did not complete cleanly");
    axi_read(8'hb4, rd);
    axi_write(9'h114, 32'h0000_0001);
    axi_read(9'h118, rd);
    if (rd !== dut.obs_error_acc[31:0]) $fatal(1, "observation error snapshot low mismatch");
    axi_read(9'h11c, rd);
    if (rd !== dut.obs_error_acc[63:32]) $fatal(1, "observation error snapshot high mismatch");
    axi_read(8'hac, rd);
    $display("Observation pair count=%0d", rd);
    if (rd != 32'd2) $fatal(1, "observation paired count mismatch: %0d", rd);
    axi_read(8'hd8, rd);
    if (rd != {8'd2, 8'd0, 16'd6400}) $fatal(1, "observation environment mismatch: %08x", rd);
    axi_read(8'hdc, rd);
    if (rd != 32'd3320) $fatal(1, "observation reference magnitude mismatch: %0d", rd);
    axi_read(8'he0, rd);
    if (rd != 32'd3324) $fatal(1, "observation magnitude mismatch: %0d", rd);
    axi_read(8'he4, rd);
    if (rd != 32'd1662) $fatal(1, "observation peak mismatch: %0d", rd);
    axi_read(8'he8, rd);
    if (rd != 32'd0) $fatal(1, "observation clip/saturation mismatch: %08x", rd);
    axi_read(8'hec, rd);
    if (rd != 32'd0) $fatal(1, "observation slew mismatch: %0d", rd);
    axi_read(8'hf0, rd);
    if (rd != 32'd3324) $fatal(1, "observation bin0 mismatch: %0d", rd);
    axi_read(8'hf4, rd);
    if (rd != 32'd2174) $fatal(1, "observation bin1 mismatch: %0d", rd);
    axi_read(8'hf8, rd);
    if (rd != 32'd0) $fatal(1, "observation bin2 mismatch: %0d", rd);
    axi_read(8'hfc, rd);
    if (rd != 32'd3324) $fatal(1, "observation adjacent proxy mismatch: %0d", rd);

    repeat (6000) @(posedge aclk);

    if (valid_count == 0) $fatal(1, "dsm_ip_axi_top produced no rf_valid");
    axi_read(7'h18, rd);
    $display("AXI smoke input sample count readback=%0d", rd);
    if (rd != 32'd64) $fatal(1, "input sample count mismatch: got %0d", rd);
    axi_read(7'h50, rd);
    $display("AXI smoke DPD sample count readback=%0d", rd);
    if (rd != 32'd64) $fatal(1, "DPD sample count mismatch: got %0d", rd);
    axi_read(7'h28, rd);
    $display("AXI smoke frontend sample count readback=%0d", rd);
    if (rd != 32'd64) $fatal(1, "frontend sample count mismatch: got %0d", rd);
    axi_read(7'h64, rd);
    if (rd == 32'd0) $fatal(1, "input power proxy did not increment");
    axi_read(7'h68, rd);
    if (rd == 32'd0) $fatal(1, "output power proxy did not increment");
    axi_read(7'h6c, rd);
    if (rd != 32'd0) $fatal(1, "input clipping count should be zero for this vector");
    axi_read(7'h70, rd);
    if (rd == 32'd0) $fatal(1, "peak monitor did not update");
    axi_read(7'h74, rd);
    if (rd == 32'd0) $fatal(1, "average magnitude monitor did not update");
    axi_read(7'h78, rd);
    if (rd == 32'd0) $fatal(1, "EVM proxy monitor did not update in LUT DPD mode");
    axi_read(7'h7c, rd);
    if (rd == 32'd0) $fatal(1, "ACPR proxy monitor did not update");
    axi_read(8'h80, rd);
    if (rd == 32'd0) $fatal(1, "spectral bin0 monitor did not update");
    axi_read(8'h84, rd);
    if (rd == 32'd0) $fatal(1, "spectral Fs/4 bin monitor did not update");
    axi_read(8'h88, rd);
    if (rd == 32'd0) $fatal(1, "spectral Fs/2 bin monitor did not update");
    axi_read(8'h8c, rd);
    if (rd == 32'd0) $fatal(1, "spectral adjacent proxy monitor did not update");
    axi_read(7'h2c, rd);
    if (rd == 32'd0) $fatal(1, "input stall count did not increment under INTERP_MODE=4 backpressure");
    axi_read(7'h34, rd);
    if (rd != 32'd2) $fatal(1, "AXI-Stream frame count mismatch");
    axi_read(7'h38, rd);
    if (rd[0] != 1'b0) $fatal(1, "last AXI-Stream tuser readback mismatch");
    axi_read(7'h3c, rd);
    if (rd != 32'd1) $fatal(1, "AXI-Stream tuser error count mismatch");
    axi_read(7'h24, rd);
    if (rd[1] !== 1'b1) $fatal(1, "AXI-Stream tuser sticky error bit was not set");
    axi_write(7'h24, 32'h0000_0002);
    axi_read(7'h24, rd);
    if (rd[1] !== 1'b0) $fatal(1, "AXI-Stream tuser sticky error bit did not clear");
    axi_read(7'h1c, rd);
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
