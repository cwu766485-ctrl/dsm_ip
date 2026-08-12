class dsm_rf_item extends uvm_sequence_item;
  bit rf_bit;
  bit signed [15:0] rf_signed;
  bit [23:0] phase;

  `uvm_object_utils_begin(dsm_rf_item)
    `uvm_field_int(rf_bit, UVM_DEFAULT)
    `uvm_field_int(rf_signed, UVM_DEFAULT)
    `uvm_field_int(phase, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "dsm_rf_item");
    super.new(name);
  endfunction
endclass

covergroup dsm_rf_cg with function sample(
  input bit rf_bit_i,
  input bit signed [15:0] rf_signed_i,
  input bit [23:0] phase_i
);
  option.per_instance = 1;
  rf_bit_cp: coverpoint rf_bit_i {
    bins zero = {0};
    bins one = {1};
  }
  rf_sign_cp: coverpoint rf_signed_i[15] {
    bins negative = {1};
    bins positive = {0};
  }
  phase_cp: coverpoint phase_i[1:0] {
    bins phase[] = {[0:3]};
  }
  bit_sign_x: cross rf_bit_cp, rf_sign_cp {
    // The RF interface encodes a one as +0x7fff and a zero as -0x7fff.
    // The opposite sign combinations are structurally unreachable and are
    // asserted separately by dsm_rf_protocol_sva.
    ignore_bins one_negative = binsof(rf_bit_cp.one) &&
                               binsof(rf_sign_cp.negative);
    ignore_bins zero_positive = binsof(rf_bit_cp.zero) &&
                               binsof(rf_sign_cp.positive);
  }
endgroup
