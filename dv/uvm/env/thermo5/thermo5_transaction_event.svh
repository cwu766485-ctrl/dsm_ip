typedef enum bit [3:0] {
  THERMO5_EVENT_SOURCE_BEAT = 4'd0,
  THERMO5_EVENT_PA_WORD = 4'd1,
  THERMO5_EVENT_AXIL_WRITE = 4'd2,
  THERMO5_EVENT_AXIL_READ = 4'd3,
  THERMO5_EVENT_AXIL_RESPONSE = 4'd4,
  THERMO5_EVENT_CDC_WORD = 4'd5,
  THERMO5_EVENT_DSP_OBSERVATION = 4'd6,
  THERMO5_EVENT_EF2_WORD = 4'd7,
  THERMO5_EVENT_EF2_STALL = 4'd8,
  THERMO5_EVENT_RESET = 4'd9
} thermo5_event_kind_e;

typedef enum bit [2:0] {
  THERMO5_CFG_CANDIDATE = 3'd0,
  THERMO5_CFG_PENDING   = 3'd1,
  THERMO5_CFG_APPLIED   = 3'd2,
  THERMO5_CFG_ACKED    = 3'd3,
  THERMO5_CFG_DONE     = 3'd4,
  THERMO5_CFG_REJECTED = 3'd5
} thermo5_config_state_e;

typedef struct {
  int unsigned txn_id;
  int unsigned config_id;
  thermo5_config_state_e state;
} thermo5_config_lifecycle_t;

class thermo5_transaction_event extends uvm_sequence_item;
  `uvm_object_utils(thermo5_transaction_event)

  thermo5_event_kind_e kind;
  longint unsigned event_id;
  int unsigned epoch;
  int unsigned event_cycle;
  int unsigned local_index;
  int unsigned frame_id;
  int unsigned config_id;
  int unsigned pending_config_id;
  bit frame_id_valid;
  bit config_applied;
  realtime time_ns;

  // AXIS source transaction.
  logic [223:0] source_i, source_q;
  logic frame_start, tlast;
  logic signed [15:0] frame_gain;
  int unsigned valid_gap_cycles;

  // Four-plane PA transaction.
  logic [63:0] pa_plane[4];

  // AXI-Lite transaction.
  logic is_write;
  logic [7:0] axil_addr;
  logic [31:0] axil_data, axil_rdata;
  logic [3:0] axil_strb;
  logic [1:0] axil_resp;
  int unsigned axil_txn_id;

  // CDC accepted 8-lane word and its frame metadata.
  logic [127:0] cdc_i, cdc_q;
  logic signed [15:0] cdc_frame_gain;
  logic cdc_frame_start, cdc_frame_end;
  logic [3:0] cdc_residual;
  logic cdc_end_pending, cdc_end_false_arm;

  // DSP boundary snapshot. Flags are probe states, not expected values.
  logic [15:0] dsp_probe_state;
  logic [2:0] dpd_active_taps;
  logic cfg_pending, cfg_ack_core, cfg_done, cfg_busy;
  logic dpd_config_boundary;
  int unsigned dpd_samples[16];
  int unsigned dpd_saturations[16];

  // Accepted 32-lane word presented to the four EF2 branches.
  logic [511:0] ef2_i, ef2_q;
  logic [3:0] ef2_pos_clamp_mask, ef2_neg_clamp_mask;
  logic [3:0] ef2_state_rail_mask;
  logic signed [19:0] ef2_err1_i[4], ef2_err2_i[4];
  logic signed [19:0] ef2_err1_q[4], ef2_err2_q[4];

  function new(string name = "thermo5_transaction_event");
    super.new(name);
  endfunction
endclass
