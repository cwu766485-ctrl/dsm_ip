`timescale 1ns/1ps

module dsm_axis_protocol_sva #(
  parameter int DATA_W = 32,
  parameter int USER_W = 1
) (
  input logic aclk,
  input logic aresetn,
  input logic [DATA_W-1:0] tx_tdata,
  input logic [USER_W-1:0] tx_tuser,
  input logic tx_tvalid,
  input logic tx_tready,
  input logic tx_tlast
);
  default clocking cb @(posedge aclk); endclocking
  property p_axis_stable_under_stall;
    disable iff (!aresetn)
    tx_tvalid && !tx_tready |=> tx_tvalid && $stable({tx_tdata, tx_tuser, tx_tlast});
  endproperty
  a_axis_stable_under_stall: assert property (p_axis_stable_under_stall);
endmodule

module dsm_axi_lite_protocol_sva #(
  parameter int ADDR_W = 9,
  parameter int DATA_W = 32
) (
  input logic aclk,
  input logic aresetn,
  input logic [ADDR_W-1:0] awaddr,
  input logic awvalid,
  input logic awready,
  input logic [DATA_W-1:0] wdata,
  input logic [(DATA_W/8)-1:0] wstrb,
  input logic wvalid,
  input logic wready,
  input logic [1:0] bresp,
  input logic bvalid,
  input logic bready,
  input logic [ADDR_W-1:0] araddr,
  input logic arvalid,
  input logic arready,
  input logic [DATA_W-1:0] rdata,
  input logic [1:0] rresp,
  input logic rvalid,
  input logic rready
);
  default clocking cb @(posedge aclk); endclocking
  a_aw_stable: assert property (
    disable iff (!aresetn) awvalid && !awready |=> awvalid && $stable(awaddr));
  a_w_stable: assert property (
    disable iff (!aresetn) wvalid && !wready |=> wvalid && $stable({wdata, wstrb}));
  a_b_stable: assert property (
    disable iff (!aresetn) bvalid && !bready |=> bvalid && $stable(bresp));
  a_ar_stable: assert property (
    disable iff (!aresetn) arvalid && !arready |=> arvalid && $stable(araddr));
  a_r_stable: assert property (
    disable iff (!aresetn) rvalid && !rready |=> rvalid && $stable({rdata, rresp}));
endmodule

module dsm_rf_protocol_sva (
  input logic aclk,
  input logic aresetn,
  input logic rf_valid,
  input logic rf_bit,
  input logic signed [15:0] rf_signed
);
  default clocking cb @(posedge aclk); endclocking
  property p_rf_encoding;
    disable iff (!aresetn)
    rf_valid |-> (rf_signed == (rf_bit ? 16'sh7fff : -16'sh7fff));
  endproperty
  a_rf_encoding: assert property (p_rf_encoding);
endmodule

module dsm_ip_control_sva (
  input logic aclk,
  input logic aresetn,
  input logic soft_reset,
  input logic s_axis_tready,
  input logic axis_buf_valid,
  input logic rf_valid,
  input logic mp_commit_pending,
  input logic mp_commit_inflight,
  input logic mp_commit_pulse,
  input logic mp_commit_success_event,
  input logic mp_commit_ack,
  input logic mp_commit_failed,
  input logic [7:0] mp_commit_epoch,
  input logic mp_active_bank,
  input logic obs_enable,
  input logic obs_active,
  input logic obs_ready
);
  default clocking cb @(posedge aclk); endclocking

  logic past_valid;
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) past_valid <= 1'b0;
    else past_valid <= 1'b1;
  end

  // A software reset and an in-flight coefficient-bank commit must close the
  // TX acceptance boundary.  The stream source is then responsible for
  // holding its payload stable until TREADY returns.
  a_soft_reset_closes_tx: assert property (
    disable iff (!aresetn) soft_reset |-> !s_axis_tready);
  // CTRL.soft_reset resets the skid buffer and the downstream datapath.  At
  // the following sampling edge no pre-reset item may remain observable.
  a_soft_reset_drains_datapath: assert property (
    disable iff (!aresetn) soft_reset |=> (!axis_buf_valid && !rf_valid));
  c_soft_reset_closes_tx: cover property (
    disable iff (!aresetn) soft_reset && !s_axis_tready);
  c_soft_reset_drains_datapath: cover property (
    disable iff (!aresetn) soft_reset ##1 (!axis_buf_valid && !rf_valid));
  a_commit_closes_tx: assert property (
    disable iff (!aresetn) (mp_commit_pending || mp_commit_inflight) |-> !s_axis_tready);
  c_commit_closes_tx: cover property (
    disable iff (!aresetn) (mp_commit_pending || mp_commit_inflight) && !s_axis_tready);

  // The active bank can only move while the guarded commit operation is live.
  // A software reset is the only non-commit operation allowed to restore the
  // DPD bank to zero.  The core reset is asynchronous to the wrapper register
  // update, so the sampled bank change coincides with the current soft-reset
  // pulse rather than with $past(soft_reset).
  a_bank_change_requires_commit: assert property (
    disable iff (!aresetn)
      (past_valid && $changed(mp_active_bank) && !soft_reset)
      |-> $past(mp_commit_pulse && mp_commit_inflight));
  // A commit is serialized: a request waits for a safe boundary, then only
  // the in-flight phase may toggle the active coefficient bank.  The ACK and
  // monotonically increasing epoch are software-visible completion evidence.
  a_commit_serialized: assert property (
    disable iff (!aresetn) !(mp_commit_pending && mp_commit_inflight));
  a_bank_change_is_acknowledged: assert property (
    disable iff (!aresetn)
      (past_valid && $changed(mp_active_bank) && !soft_reset)
      |=> (mp_commit_ack || soft_reset));
  a_ack_requires_inflight: assert property (
    disable iff (!aresetn)
      past_valid && $rose(mp_commit_ack) |-> $past(mp_commit_inflight));
  // Epoch is transaction history, not an independent state machine.  Check
  // both directions so an epoch cannot move without a successful commit and
  // every successful commit advances it exactly once.  ACK may be cleared by
  // a coincident software reset, which is the defined transaction-cancel path.
  a_epoch_change_requires_success: assert property (
    disable iff (!aresetn)
      past_valid && $changed(mp_commit_epoch) |-> $past(mp_commit_success_event));
  a_commit_success_updates_epoch: assert property (
    disable iff (!aresetn)
      mp_commit_success_event
      |=> ((mp_commit_epoch == ($past(mp_commit_epoch) + 8'd1)) &&
           (mp_commit_ack || soft_reset)));
  a_failed_commit_keeps_bank: assert property (
    disable iff (!aresetn)
      (past_valid && $rose(mp_commit_failed) && !soft_reset)
      |-> $stable(mp_active_bank));
  c_bank_change: cover property (
    disable iff (!aresetn) $changed(mp_active_bank));
  c_commit_ack: cover property (
    disable iff (!aresetn) $rose(mp_commit_ack));
  c_commit_failure: cover property (
    disable iff (!aresetn) $rose(mp_commit_failed));

  // The observer must never accept feedback before its software-controlled
  // enable/start state has made the collection window active.
  a_observer_ready_requires_active: assert property (
    disable iff (!aresetn) obs_ready |-> (obs_enable && obs_active));
  c_observer_ready: cover property (
    disable iff (!aresetn) obs_ready && obs_enable && obs_active);
endmodule

// A data-aware FIFO checker complements the AXI stability assertion above.
// FIFO ordering cannot be fully expressed by a local ready/valid property:
// it requires remembering the payload sequence at the write clock and
// comparing it at the unrelated read clock.  This checker is simulation-only
// verification collateral; it is not part of synthesizable RTL.
module dsm_async_fifo_order_checker #(
  parameter int DATA_W = 32,
  parameter int USER_W = 1,
  parameter int MAX_TRANSACTIONS = 4096
) (
  input logic s_clk,
  input logic s_rst_n,
  input logic [DATA_W-1:0] s_tdata,
  input logic s_tlast,
  input logic [USER_W-1:0] s_tuser,
  input logic s_tvalid,
  input logic s_tready,
  input logic m_clk,
  input logic m_rst_n,
  input logic [DATA_W-1:0] m_tdata,
  input logic m_tlast,
  input logic [USER_W-1:0] m_tuser,
  input logic m_tvalid,
  input logic m_tready
);
  logic [DATA_W+USER_W:0] expected_mem [0:MAX_TRANSACTIONS-1];
  int unsigned write_sequence;
  int unsigned read_sequence;

  always @(posedge s_clk or negedge s_rst_n) begin
    if (!s_rst_n) begin
      write_sequence <= 0;
    end else if (s_tvalid && s_tready) begin
      assert (write_sequence < MAX_TRANSACTIONS)
        else $error("FIFO checker source transaction limit exceeded");
      expected_mem[write_sequence] <= {s_tdata, s_tlast, s_tuser};
      write_sequence <= write_sequence + 1;
    end
  end

  always @(posedge m_clk or negedge m_rst_n) begin
    if (!m_rst_n) begin
      read_sequence <= 0;
    end else if (m_tvalid && m_tready) begin
      assert (read_sequence < write_sequence)
        else $error("FIFO output transaction has no corresponding input");
      assert ({m_tdata, m_tlast, m_tuser} === expected_mem[read_sequence])
        else $error("FIFO ordering/payload mismatch at transaction %0d", read_sequence);
      read_sequence <= read_sequence + 1;
    end
  end
endmodule
