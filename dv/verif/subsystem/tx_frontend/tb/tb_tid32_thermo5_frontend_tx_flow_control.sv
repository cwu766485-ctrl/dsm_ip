`timescale 1ns/1ps
`default_nettype none

module tb_tid32_thermo5_frontend_tx_flow_control;
  localparam int W = 16;
  localparam int LANES = 8;
  localparam int WORDS = 64;
`ifdef TB_INTERP_2
  localparam int INTERP_TAPS = 2;
`elsif TB_INTERP_3
  localparam int INTERP_TAPS = 3;
`else
  localparam int INTERP_TAPS = 4;
`endif
`ifdef TB_DPD_1
  localparam int DPD_MAX_TAPS = 1;
`elsif TB_DPD_2
  localparam int DPD_MAX_TAPS = 2;
`else
  localparam int DPD_MAX_TAPS = 4;
`endif

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic enable = 1'b1;
  logic in_valid = 1'b0;
  logic in_frame_start = 1'b0;
  logic signed [W-1:0] in_frame_gain = 16'sd16384;
  logic signed [LANES*W-1:0] in_i_vec = '0;
  logic signed [LANES*W-1:0] in_q_vec = '0;
  logic [3:0] pa_ready = '0;
  wire in_ready;
  wire [3:0] pa_valid;
  wire [63:0] pa_data [0:3];

  logic [W-1:0] i_mem [0:LANES*WORDS-1];
  logic [W-1:0] q_mem [0:LANES*WORDS-1];
  logic [W-1:0] frame_start_mem [0:WORDS-1];
  logic [W-1:0] frame_gain_mem [0:WORDS-1];
  logic [63:0] pa_mem [0:3][0:WORDS-1];
  logic signed [DPD_MAX_TAPS*W-1:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im;

  integer sent = 0;
  integer got = 0;
  integer errors = 0;
  integer cycles = 0;
  integer bubble_cycles = 0;
  integer stall_cycles = 0;
  integer ready_phase = 0;
  integer lane;
  integer branch;
  logic drain = 1'b0;
  logic held_valid = 1'b0;
  logic [63:0] held_data [0:3];

  tid32_thermo5_frontend_tx #(
    .STEP(7168), .INTERP_TAPS(INTERP_TAPS), .MAX_TAPS(DPD_MAX_TAPS)
  ) dut (
    .clk(clk), .rst_n(rst_n), .enable(enable),
    .in_valid(in_valid), .in_ready(in_ready),
    .in_frame_start(in_frame_start), .in_frame_gain(in_frame_gain),
    .in_i_vec(in_i_vec), .in_q_vec(in_q_vec),
    .dpd_active_taps(3'd1),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im), .c5_re(c5_re), .c5_im(c5_im),
    .pa_valid(pa_valid), .pa_data(pa_data), .pa_ready(pa_ready)
  );

  always #5 clk = ~clk;

  // Deterministic partial-ready windows exercise all-or-nothing PA flow control.
  always @(negedge clk) begin
    if (!rst_n || drain) begin
      pa_ready = 4'hf;
    end else begin
      case (ready_phase % 16)
        3, 4, 5: pa_ready = 4'b1110;
        7:       pa_ready = 4'b1101;
        12, 13:  pa_ready = 4'b0111;
        default: pa_ready = 4'hf;
      endcase
      ready_phase = ready_phase + 1;
    end
  end

  initial begin
    $readmemh("tid32_thermo5_frontend_i.mem", i_mem);
    $readmemh("tid32_thermo5_frontend_q.mem", q_mem);
    $readmemh("tid32_thermo5_frontend_frame_start.mem", frame_start_mem);
    $readmemh("tid32_thermo5_frontend_frame_gain.mem", frame_gain_mem);
    $readmemh("tid32_thermo5_frontend_pa0.mem", pa_mem[0]);
    $readmemh("tid32_thermo5_frontend_pa1.mem", pa_mem[1]);
    $readmemh("tid32_thermo5_frontend_pa2.mem", pa_mem[2]);
    $readmemh("tid32_thermo5_frontend_pa3.mem", pa_mem[3]);

    c1_re = '0;
    c1_re[15:0] = 16'sd16384;
    c1_im = '0;
    c3_re = '0;
    c3_im = '0;
    c5_re = '0;
    c5_im = '0;

    repeat (5) @(negedge clk);
    rst_n = 1'b1;

    for (integer word_index = 0; word_index < WORDS; word_index = word_index + 1) begin
      // Insert source bubbles, but only between completed AXI transfers.
      if ((word_index % 8) == 4) begin
        in_valid = 1'b0;
        repeat (2) @(negedge clk);
        bubble_cycles = bubble_cycles + 2;
      end

      @(negedge clk);
      in_frame_start = frame_start_mem[word_index][0];
      in_frame_gain = frame_gain_mem[word_index];
      for (lane = 0; lane < LANES; lane = lane + 1) begin
        in_i_vec[lane*W +: W] = i_mem[word_index*LANES + lane];
        in_q_vec[lane*W +: W] = q_mem[word_index*LANES + lane];
      end
      in_valid = 1'b1;
      do @(posedge clk); while (in_ready !== 1'b1);
      sent = sent + 1;
      @(negedge clk);
      in_valid = 1'b0;
    end

    @(posedge clk);
    drain = 1'b1;
    in_valid = 1'b0;
    cycles = 0;
    while (got < WORDS && cycles < 10000) begin
      @(negedge clk);
      cycles = cycles + 1;
    end
    if (sent != WORDS) $fatal(1, "Accepted %0d/%0d frontend inputs", sent, WORDS);
    if (got != WORDS) $fatal(1, "Observed %0d/%0d frontend output words", got, WORDS);
    if (bubble_cycles == 0) $fatal(1, "No input bubble was generated");
    if (stall_cycles == 0) $fatal(1, "No PA backpressure stall was observed");
    if (errors != 0) $fatal(1, "Frontend flow-control mismatches=%0d", errors);

    $display("TID32_THERMO5_FRONTEND_FLOW_CONTROL_PASS words=%0d bubbles=%0d stalls=%0d",
             WORDS, bubble_cycles, stall_cycles);
    $finish;
  end

  always @(posedge clk) begin
    if (rst_n) begin
      if (pa_valid !== 4'h0 && pa_valid !== 4'hf)
        $fatal(1, "Four-plane valid alignment failure: %b", pa_valid);

      if (held_valid) begin
        if (pa_valid !== 4'hf)
          $fatal(1, "PA valid dropped while a four-plane word was stalled");
        for (branch = 0; branch < 4; branch = branch + 1)
          if (pa_data[branch] !== held_data[branch])
            $fatal(1, "PA%0d changed while stalled: got=%h held=%h",
                   branch, pa_data[branch], held_data[branch]);
      end

      if (pa_valid === 4'hf) begin
        if (pa_ready === 4'hf) begin
          if (got >= WORDS) $fatal(1, "Unexpected extra PA quartet");
          for (branch = 0; branch < 4; branch = branch + 1) begin
            if (pa_data[branch] !== pa_mem[branch][got]) begin
              $error("PA%0d mismatch word=%0d got=%h exp=%h",
                     branch, got, pa_data[branch], pa_mem[branch][got]);
              errors = errors + 1;
            end
          end
          got = got + 1;
          held_valid = 1'b0;
        end else begin
          for (branch = 0; branch < 4; branch = branch + 1)
            held_data[branch] = pa_data[branch];
          held_valid = 1'b1;
          stall_cycles = stall_cycles + 1;
        end
      end else if (held_valid) begin
        $fatal(1, "PA quartet disappeared before backpressure was released");
      end
    end else begin
      held_valid = 1'b0;
    end
  end
endmodule

`default_nettype wire
