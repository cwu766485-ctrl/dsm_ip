`timescale 1ns/1ps
`default_nettype none

module tb_tid32_thermo5_fs4_multipa_tx_backpressure;
  localparam int W = 16;
  localparam int LANES = 32;
  localparam int VECTORS = 128;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic in_valid = 1'b0;
  logic [3:0] pa_ready = '0;
  logic signed [LANES*W-1:0] in_i_poly_vec = '0;
  logic signed [LANES*W-1:0] in_q_poly_vec = '0;
  wire in_ready;
  wire [3:0] pa_valid;
  wire [2*LANES-1:0] pa_data [0:3];

  logic [W-1:0] i_mem [0:LANES*VECTORS-1];
  logic [W-1:0] q_mem [0:LANES*VECTORS-1];
  logic [2*LANES-1:0] pa0_mem [0:VECTORS-1];
  logic [2*LANES-1:0] pa1_mem [0:VECTORS-1];
  logic [2*LANES-1:0] pa2_mem [0:VECTORS-1];
  logic [2*LANES-1:0] pa3_mem [0:VECTORS-1];

  integer sent = 0;
  integer got = 0;
  integer errors = 0;
  integer stalls = 0;
  integer bubbles = 0;
  integer timeout = 0;
  integer ready_phase = 0;
  logic drain = 1'b0;
  logic held_valid = 1'b0;
  logic [2*LANES-1:0] held_data [0:3];

  tid32_thermo5_fs4_multipa_tx #(.W(W), .CHANNELS(LANES), .STEP(6144)) dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
    .in_i_poly_vec(in_i_poly_vec), .in_q_poly_vec(in_q_poly_vec),
    .pa_valid(pa_valid), .pa_data(pa_data), .pa_ready(pa_ready)
  );
  always #5 clk = ~clk;

  // Each partial-ready pattern blocks a different PA plane.  The DUT must
  // treat the four words as one atomic quartet and only advance on 4'hf.
  always @(negedge clk) begin
    if (!rst_n || drain) begin
      pa_ready = 4'hf;
    end else begin
      case (ready_phase % 12)
        2, 3: pa_ready = 4'b1110;
        5:    pa_ready = 4'b1101;
        7, 8: pa_ready = 4'b1011;
        10:   pa_ready = 4'b0111;
        default: pa_ready = 4'hf;
      endcase
      ready_phase = ready_phase + 1;
    end
  end

  initial begin
    $readmemh("tid32_thermo5_i.mem", i_mem);
    $readmemh("tid32_thermo5_q.mem", q_mem);
    $readmemh("tid32_thermo5_pa0.mem", pa0_mem);
    $readmemh("tid32_thermo5_pa1.mem", pa1_mem);
    $readmemh("tid32_thermo5_pa2.mem", pa2_mem);
    $readmemh("tid32_thermo5_pa3.mem", pa3_mem);

    repeat (3) @(negedge clk);
    rst_n = 1'b1;

    for (integer word_index = 0; word_index < VECTORS; word_index = word_index + 1) begin
      if ((word_index % 8) == 3) begin
        in_valid = 1'b0;
        repeat (2) @(negedge clk);
        bubbles = bubbles + 2;
      end

      @(negedge clk);
      for (integer lane = 0; lane < LANES; lane = lane + 1) begin
        in_i_poly_vec[lane*W +: W] = i_mem[word_index*LANES + lane];
        in_q_poly_vec[lane*W +: W] = q_mem[word_index*LANES + lane];
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
    while (got < VECTORS && timeout < 10000) begin
      @(negedge clk);
      timeout = timeout + 1;
    end

    if (sent != VECTORS) $fatal(1, "Accepted %0d/%0d backend input words", sent, VECTORS);
    if (got != VECTORS) $fatal(1, "Observed %0d/%0d PA quartets", got, VECTORS);
    if (stalls == 0) $fatal(1, "No partial-ready backpressure was observed");
    if (bubbles == 0) $fatal(1, "No valid bubble was generated");
    if (errors != 0) $fatal(1, "Backend backpressure mismatches=%0d", errors);

    $display("TID32_THERMO5_FS4_MULTIPA_BACKPRESSURE_PASS vectors=%0d bubbles=%0d stalls=%0d",
             VECTORS, bubbles, stalls);
    $finish;
  end

  always @(posedge clk) begin
    if (rst_n) begin
      if (pa_valid !== 4'h0 && pa_valid !== 4'hf)
        $fatal(1, "PA valid streams lost plane alignment: %b", pa_valid);

      if (held_valid) begin
        if (pa_valid !== 4'hf)
          $fatal(1, "PA valid dropped while quartet was blocked");
        for (integer branch = 0; branch < 4; branch = branch + 1)
          if (pa_data[branch] !== held_data[branch])
            $fatal(1, "PA%0d changed while quartet was blocked", branch);
      end

      if (pa_valid === 4'hf) begin
        if (pa_ready === 4'hf) begin
          if (got >= VECTORS) $fatal(1, "Unexpected extra PA quartet");
          if (pa_data[0] !== pa0_mem[got]) begin $error("PA0 mismatch word=%0d", got); errors = errors + 1; end
          if (pa_data[1] !== pa1_mem[got]) begin $error("PA1 mismatch word=%0d", got); errors = errors + 1; end
          if (pa_data[2] !== pa2_mem[got]) begin $error("PA2 mismatch word=%0d", got); errors = errors + 1; end
          if (pa_data[3] !== pa3_mem[got]) begin $error("PA3 mismatch word=%0d", got); errors = errors + 1; end
          got = got + 1;
          held_valid = 1'b0;
        end else begin
          for (integer branch = 0; branch < 4; branch = branch + 1)
            held_data[branch] = pa_data[branch];
          held_valid = 1'b1;
          stalls = stalls + 1;
        end
      end else if (held_valid) begin
        $fatal(1, "PA quartet disappeared before ready returned");
      end
    end else begin
      held_valid = 1'b0;
    end
  end
endmodule

`default_nettype wire
