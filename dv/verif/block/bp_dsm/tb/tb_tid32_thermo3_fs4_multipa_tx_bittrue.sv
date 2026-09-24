`timescale 1ns/1ps
`default_nettype none

module tb_tid32_thermo3_fs4_multipa_tx_bittrue;
  localparam int W = 16;
  localparam int LANES = 32;
  localparam int VECTORS = 128;
  logic clk = 1'b0, rst_n = 1'b0, in_valid = 1'b0;
  logic pa_p_ready = 1'b0, pa_m_ready = 1'b0;
  logic signed [LANES*W-1:0] in_i_poly_vec = '0, in_q_poly_vec = '0;
  wire in_ready, pa_p_valid, pa_m_valid;
  wire [2*LANES-1:0] pa_p_data, pa_m_data;
  logic [W-1:0] i_mem [0:LANES*VECTORS-1];
  logic [W-1:0] q_mem [0:LANES*VECTORS-1];
  logic [2*LANES-1:0] p_mem [0:VECTORS-1];
  logic [2*LANES-1:0] m_mem [0:VECTORS-1];
  integer n, lane, accepted, errors, timeout;

  tid32_thermo3_fs4_multipa_tx #(.W(W), .CHANNELS(LANES), .THRESHOLD(8192)) dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
    .in_i_poly_vec(in_i_poly_vec), .in_q_poly_vec(in_q_poly_vec),
    .pa_p_valid(pa_p_valid), .pa_p_data(pa_p_data), .pa_p_ready(pa_p_ready),
    .pa_m_valid(pa_m_valid), .pa_m_data(pa_m_data), .pa_m_ready(pa_m_ready)
  );
  always #5 clk = ~clk;

  initial begin
    $readmemh("tid32_thermo3_i.mem", i_mem);
    $readmemh("tid32_thermo3_q.mem", q_mem);
    $readmemh("tid32_thermo3_pa_p.mem", p_mem);
    $readmemh("tid32_thermo3_pa_m.mem", m_mem);
    accepted = 0; errors = 0;
    repeat (3) @(negedge clk);
    rst_n = 1'b1; pa_p_ready = 1'b1; pa_m_ready = 1'b1;
    for (n = 0; n < VECTORS; n = n + 1) begin
      @(negedge clk);
      if (!in_ready) $fatal(1, "Unexpected input backpressure at word %0d", n);
      for (lane = 0; lane < LANES; lane = lane + 1) begin
        in_i_poly_vec[lane*W +: W] = i_mem[n*LANES+lane];
        in_q_poly_vec[lane*W +: W] = q_mem[n*LANES+lane];
      end
      in_valid = 1'b1;
    end
    @(negedge clk);
    in_valid = 1'b0;
    timeout = 0;
    while (accepted < VECTORS && timeout < 16) begin @(negedge clk); timeout = timeout + 1; end
    if (accepted != VECTORS) $fatal(1, "Accepted %0d PA word pairs", accepted);
    if (errors != 0) $fatal(1, "TID32 thermo3 mismatches=%0d", errors);
    $display("TID32_THERMO3_FS4_MULTIPA_BITTRUE_PASS vectors=%0d samples=%0d", VECTORS, VECTORS*LANES);
    $finish;
  end

  always @(posedge clk) begin
    if (rst_n && (pa_p_valid !== pa_m_valid)) $fatal(1, "PA valid streams lost alignment");
    if (rst_n && pa_p_valid && pa_p_ready && pa_m_ready) begin
      if (pa_p_data !== p_mem[accepted]) begin
        $error("PA+ mismatch word=%0d actual=%h expected=%h", accepted, pa_p_data, p_mem[accepted]); errors = errors + 1;
      end
      if (pa_m_data !== m_mem[accepted]) begin
        $error("PA- mismatch word=%0d actual=%h expected=%h", accepted, pa_m_data, m_mem[accepted]); errors = errors + 1;
      end
      accepted = accepted + 1;
    end
  end
endmodule

`default_nettype wire
