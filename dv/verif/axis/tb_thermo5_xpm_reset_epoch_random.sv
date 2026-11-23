`timescale 1ns/1ps
`default_nettype none

// Product-width XPM FIFO reset/epoch stress. The clocks keep the product
// periods while each invocation selects independent phase offsets. Resets
// abort both queued FIFO data and active source traffic; accepted output is
// checked against a fresh-epoch reference stream.
module tb_thermo5_xpm_reset_epoch_random;
  localparam int FIFO_W = 2*14*16 + 2 + 16;
  localparam int FIFO_DEPTH = 16;

  logic wr_clk = 1'b0;
  logic rd_clk = 1'b0;
  logic common_n = 1'b0;
  logic wr_valid = 1'b0;
  logic rd_ready = 1'b0;
  logic [FIFO_W-1:0] wr_data = '0;
  logic [1:0] sink_mode = 2'd0;
  integer axis_phase_ps = 0;
  integer core_phase_ps = 0;
  integer release_delay_ps = 0;
  integer test_seed = 32'h13579bdf;

  wire wn, rn;
  wire wr_ready, wr_full, rd_valid, rd_empty;
  wire [FIFO_W-1:0] rd_data;
  wire [4:0] rd_count;

  integer exp_wr = 0;
  integer exp_rd = 0;
  integer observed_words = 0;
  integer reset_epochs = 0;
  integer aborted_words = 0;
  integer wr_stall_cycles = 0;
  integer rd_stall_cycles = 0;

  logic [FIFO_W-1:0] expected [0:4095];
  logic wr_stalled_q = 1'b0;
  logic [FIFO_W-1:0] wr_stalled_data_q = '0;
  logic rd_stalled_q = 1'b0;
  logic [FIFO_W-1:0] rd_stalled_data_q = '0;

  initial begin
    void'($value$plusargs("AXIS_PHASE_PS=%d", axis_phase_ps));
    void'($value$plusargs("CORE_PHASE_PS=%d", core_phase_ps));
    void'($value$plusargs("RELEASE_DELAY_PS=%d", release_delay_ps));
    void'($value$plusargs("SEED=%d", test_seed));
    # (axis_phase_ps * 1ps);
    forever #4ns wr_clk = ~wr_clk;
  end

  initial begin
    # (core_phase_ps * 1ps);
    forever #2.285714ns rd_clk = ~rd_clk;
  end

  dsm_reset_sync u_wr_reset (.clk(wr_clk), .arst_n(common_n), .srst_n(wn));
  dsm_reset_sync u_rd_reset (.clk(rd_clk), .arst_n(common_n), .srst_n(rn));

  dsm_xpm_async_fifo #(
    .DATA_W(FIFO_W),
    .ADDR_W(4),
    .COMMON_RESET_EPOCH(1'b1)
  ) dut (
    .wr_clk(wr_clk), .wr_rst_n(wn), .wr_data_vec(wr_data),
    .wr_valid(wr_valid), .wr_ready(wr_ready), .wr_full(wr_full),
    .rd_clk(rd_clk), .rd_rst_n(rn), .rd_data(rd_data),
    .rd_valid(rd_valid), .rd_ready(rd_ready), .rd_empty(rd_empty),
    .rd_count(rd_count)
  );

  always @(negedge common_n) begin
    exp_wr = 0;
    exp_rd = 0;
    reset_epochs = reset_epochs + 1;
    wr_stalled_q = 1'b0;
    rd_stalled_q = 1'b0;
  end

  always @(posedge wr_clk) begin
    if (!common_n || !wn) begin
      wr_stalled_q <= 1'b0;
    end else begin
      if (wr_stalled_q && (!wr_valid || wr_data !== wr_stalled_data_q))
        $fatal(1, "source violated VALID/payload hold under backpressure");
      wr_stalled_q <= wr_valid && !wr_ready;
      if (wr_valid && !wr_ready) begin
        wr_stall_cycles = wr_stall_cycles + 1;
        wr_stalled_data_q <= wr_data;
      end
    end
    if (common_n && wn && wr_valid && wr_ready) begin
      if (exp_wr >= 4096) $fatal(1, "reference queue capacity exceeded");
      expected[exp_wr] = wr_data;
      exp_wr = exp_wr + 1;
    end
  end

  always @(posedge rd_clk) begin
    if (!common_n || !rn) begin
      rd_stalled_q <= 1'b0;
    end else begin
      if (rd_stalled_q && (!rd_valid || rd_data !== rd_stalled_data_q))
        $fatal(1, "FIFO violated VALID/data hold under backpressure");
      rd_stalled_q <= rd_valid && !rd_ready;
      if (rd_valid && !rd_ready) begin
        rd_stall_cycles = rd_stall_cycles + 1;
        rd_stalled_data_q <= rd_data;
      end
    end
    if (common_n && rn && rd_count >= 2 && exp_wr < 2)
      $fatal(1, "prefill count before two accepted current-epoch writes count=%0d writes=%0d", rd_count, exp_wr);
    if (common_n && rn && rd_ready && rd_valid) begin
      if (exp_rd >= exp_wr)
        $fatal(1, "FIFO emitted an unaccepted/stale word epoch=%0d read=%0d writes=%0d", reset_epochs, exp_rd, exp_wr);
      if (rd_data !== expected[exp_rd])
        $fatal(1, "FIFO data mismatch/stale epoch=%0d index=%0d got=%h expected=%h", reset_epochs, exp_rd, rd_data, expected[exp_rd]);
      exp_rd = exp_rd + 1;
      observed_words = observed_words + 1;
    end
  end

  always @(negedge rd_clk) begin
    if (!common_n || !rn || sink_mode == 2'd0)
      rd_ready <= 1'b0;
    else if (sink_mode == 2'd2)
      rd_ready <= 1'b1;
    else
      rd_ready <= ($urandom_range(0, 3) != 0); // 25% sink stall
  end

  function automatic logic [FIFO_W-1:0] make_word(input integer epoch_id, input integer sequence_id);
    logic [FIFO_W-1:0] value;
    logic [31:0] state;
    integer base;
    integer bit_index;
    begin
      value = '0;
      state = 32'h9e3779b9 ^ (epoch_id * 32'h85ebca6b) ^ (sequence_id * 32'hc2b2ae35);
      for (base = 0; base < FIFO_W; base = base + 32) begin
        state = state ^ (state << 13);
        state = state ^ (state >> 17);
        state = state ^ (state << 5);
        for (bit_index = 0; bit_index < 32 && (base + bit_index) < FIFO_W; bit_index = bit_index + 1)
          value[base + bit_index] = state[bit_index];
      end
      make_word = value;
    end
  endfunction

  task automatic send_words(input integer epoch_id, input integer target_count);
    integer accepted;
    integer bubble;
    begin
      accepted = 0;
      while (accepted < target_count && common_n) begin
        @(negedge wr_clk);
        // A source bubble may be inserted only between transactions. Once
        // TVALID is asserted, preserve both TVALID and payload until handshake.
        if (!wr_valid) begin
          bubble = $urandom_range(0, 3);
          if (bubble == 0) begin
            wr_valid <= 1'b0; // 25% source bubble
          end else begin
            wr_data <= make_word(epoch_id, accepted);
            wr_valid <= 1'b1;
          end
        end
        @(posedge wr_clk);
        if (common_n && wn && wr_valid && wr_ready)
          accepted = accepted + 1;
      end
      @(negedge wr_clk);
      wr_valid <= 1'b0;
    end
  endtask

  task automatic begin_epoch(input integer epoch_id);
    begin
      wr_valid = 1'b0;
      sink_mode = 2'd0;
      common_n = 1'b0;
      repeat (3) @(posedge wr_clk);
      repeat (2) @(posedge rd_clk);
      #(release_delay_ps * 1ps);
      common_n = 1'b1;
      wait (wn && rn && wr_ready);
    end
  endtask

  initial begin : scenario
    integer epoch_id;
    integer before_read;
    #1ps;
    common_n = 1'b1;
    #1ps common_n = 1'b0;
    for (epoch_id = 0; epoch_id < 12; epoch_id = epoch_id + 1) begin
      begin_epoch(epoch_id);
      if ((epoch_id % 4) == 0) begin
        // Deliberately leave unread words in the product FIFO, then abort.
        sink_mode = 2'd0;
        send_words(epoch_id, FIFO_DEPTH);
        if (exp_wr != FIFO_DEPTH || exp_rd != 0)
          $fatal(1, "unread-reset precondition failed epoch=%0d writes=%0d reads=%0d", epoch_id, exp_wr, exp_rd);
        aborted_words = aborted_words + (exp_wr - exp_rd);
        @(negedge wr_clk);
        wr_data <= make_word(epoch_id, FIFO_DEPTH);
        wr_valid <= 1'b1;
        wait (!wr_ready);
        repeat (2) @(posedge wr_clk);
        if (!wr_valid || wr_data !== make_word(epoch_id, FIFO_DEPTH))
          $fatal(1, "source did not hold the blocked write through FIFO full");
        #317ps common_n = 1'b0;
      end else if ((epoch_id % 4) == 1) begin
        // Reset while accepted traffic continues and the sink applies stalls.
        sink_mode = 2'd1;
        fork
          send_words(epoch_id, 96);
          begin
            wait (exp_wr >= 12);
            #431ps;
            aborted_words = aborted_words + (exp_wr - exp_rd);
            common_n = 1'b0;
          end
        join_any
        disable fork;
        wr_valid = 1'b0;
      end else begin
        // Full legal stream with independent source bubbles and sink stalls.
        sink_mode = 2'd1;
        before_read = observed_words;
        send_words(epoch_id, 40);
        wait (exp_rd == exp_wr);
        if ((observed_words - before_read) != 40)
          $fatal(1, "drain count mismatch epoch=%0d delta=%0d", epoch_id, observed_words-before_read);
        sink_mode = 2'd0;
        #293ps common_n = 1'b0;
      end
      repeat (2) @(posedge wr_clk);
    end

    if (observed_words < 80 || aborted_words < 20 || reset_epochs < 12 ||
        wr_stall_cycles == 0 || rd_stall_cycles == 0)
      $fatal(1, "insufficient scenario activity observed=%0d aborted=%0d resets=%0d wr_stalls=%0d rd_stalls=%0d",
             observed_words, aborted_words, reset_epochs, wr_stall_cycles, rd_stall_cycles);
    $display("THERMO5_XPM_RESET_EPOCH_RANDOM_PASS width=%0d depth=%0d phases_ps=%0d/%0d release_ps=%0d epochs=%0d outputs=%0d aborted=%0d wr_stalls=%0d rd_stalls=%0d seed=%0d",
             FIFO_W, FIFO_DEPTH, axis_phase_ps, core_phase_ps, release_delay_ps, reset_epochs,
             observed_words, aborted_words, wr_stall_cycles, rd_stall_cycles, test_seed);
    $finish;
  end

  initial begin
    #200000ns;
    $fatal(1, "watchdog expired");
  end
endmodule

`default_nettype wire
