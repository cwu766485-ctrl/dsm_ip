`timescale 1ns/1ps
`default_nettype none

module tb_ti64_cartesian_frontend_tx;
  localparam int W = 16;
  localparam int LANES = 64;
  localparam int WORDS = 24;
  localparam int V_MAX = 134217727;
  localparam int V_MIN = -134217728;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic in_valid = 1'b0;
  logic gt_ready = 1'b0;
  logic signed [LANES*W-1:0] in_i_vec = '0;
  logic signed [LANES*W-1:0] in_q_vec = '0;
  logic [1:0] dpd_mode = 2'd0;
  logic signed [15:0] c1_re = 16'sd16384;
  logic signed [15:0] c1_im = '0;
  logic signed [15:0] c3_re = '0;
  logic signed [15:0] c3_im = '0;
  logic signed [15:0] c5_re = '0;
  logic signed [15:0] c5_im = '0;
  logic signed [15:0] c7_re = '0;
  logic signed [15:0] c7_im = '0;
  wire in_ready;
  wire [1:0] dpd_effective_mode;
  wire gt_valid;
  wire [63:0] gt_data;

  logic [63:0] expected_words [0:WORDS-1];
  integer e_state [0:LANES-1];
  integer sent, received, errors, lane, value_i, value_q, value_x, value_v;
  logic value_base;

  ti64_cartesian_frontend_tx #(.W(W), .ACC_W(28)) dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
    .in_i_vec(in_i_vec), .in_q_vec(in_q_vec), .dpd_mode(dpd_mode),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .c7_re(c7_re), .c7_im(c7_im),
    .dpd_effective_mode(dpd_effective_mode), .gt_valid(gt_valid),
    .gt_ready(gt_ready), .gt_data(gt_data)
  );

  always #5 clk = ~clk;

  function automatic integer input_i(input integer word, input integer l);
    input_i = ((word * 137 + l * 29 + 401) % 8192) - 4096;
  endfunction

  function automatic integer input_q(input integer word, input integer l);
    input_q = ((word * 73 + l * 47 + 991) % 8192) - 4096;
  endfunction

  initial begin
    sent = 0;
    received = 0;
    errors = 0;
    for (lane = 0; lane < LANES; lane = lane + 1) e_state[lane] = 0;

    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    gt_ready = 1'b1;

    for (sent = 0; sent < WORDS; sent = sent + 1) begin
      @(negedge clk);
      if (!in_ready) $fatal(1, "unexpected input stall at word %0d", sent);
      // Use bypass for half the burst and unity polynomial DPD for the other
      // half. With c1=1 and all nonlinear coefficients zero, both are the
      // same fixed-point reference signal while exercising both modes.
      dpd_mode = (sent < (WORDS/2)) ? 2'd0 : 2'd1;
      for (lane = 0; lane < LANES; lane = lane + 1) begin
        value_i = input_i(sent, lane);
        value_q = input_q(sent, lane);
        in_i_vec[lane*W +: W] = value_i;
        in_q_vec[lane*W +: W] = value_q;
        case (lane % 4)
          0: value_x = value_i;
          1: value_x = value_q;
          2: value_x = -value_i;
          default: value_x = -value_q;
        endcase
        value_v = value_x + e_state[lane];
        if (value_v > V_MAX) value_v = V_MAX;
        if (value_v < V_MIN) value_v = V_MIN;
        value_base = (value_v >= 0);
        e_state[lane] = value_v - (value_base ? 32767 : -32767);
        expected_words[sent][lane] = value_base ^ ((lane % 4) >= 2);
      end
      in_valid = 1'b1;
    end
    @(negedge clk);
    in_valid = 1'b0;

    repeat (80) begin
      @(posedge clk);
      if (received == WORDS) break;
    end
    if (received != WORDS) $fatal(1, "received %0d of %0d GT words", received, WORDS);
    if (errors != 0) $fatal(1, "cartesian TI64 errors=%0d", errors);
    $display("TI64_CARTESIAN_FRONTEND_TX_PASS words=%0d samples=%0d", WORDS, WORDS*LANES);
    $finish;
  end

  always @(posedge clk) begin
    if (rst_n && gt_valid && gt_ready) begin
      if (received >= WORDS) begin
        $error("unexpected GT word after end of expected sequence");
        errors = errors + 1;
      end else begin
        for (lane = 0; lane < LANES; lane = lane + 1) begin
          if (gt_data[lane] !== expected_words[received][lane]) begin
            $error("GT mismatch word=%0d lane=%0d got=%0b exp=%0b",
              received, lane, gt_data[lane], expected_words[received][lane]);
            errors = errors + 1;
          end
        end
      end
      received = received + 1;
    end
  end
endmodule

`default_nettype wire
