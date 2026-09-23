`timescale 1ns/1ps
`default_nettype none

//------------------------------------------------------------------------------
// Vendor-neutral 64-bit raw-link bring-up and BERT endpoint.
//
// The endpoint is deliberately above the GT primitive.  tx_data/tx_valid and
// rx_data/rx_valid are the same 64-bit user-word contract used by
// gt_tx_raw64_boundary and by the generated GT Wizard.  It supports a known
// word mode for bring-up and a parallel PRBS31 mode for sustained BERT.
//
// PRBS convention: x^31 + x^28 + 1, LSB emitted first.  The state is advanced
// once per accepted 64-bit word, so the checker is independent of the physical
// serializer width and can be used with a 32/64/128-bit GT user interface after
// changing DATA_W.
//------------------------------------------------------------------------------
module gt_link_bringup_bist #(
  parameter int DATA_W = 64,
  parameter logic [DATA_W-1:0] KNOWN_WORD = 64'h0123_4567_89ab_cdef,
  parameter int READY_FILTER = 4,
  parameter logic [30:0] PRBS_SEED = 31'h7fffffff
) (
  input  wire logic                 clk,
  input  wire logic                 rst_n,
  input  wire logic                 enable,
  input  wire logic                 tx_ready,
  input  wire logic                 rx_ready,
  input  wire logic                 rx_valid,
  input  wire logic [DATA_W-1:0]    rx_data,
  input  wire logic                 inject_error,
  input  wire logic                 inject_error_once,
  input  wire logic                 clear_errors,
  input  wire logic                 mode_prbs31,
  output wire logic                 tx_valid,
  output wire logic [DATA_W-1:0]    tx_data,
  output wire logic                 link_up,
  output wire logic                 training,
  output wire logic                 error_sticky,
  output wire logic [31:0]          error_count,
  output wire logic [31:0]          word_count
);
  typedef enum logic [2:0] {S_RESET, S_WAIT_READY, S_TRAIN, S_RUN_ARM,
                            S_RUN_LOCK, S_RUN, S_ERROR} state_t;
  state_t state_q;
  logic [DATA_W-1:0] tx_data_q;
  logic [30:0] tx_prbs_q, rx_prbs_q;
  logic [31:0] ready_count_q, train_count_q, rx_train_count_q, error_count_q, word_count_q;
  logic inject_once_q;
  logic error_sticky_q;

  function automatic logic [DATA_W-1:0] prbs_word(input logic [30:0] seed);
    logic [30:0] s;
    logic [DATA_W-1:0] w;
    begin
      s = seed;
      for (int k = 0; k < DATA_W; k++) begin
        w[k] = s[0];
        s = {s[29:0], s[30] ^ s[27]};
        if (s == '0) s = PRBS_SEED;
      end
      prbs_word = w;
    end
  endfunction

  function automatic logic [30:0] prbs_advance(input logic [30:0] seed);
    logic [30:0] s;
    begin
      s = seed;
      for (int k = 0; k < DATA_W; k++) begin
        s = {s[29:0], s[30] ^ s[27]};
        if (s == '0) s = PRBS_SEED;
      end
      prbs_advance = s;
    end
  endfunction

  assign link_up = (state_q == S_RUN);
  assign training = (state_q == S_TRAIN);
  assign tx_valid = ((state_q == S_TRAIN) || (state_q == S_RUN_ARM) ||
                     (state_q == S_RUN_LOCK) || (state_q == S_RUN)) &&
                    enable && tx_ready;
  // Training words are held during S_TRAIN.  In RUN the current PRBS word is
  // presented combinationally so the first RUN transfer is not one stale
  // training word ahead of the checker.
  wire [DATA_W-1:0] tx_payload = (state_q == S_TRAIN) ? KNOWN_WORD :
                                  ((state_q == S_RUN_ARM) && mode_prbs31) ? prbs_word(PRBS_SEED) :
                                  (mode_prbs31 ? prbs_word(tx_prbs_q) : KNOWN_WORD);
  assign tx_data = tx_payload ^ ((inject_error || (inject_error_once && !inject_once_q))
                                ? {{(DATA_W-1){1'b0}},1'b1} : '0);
  assign error_sticky = error_sticky_q;
  assign error_count = error_count_q;
  assign word_count = word_count_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q       <= S_RESET;
      tx_data_q     <= KNOWN_WORD;
      tx_prbs_q     <= PRBS_SEED;
      rx_prbs_q     <= PRBS_SEED;
      ready_count_q <= '0;
      train_count_q <= '0;
      rx_train_count_q <= '0;
      error_count_q <= '0;
      word_count_q  <= '0;
      inject_once_q <= 1'b0;
      error_sticky_q<= 1'b0;
    end else begin
      if (clear_errors) begin
        error_count_q  <= '0;
        error_sticky_q <= 1'b0;
      end
      if (inject_error_once) inject_once_q <= 1'b1;
      if (!enable) begin
        state_q <= S_WAIT_READY;
        ready_count_q <= '0;
        train_count_q <= '0;
        rx_train_count_q <= '0;
        tx_prbs_q <= PRBS_SEED;
        rx_prbs_q <= PRBS_SEED;
        inject_once_q <= 1'b0;
      end else begin
        case (state_q)
          S_RESET, S_WAIT_READY: begin
            if (tx_ready && rx_ready) begin
              if (ready_count_q == READY_FILTER-1) begin
                state_q <= S_TRAIN;
                ready_count_q <= '0;
                train_count_q <= '0;
                rx_train_count_q <= '0;
              end else ready_count_q <= ready_count_q + 1'b1;
            end else ready_count_q <= '0;
          end
          S_TRAIN: begin
            // Four known words are enough to establish word alignment before
            // entering PRBS mode.  The RX checker is intentionally active only
            // after this boundary, so a GT gearbox latency is not hidden.
            tx_data_q <= KNOWN_WORD;
            if (tx_ready) begin
              if (train_count_q != 3) begin
                train_count_q <= train_count_q + 1'b1;
              end
            end
            if (rx_valid && rx_ready && rx_data == KNOWN_WORD) begin
              if (rx_train_count_q != 3)
                rx_train_count_q <= rx_train_count_q + 1'b1;
            end
            if ((train_count_q >= 3) && (rx_train_count_q >= 3))
              state_q <= S_RUN_ARM;
          end
          S_RUN_ARM: begin
            // Repeat the seed word until it is observed at RX.  This makes
            // acquisition independent of GT/CDC transport latency.
            tx_prbs_q <= PRBS_SEED;
            rx_prbs_q <= PRBS_SEED;
            if (!mode_prbs31) begin
              state_q <= S_RUN;
            end else if (rx_valid && rx_ready && rx_data == prbs_word(PRBS_SEED)) begin
              tx_prbs_q <= prbs_advance(PRBS_SEED);
              state_q <= S_RUN_LOCK;
            end
          end
          S_RUN_LOCK: begin
            // TX is now advancing. Ignore residual repeated seed words and
            // enter RUN when the first advanced word reaches the checker.
            if (tx_valid) tx_prbs_q <= prbs_advance(tx_prbs_q);
            if (rx_valid && rx_ready &&
                rx_data == prbs_word(prbs_advance(PRBS_SEED))) begin
              rx_prbs_q <= prbs_advance(prbs_advance(PRBS_SEED));
              state_q <= S_RUN;
            end
          end
          S_RUN: begin
            if (!tx_ready || !rx_ready) state_q <= S_ERROR;
            tx_data_q <= mode_prbs31 ? prbs_word(tx_prbs_q) : KNOWN_WORD;
            if (tx_valid) begin
              word_count_q <= word_count_q + 1'b1;
              if (mode_prbs31) tx_prbs_q <= prbs_advance(tx_prbs_q);
            end
            if (rx_valid && rx_ready) begin
              if (rx_data !== (mode_prbs31 ? prbs_word(rx_prbs_q) : KNOWN_WORD)) begin
                error_count_q <= error_count_q + 1'b1;
                error_sticky_q <= 1'b1;
                state_q <= S_ERROR;
              end else if (mode_prbs31) rx_prbs_q <= prbs_advance(rx_prbs_q);
            end
          end
          S_ERROR: begin
            if (!tx_ready || !rx_ready) state_q <= S_WAIT_READY;
            else if (clear_errors) state_q <= S_TRAIN;
          end
          default: state_q <= S_WAIT_READY;
        endcase
      end
    end
  end

`ifndef SYNTHESIS
  always_ff @(posedge clk) begin
    if (rst_n) begin
      // tx_valid is combinational from the FSM and is sampled in the same
      // clocked process; check the externally observable ready contract here
      // and leave state-transition phase checking to the TB protocol checks.
      // tx_valid is a combinational ready-qualified interface signal.  Its
      // value can change in the same NBA region as a testbench control write;
      // the transfer contract is therefore checked by the cycle-level TB.
      assert (!$isunknown({tx_valid, enable, tx_ready}))
        else $error("BERT ready/valid control became unknown");
      assert (!(link_up && !enable))
        else $error("BERT link remained up while disabled");
      assert (error_count_q == 0 || error_sticky_q)
        else $error("BERT error counter changed without sticky status");
    end
  end
`endif
endmodule

`default_nettype wire
