// Compatibility include hub for full-IP scenario tests.
// Each UVM test class is kept in its own file under full_ip/.
  `include "full_ip/thermo5_sku_fifo_reset_phase_test.svh"
  `include "full_ip/thermo5_sku_prestart_empty_test.svh"
  `include "full_ip/thermo5_sku_fifo_boundary_test.svh"
  `include "full_ip/thermo5_sku_bubble_backpressure_test.svh"
  `include "full_ip/thermo5_sku_interp1_empty_blocked_test.svh"
  `include "full_ip/thermo5_sku_long_counter_test.svh"
  `include "full_ip/thermo5_sku_sustained_test.svh"
  `include "full_ip/thermo5_sku_ef2_corner_test.svh"
  `include "full_ip/thermo5_sku_fifo_empty_test.svh"
  `include "full_ip/thermo5_sku_reset_test.svh"
  `include "full_ip/thermo5_sku_reset_sweep_test.svh"
  `include "full_ip/thermo5_sku_illegal_frame_test.svh"
