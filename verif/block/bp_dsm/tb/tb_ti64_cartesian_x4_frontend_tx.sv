`timescale 1ns/1ps
`default_nettype none

module tb_ti64_cartesian_x4_frontend_tx;
  localparam int W = 16;
  localparam int LANES_IN = 16;
  localparam int INTERP = 4;
  localparam int LANES_OUT = LANES_IN * INTERP;
  localparam int HISTORY_DEPTH = 7;
  localparam int WORDS = 32;
  localparam int V_MAX = 134217727;
  localparam int V_MIN = -134217728;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic in_valid = 1'b0;
  logic gt_ready = 1'b0;
  logic signed [LANES_IN*W-1:0] in_i_vec = '0;
  logic signed [LANES_IN*W-1:0] in_q_vec = '0;
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
  integer dsm_state [0:LANES_OUT-1];
  integer history_i [0:HISTORY_DEPTH-1];
  integer history_q [0:HISTORY_DEPTH-1];
  integer interp_i [0:LANES_OUT-1];
  integer interp_q [0:LANES_OUT-1];
  integer sent, received, errors, lane, phase, tap, value_x, value_v;
  integer sample_i, sample_q;
  longint signed total_i, total_q, rounded_i, rounded_q;
  logic value_base;

  ti64_cartesian_x4_frontend_tx #(.W(W), .ACC_W(28)) dut (
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

  function automatic integer coeff(input integer index);
    begin
      case (index)
        0: coeff = 128;  1: coeff = 512;  2: coeff = 1280; 3: coeff = 2560;
        4: coeff = 4480; 5: coeff = 7168; 6: coeff = 10752; 7: coeff = 15360;
        8: coeff = 20608; 9: coeff = 26112; 10: coeff = 31488; 11: coeff = 36352;
        12: coeff = 40320; 13: coeff = 43008; 14: coeff = 44032; 15: coeff = 43008;
        16: coeff = 40320; 17: coeff = 36352; 18: coeff = 31488; 19: coeff = 26112;
        20: coeff = 20608; 21: coeff = 15360; 22: coeff = 10752; 23: coeff = 7168;
        24: coeff = 4480; 25: coeff = 2560; 26: coeff = 1280; 27: coeff = 512;
        28: coeff = 128;
        default: coeff = 0;
      endcase
    end
  endfunction

  function automatic longint signed round_shift_ref(input longint signed value);
    begin
      if (value >= 0) round_shift_ref = (value + 32768) >>> 16;
      else round_shift_ref = -(((-value) + 32768) >>> 16);
    end
  endfunction

  function automatic integer sat16(input longint signed value);
    begin
      if (value > 32767) sat16 = 32767;
      else if (value < -32768) sat16 = -32768;
      else sat16 = value;
    end
  endfunction

  initial begin
    sent = 0;
    received = 0;
    errors = 0;
    for (lane = 0; lane < LANES_OUT; lane = lane + 1) dsm_state[lane] = 0;
    for (lane = 0; lane < HISTORY_DEPTH; lane = lane + 1) begin
      history_i[lane] = 0;
      history_q[lane] = 0;
    end

    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    gt_ready = 1'b1;

    for (sent = 0; sent < WORDS; sent = sent + 1) begin
      @(negedge clk);
      if (!in_ready) $fatal(1, "unexpected input stall at word %0d", sent);
      // Unity polynomial makes this vector path exercise both supported DPD
      // selections without changing the fixed-point expected baseband stream.
      dpd_mode = (sent < (WORDS/2)) ? 2'd0 : 2'd1;
      for (lane = 0; lane < LANES_IN; lane = lane + 1) begin
        in_i_vec[lane*W +: W] = input_i(sent, lane);
        in_q_vec[lane*W +: W] = input_q(sent, lane);
      end

      // Independent x4 oracle: identical quantized FIR arithmetic, explicit
      // time order and seven-sample word-boundary history.
      for (lane = 0; lane < LANES_IN; lane = lane + 1) begin
        for (phase = 0; phase < INTERP; phase = phase + 1) begin
          total_i = 0;
          total_q = 0;
          for (tap = 0; tap <= HISTORY_DEPTH; tap = tap + 1) begin
            if ((phase + tap * INTERP) < 29) begin
              if (tap == 0) begin
                sample_i = input_i(sent, lane);
                sample_q = input_q(sent, lane);
              end else if (tap <= lane) begin
                sample_i = input_i(sent, lane-tap);
                sample_q = input_q(sent, lane-tap);
              end else begin
                sample_i = history_i[tap-lane-1];
                sample_q = history_q[tap-lane-1];
              end
              total_i = total_i + sample_i * coeff(phase + tap * INTERP);
              total_q = total_q + sample_q * coeff(phase + tap * INTERP);
            end
          end
          rounded_i = round_shift_ref(total_i);
          rounded_q = round_shift_ref(total_q);
          interp_i[lane*INTERP + phase] = sat16(rounded_i);
          interp_q[lane*INTERP + phase] = sat16(rounded_q);
        end
      end
      for (lane = 0; lane < HISTORY_DEPTH; lane = lane + 1) begin
        history_i[lane] = input_i(sent, LANES_IN-1-lane);
        history_q[lane] = input_q(sent, LANES_IN-1-lane);
      end

      for (lane = 0; lane < LANES_OUT; lane = lane + 1) begin
        case (lane % 4)
          0: value_x = interp_i[lane];
          1: value_x = interp_q[lane];
          2: value_x = -interp_i[lane];
          default: value_x = -interp_q[lane];
        endcase
        value_v = value_x + dsm_state[lane];
        if (value_v > V_MAX) value_v = V_MAX;
        if (value_v < V_MIN) value_v = V_MIN;
        value_base = (value_v >= 0);
        dsm_state[lane] = value_v - (value_base ? 32767 : -32767);
        expected_words[sent][lane] = value_base ^ ((lane % 4) >= 2);
      end
      in_valid = 1'b1;
    end
    @(negedge clk);
    in_valid = 1'b0;

    repeat (128) begin
      @(posedge clk);
      if (received == WORDS) break;
    end
    if (received != WORDS) $fatal(1, "received %0d of %0d GT words", received, WORDS);
    if (errors != 0) $fatal(1, "x4 Cartesian TI64 errors=%0d", errors);
    $display("TI64_CARTESIAN_X4_FRONTEND_TX_PASS words=%0d input_samples=%0d output_samples=%0d",
      WORDS, WORDS*LANES_IN, WORDS*LANES_OUT);
    $finish;
  end

  always @(posedge clk) begin
    if (rst_n && gt_valid && gt_ready) begin
      if (received >= WORDS) begin
        $error("unexpected GT word after end of expected sequence");
        errors = errors + 1;
      end else begin
        for (lane = 0; lane < LANES_OUT; lane = lane + 1) begin
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
