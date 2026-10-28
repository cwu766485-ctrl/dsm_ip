# Primary Linux regression flow for VCS/Verdi. Questa remains available for
# portability, while Windows XSim is an optional smoke-only path.

SHELL := /bin/bash
ROOT := $(abspath $(CURDIR)/../../..)
UVM_ROOT := $(ROOT)/dv/uvm
FILELIST := $(UVM_ROOT)/sim/uvm_filelist.f
OUT := $(UVM_ROOT)/sim/out

SIM ?= vcs
VCS ?= vcs
URG ?= $(if $(VCS_HOME),$(VCS_HOME)/bin/urg,urg)
VERDI ?= verdi
VLOG ?= vlog
VSIM ?= vsim
PYTHON ?= python3.12
UVM_HOME ?=
VERDI_HOME ?=
UVM_TESTNAME ?= dsm_bp_test
UVM_VERBOSITY ?= UVM_LOW
UVM_SEED ?= 1
RUN_TAG ?= $(UVM_TESTNAME)_seed$(UVM_SEED)
RUN_TAGS ?= $(RUN_TAG)
URG_ELFILE ?=
COVERAGE ?= 1
FSDB ?= 0

VCS_OUT := $(OUT)/vcs
VCS_BIN := $(VCS_OUT)/simv
VCS_LOG := $(VCS_OUT)/compile.log
RUN_DIR := $(VCS_OUT)/runs/$(RUN_TAG)
QUESTA_OUT := $(OUT)/questa
THERMO5_FIFO_IMPL ?= generic
THERMO5_XPM_ROOT ?=
THERMO5_OUT := $(ROOT)/runs/uvm_thermo5_i2_d1$(if $(filter xpm,$(THERMO5_FIFO_IMPL)),_xpm,)
THERMO5_XPM_SOURCES := $(THERMO5_XPM_ROOT)/data/verilog/src/glbl.v \
  $(THERMO5_XPM_ROOT)/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv \
  $(THERMO5_XPM_ROOT)/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv \
  $(THERMO5_XPM_ROOT)/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv
THERMO5_XPM_ARGS := $(if $(filter xpm,$(THERMO5_FIFO_IMPL)),+define+THERMO5_XPM_FIFO $(THERMO5_XPM_SOURCES) -top glbl,)
THERMO5_VECTORS := $(ROOT)/runs/uvm_thermo5_i2_d1/vectors
THERMO5_LONG_VECTORS ?= $(ROOT)/runs/thermo5_axil_tlast_112_vectors
THERMO5_CENTERED_LP_VECTORS ?= $(ROOT)/runs/thermo5_centered_low_power_vectors
THERMO5_NONLINEAR_SHORT_VECTORS ?= $(ROOT)/runs/thermo5_centered_nonlinear_short_vectors
THERMO5_NONLINEAR_LONG_VECTORS ?= $(ROOT)/runs/thermo5_centered_nonlinear_long_vectors
THERMO5_STOP_RESTART_VECTORS ?= $(ROOT)/runs/thermo5_centered_stop_restart_vectors
THERMO5_STOP_RESTART_TIDSM_ORDER ?= 2
THERMO5_STOP_RESTART_STEP ?= 5120
THERMO5_FILELIST := $(UVM_ROOT)/sim/thermo5_sku_filelist.f
THERMO5_EXTRA_ARGS ?=
THERMO5_TESTNAME ?= thermo5_sku_bittrue_test
THERMO5_USE_AXIL ?= 0
THERMO5_TOP ?= thermo5_sku_uvm_tb
THERMO5_CENTERED_CUBIC ?= 1
THERMO5_LOW_POWER ?= 0
THERMO5_TIDSM_ORDER ?= 2
THERMO5_STEP ?= 5120
THERMO5_DUT_ARGS := $(if $(filter 1,$(THERMO5_USE_AXIL)),+define+THERMO5_AXIL_CONTROL,) \
	$(if $(filter 1,$(THERMO5_CENTERED_CUBIC)),+define+THERMO5_CENTERED_CUBIC,) \
	$(if $(filter 1,$(THERMO5_LOW_POWER)),+define+THERMO5_LOW_POWER,) \
	+define+THERMO5_TIDSM_ORDER=$(THERMO5_TIDSM_ORDER) \
	+define+THERMO5_STEP=$(THERMO5_STEP)
THERMO5_DEBUG_ARGS := $(if $(filter 1,$(THERMO5_USE_AXIL)),-debug_access+all,)
THERMO5_RUN_LOG := $(THERMO5_OUT)/$(THERMO5_TESTNAME)_seed$(UVM_SEED).log
THERMO5_COVERAGE ?= 1
THERMO5_COV_ARGS := $(if $(filter 1,$(THERMO5_COVERAGE)),-cm line+cond+fsm+tgl+branch+assert,)
GT_PARENT_FAULT_OUT ?= $(ROOT)/runs/thermo5_gt_parent_fault_vcs
GT_PARENT_FAULT_SRCS := \
	dv/verif/integration/gt_parent_fault/tb_thermo5_gt_parent_link_fault.sv \
	rtl/axis/dsm_reset_sync.sv \
	rtl/axis/dsm_frame_power_ctrl.sv \
	rtl/axis/dsm_async_fifo.sv \
	rtl/axis/dsm_axis14_to_core8_cdc.sv \
	rtl/frontend/dsm_frame_gain_vector.sv \
	rtl/dpd/dpd_poly.v \
	rtl/dpd/dpd_memory_poly.v \
	rtl/dpd/dpd_vector16_memory_poly.sv \
	rtl/dpd/dpd_vector_elastic_buffer.sv \
	rtl/interp/dsm_interp_x2_centered_cubic_vector.sv \
	rtl/interp/dsm_interp_x2_polyphase_vector.sv \
	rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv \
	rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv \
	rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv \
	rtl/gt/gt_tx_user_bridge.sv \
	rtl/gt/gt_tx_raw64_boundary.sv \
	rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv \
	rtl/tx_bandpass_if/tid32_thermo5_axis_frontend_tx.sv \
	rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv \
	rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv \
	rtl/gt/thermo5_raw64_continuous_tx.sv \
	fpga/zu15eg/rtl/thermo5_qsfp_gt14_parent.sv
THERMO5_STRESS_SEEDS ?= 11 12 13 14 15 16 17 18 19 20
THERMO5_URG_EXTRA_VDBS ?=

VCS_COV_COMPILE := $(if $(filter 1,$(COVERAGE)),-cm line+cond+fsm+tgl+branch+assert,)
VCS_COV_RUN := $(if $(filter 1,$(COVERAGE)),-cm line+cond+fsm+tgl+branch+assert -cm_dir $(RUN_DIR)/simv.vdb,)
VCS_COV_HIER := $(if $(filter 1,$(COVERAGE)),-cm_hier $(UVM_ROOT)/sim/dut_coverage.hier,)
VCS_RUN_ARGS ?= -no_save
VCS_FSDB_COMPILE :=
VCS_FSDB_RUN :=
ifeq ($(FSDB),1)
  ifeq ($(strip $(VERDI_HOME)),)
    $(error VERDI_HOME must be set when FSDB=1)
  endif
  VCS_FSDB_COMPILE := +define+DSM_ENABLE_FSDB \
    -P $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab \
       $(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a
  VCS_FSDB_RUN := +FSDB_FILE=$(RUN_DIR)/waves.fsdb
endif

UVM_ARGS := +UVM_TESTNAME=$(UVM_TESTNAME) \
            +UVM_VERBOSITY=$(UVM_VERBOSITY) \
            +ntb_random_seed=$(UVM_SEED)

.PHONY: help check-tools formal-check-tools vcs vcs-run vcs-run-only regression coverage-merge \
        verdi questa questa-run questa-run-only run clean thermo5-vcs thermo5-vcs-run \
        thermo5-vcs-run-only thermo5-vcs-regression thermo5-vcs-negative thermo5-coverage-merge thermo5-vcs-multiseed \
        thermo5-axil-config-vcs-run thermo5-axil-graceful-stop-vcs-run thermo5-axil-register-access-vcs-run \
        thermo5-axil-stop-restart-vcs-run \
        thermo5-axil-long-frame-vcs-run \
        thermo5-axil-coeff-transport-vcs-run \
        thermo5-axil-nonlinear-dpd-vcs-run thermo5-axil-tap4-identity-vcs-run \
        thermo5-centered-cubic-vcs thermo5-centered-cubic-low-power-vcs \
thermo5-centered-cubic-ef2-vcs-regression thermo5-ef2-qualification thermo5-ef2-pair-vcs thermo5-ef2-serdes-vcs \
        thermo5-gt-parent-link-fault-vcs \
        thermo5-axil-centered-nonlinear-bittrue-vcs \
        thermo5-axil-boundary-phase-vcs-run thermo5-axil-vcs-negative thermo5-axil-vcs-mailbox-negative \
        thermo5-axil-vcs-parameter-guard thermo5-axil-vcs-regression thermo5-axil-cfg-unit-vcs

help:
	@echo "Primary targets:"
	@echo "  make vcs                 Compile once with VCS"
	@echo "  make vcs-run             Compile and run one test/seed"
	@echo "  make regression          Run Python test/seed matrix"
	@echo "  make coverage-merge      Merge selected VCS coverage databases with URG"
	@echo "  make thermo5-vcs-run     Compile/run two-clock thermo5/2-tap/DPD1 subsystem"
	@echo "  make thermo5-axil-config-vcs-run  Run AXI-Lite config/CDC plus bit-true test"
	@echo "  make thermo5-axil-graceful-stop-vcs-run  Run AXI-Lite mid-frame graceful-stop test"
	@echo "  make thermo5-axil-stop-restart-vcs-run   Run centered-cubic two-packet STOP/drain/restart test"
	@echo "  make thermo5-axil-long-frame-vcs-run  Run 64-beat/two-quantum TLAST and drain test"
	@echo "  make thermo5-axil-register-access-vcs-run  Run AXI-Lite register/protocol-only test"
	@echo "  make thermo5-axil-coeff-transport-vcs-run  Run coefficient mailbox transport case"
	@echo "  make thermo5-axil-nonlinear-dpd-vcs-run  Run nonlinear DPD coefficient case"
	@echo "  make thermo5-axil-tap4-identity-vcs-run  Run legal four-tap identity case"
	@echo "  make thermo5-axil-boundary-phase-vcs-run  Run commit/frame-boundary phase case"
	@echo "  make thermo5-axil-vcs-regression  Run focused AXI-Lite tests, integration tests and URG merge"
	@echo "  make thermo5-vcs-regression  Run bittrue/reset/FIFO/negative-frame suite"
	@echo "  make thermo5-vcs-run THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120  Run EF2 candidate bittrue test"
	@echo "  make thermo5-ef2-qualification  Run fixed-seed long-frame EF2 qualification and hash manifest"
	@echo "  make thermo5-ef2-pair-vcs  Compare exact pair-look-ahead core with scalar EF2 baseline"
	@echo "  make thermo5-ef2-serdes-vcs  Compare EF2 four-plane words through serializer loopback"
	@echo "  make thermo5-gt-parent-link-fault-vcs  Verify active-packet GT loss, PA blanking and reset recovery"
	@echo "  make thermo5-vcs-multiseed   Run ten seeds each of PA stalls and FIFO boundary"
	@echo "  make thermo5-vcs-regression THERMO5_FIFO_IMPL=xpm THERMO5_XPM_ROOT=<Vivado root>"
	@echo "  make thermo5-coverage-merge  Merge passing thermo5 VCS VDBs with URG"
	@echo "  make formal-check-tools  Probe the Linux EDA environment for a formal engine"
	@echo "  IP functional closure: ./dv/uvm/sim/run_ip_coverage_linux.sh"
	@echo "  PowerShell bridge: .\\dv\\uvm\\sim\\run_ip_coverage_bridge.ps1"
	@echo "  make verdi RUN_TAG=...   Open an FSDB generated with FSDB=1"
	@echo "Optional targets: questa-run, check-tools, clean"
	@echo "Variables: UVM_TESTNAME, UVM_SEED, RUN_TAGS, UVM_VERBOSITY, COVERAGE, FSDB, VERDI_HOME"
	@echo "Thermo5: UVM_SEED, THERMO5_EXTRA_ARGS=+STRESS_PA_READY, THERMO5_TIDSM_ORDER (1/2), THERMO5_STEP"
	@echo "Stop/restart default: centered-cubic EF2, THERMO5_STOP_RESTART_TIDSM_ORDER=2 THERMO5_STOP_RESTART_STEP=5120"

check-tools:
	@command -v $(VCS) >/dev/null 2>&1 || { echo "ERROR: VCS not found"; exit 127; }
	@command -v $(PYTHON) >/dev/null 2>&1 || { echo "ERROR: $(PYTHON) not found"; exit 127; }
	@echo "VCS:   $$(command -v $(VCS))"
	@echo "Python: $$(command -v $(PYTHON))"
	@echo "Verdi: $$(command -v $(VERDI) 2>/dev/null || echo NOT_FOUND)"

# This target only discovers whether a formal engine is present. It does not
# claim that any property has been proven.
formal-check-tools:
	@bash $(UVM_ROOT)/formal/check_formal_tools_linux.sh

vcs:
	@mkdir -p $(VCS_OUT)
	@$(PYTHON) $(UVM_ROOT)/refmodel/python/generate_performance_sku_vectors.py
	@cd $(ROOT) && $(VCS) -full64 -sverilog -ntb_opts uvm \
		-timescale=1ns/1ps -f $(FILELIST) -Mdir=$(VCS_OUT)/csrc \
		-kdb -debug_access+all $(VCS_COV_COMPILE) $(VCS_COV_HIER) $(VCS_FSDB_COMPILE) \
		-o $(VCS_BIN) -l $(VCS_LOG)

vcs-run: vcs vcs-run-only

# Separate DUT top within the same UVM tree.  The legacy dsm_ip_axi_top
# regression remains intact; the thermo5 subsystem is not that IP instance.
thermo5-vcs:
	@command -v $(VCS) >/dev/null 2>&1 || { echo "ERROR: VCS not found"; exit 127; }
	@test '$(THERMO5_FIFO_IMPL)' = generic -o '$(THERMO5_FIFO_IMPL)' = xpm || { echo "ERROR: THERMO5_FIFO_IMPL must be generic or xpm"; exit 2; }
	@if [ '$(THERMO5_FIFO_IMPL)' = xpm ]; then \
	  test -n '$(THERMO5_XPM_ROOT)' || { echo "ERROR: set THERMO5_XPM_ROOT to the Vivado installation root"; exit 2; }; \
	  for src in $(THERMO5_XPM_SOURCES); do test -f "$$src" || { echo "ERROR: missing XPM source $$src"; exit 2; }; done; \
	fi
	@test -f $(THERMO5_VECTORS)/tid32_thermo5_frontend_pa3.mem || { echo "ERROR: generate thermo5 vectors with MATLAB or generate_thermo5_frontend_vectors.py first"; exit 2; }
	@mkdir -p $(THERMO5_OUT)
	@cd $(ROOT) && $(VCS) -full64 -sverilog -ntb_opts uvm +lint=TFIPC-L \
		-timescale=1ns/1ps -f $(THERMO5_FILELIST) $(THERMO5_XPM_ARGS) $(THERMO5_DUT_ARGS) \
		-top $(THERMO5_TOP) -Mdir=$(THERMO5_OUT)/csrc \
		$(THERMO5_COV_ARGS) $(THERMO5_DEBUG_ARGS) \
		-o $(THERMO5_OUT)/simv -l $(THERMO5_OUT)/compile.log

thermo5-vcs-run: thermo5-vcs thermo5-vcs-run-only

thermo5-axil-config-vcs-run:
	@$(MAKE) --no-print-directory thermo5-vcs-run \
	  THERMO5_USE_AXIL=1 THERMO5_TESTNAME=thermo5_sku_axil_config_test

thermo5-axil-graceful-stop-vcs-run:
	@$(MAKE) --no-print-directory thermo5-vcs-run \
	  THERMO5_USE_AXIL=1 THERMO5_TESTNAME=thermo5_sku_axil_graceful_stop_test

# A reproducible multi-quantum packet case. Generate 112-word MATLAB vectors
# first; this represents 64 accepted 14-lane AXIS beats and two 32-beat
# stop-safe quanta (112 words on each of four output planes).
thermo5-axil-long-frame-vcs-run:
	@$(MAKE) --no-print-directory thermo5-vcs THERMO5_USE_AXIL=1 \
	  THERMO5_VECTORS=$(THERMO5_LONG_VECTORS)
	@$(MAKE) --no-print-directory thermo5-vcs-run-only THERMO5_USE_AXIL=1 \
	  THERMO5_TESTNAME=thermo5_sku_axil_graceful_stop_test \
	  THERMO5_VECTORS=$(THERMO5_LONG_VECTORS) UVM_SEED=420112 \
	  THERMO5_EXTRA_ARGS=+CORE_WORDS=112

thermo5-axil-register-access-vcs-run:
	@$(MAKE) --no-print-directory thermo5-vcs-run \
	  THERMO5_USE_AXIL=1 THERMO5_TESTNAME=thermo5_sku_axil_register_access_test

thermo5-axil-coeff-transport-vcs-run:
	@$(MAKE) --no-print-directory thermo5-vcs-run \
	  THERMO5_USE_AXIL=1 THERMO5_TESTNAME=thermo5_sku_axil_coeff_transport_test

thermo5-axil-nonlinear-dpd-vcs-run:
	@$(MAKE) --no-print-directory thermo5-vcs-run \
	  THERMO5_USE_AXIL=1 THERMO5_TESTNAME=thermo5_sku_axil_nonlinear_dpd_test

thermo5-axil-tap4-identity-vcs-run:
	@$(MAKE) --no-print-directory thermo5-vcs-run \
	  THERMO5_USE_AXIL=1 THERMO5_TESTNAME=thermo5_sku_axil_tap4_identity_test

thermo5-axil-boundary-phase-vcs-run:
	@$(MAKE) --no-print-directory thermo5-vcs-run \
	  THERMO5_USE_AXIL=1 THERMO5_TESTNAME=thermo5_sku_axil_boundary_phase_test

thermo5-vcs-run-only:
	@test -x $(THERMO5_OUT)/simv || { echo "ERROR: run thermo5-vcs first"; exit 2; }
	@cd $(ROOT) && $(THERMO5_OUT)/simv \
		+UVM_TESTNAME=$(THERMO5_TESTNAME) \
		+VEC_DIR=$(THERMO5_VECTORS) +ntb_random_seed=$(UVM_SEED) \
		$(THERMO5_COV_ARGS) -cm_dir $(THERMO5_OUT)/cov_$(THERMO5_TESTNAME)_seed$(UVM_SEED).vdb \
		$(THERMO5_EXTRA_ARGS) -l $(THERMO5_RUN_LOG)
	@grep -q 'UVM_ERROR *: *0' $(THERMO5_RUN_LOG)
	@grep -q 'UVM_FATAL *: *0' $(THERMO5_RUN_LOG)
	@grep -q 'THERMO5_.*_UVM_PASS' $(THERMO5_RUN_LOG)
	@! grep -q 'DSM frame_start was not aligned' $(THERMO5_RUN_LOG)

thermo5-vcs-negative:
	@test -x $(THERMO5_OUT)/simv || { echo "ERROR: run thermo5-vcs first"; exit 2; }
	@set +e; cd $(ROOT) && $(THERMO5_OUT)/simv \
		+UVM_TESTNAME=thermo5_sku_illegal_frame_test \
		+VEC_DIR=$(THERMO5_VECTORS) +ntb_random_seed=$(UVM_SEED) \
		$(THERMO5_COV_ARGS) -cm_dir $(THERMO5_OUT)/cov_illegal_frame_seed$(UVM_SEED).vdb \
		-l $(THERMO5_OUT)/illegal_frame_seed$(UVM_SEED).log; \
		status=$$?; set -e; \
		grep -q 'DSM frame_start was not aligned to a 56-sample boundary' $(THERMO5_OUT)/illegal_frame_seed$(UVM_SEED).log; \
		grep -q 'THERMO5_ILLEGAL_FRAME_OBSERVED' $(THERMO5_OUT)/illegal_frame_seed$(UVM_SEED).log; \
		grep -q 'UVM_FATAL *: *0' $(THERMO5_OUT)/illegal_frame_seed$(UVM_SEED).log; \
		echo "Expected negative assertion observed (simulator exit $$status)"

# Full AXI-Lite wrapper integration coverage is intentionally a distinct
# configuration from the frozen parallel-config SKU suite. The positive test
# covers register/mailbox operation, PA backpressure, bit-true output and reset
# defaults; the negative test expects the illegal-frame RTL assertion.
thermo5-axil-vcs-negative:
	@test -x $(THERMO5_OUT)/simv || { echo "ERROR: run thermo5-vcs with THERMO5_USE_AXIL=1 first"; exit 2; }
	@set +e; cd $(ROOT) && $(THERMO5_OUT)/simv \
		+UVM_TESTNAME=thermo5_sku_axil_illegal_frame_test \
		+VEC_DIR=$(THERMO5_VECTORS) +ntb_random_seed=420102 \
		$(THERMO5_COV_ARGS) -cm_dir $(THERMO5_OUT)/cov_axil_illegal_frame_seed420102.vdb \
		-l $(THERMO5_OUT)/axil_illegal_frame_seed420102.log; \
	status=$$?; set -e; \
	grep -q 'DSM frame_start was not aligned to a 56-sample boundary' $(THERMO5_OUT)/axil_illegal_frame_seed420102.log; \
	grep -q 'THERMO5_AXIL_ILLEGAL_FRAME_OBSERVED' $(THERMO5_OUT)/axil_illegal_frame_seed420102.log; \
	grep -q 'THERMO5_AXIL_ILLEGAL_FRAME_UVM_PASS' $(THERMO5_OUT)/axil_illegal_frame_seed420102.log; \
	grep -q 'UVM_WARNING *: *0' $(THERMO5_OUT)/axil_illegal_frame_seed420102.log; \
	grep -q 'UVM_ERROR *: *0' $(THERMO5_OUT)/axil_illegal_frame_seed420102.log; \
	grep -q 'UVM_FATAL *: *0' $(THERMO5_OUT)/axil_illegal_frame_seed420102.log; \
	echo "Expected AXI-Lite negative assertion observed (simulator exit $$status)"

thermo5-axil-vcs-mailbox-negative:
	@test -x $(THERMO5_OUT)/simv || { echo "ERROR: run thermo5-vcs with THERMO5_USE_AXIL=1 first"; exit 2; }
	@set +e; cd $(ROOT) && $(THERMO5_OUT)/simv \
		+UVM_TESTNAME=thermo5_sku_axil_mailbox_fault_test \
		+VEC_DIR=$(THERMO5_VECTORS) +ntb_random_seed=420103 \
		$(THERMO5_COV_ARGS) -cm_dir $(THERMO5_OUT)/cov_axil_mailbox_fault_seed420103.vdb \
		-l $(THERMO5_OUT)/axil_mailbox_fault_seed420103.log; \
	status=$$?; set -e; \
	grep -q 'thermo5 DPD CDC mailbox changed before acknowledgement' $(THERMO5_OUT)/axil_mailbox_fault_seed420103.log; \
	grep -q 'THERMO5_AXIL_MAILBOX_CORRUPTION_OBSERVED' $(THERMO5_OUT)/axil_mailbox_fault_seed420103.log; \
	grep -q 'THERMO5_AXIL_MAILBOX_FAULT_UVM_PASS' $(THERMO5_OUT)/axil_mailbox_fault_seed420103.log; \
	grep -q 'UVM_WARNING *: *0' $(THERMO5_OUT)/axil_mailbox_fault_seed420103.log; \
	grep -q 'UVM_ERROR *: *0' $(THERMO5_OUT)/axil_mailbox_fault_seed420103.log; \
	grep -q 'UVM_FATAL *: *0' $(THERMO5_OUT)/axil_mailbox_fault_seed420103.log; \
	 echo "Expected mailbox fault assertion observed (simulator exit $$status)"

# Parameter guard is deliberately tested in a tiny negative top. It is not a
# legal runtime configuration and is reported separately from the frozen SKU.
thermo5-axil-vcs-parameter-guard:
	@mkdir -p $(THERMO5_OUT)/parameter_guard/csrc
	@cd $(ROOT) && $(VCS) -full64 -sverilog -timescale=1ns/1ps \
		$(THERMO5_COV_ARGS) -top thermo5_axil_parameter_guard_tb \
		-Mdir=$(THERMO5_OUT)/parameter_guard/csrc \
		rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv \
		dv/verif/block/axil/tb/thermo5_axil_parameter_guard_tb.sv \
		-o $(THERMO5_OUT)/parameter_guard/simv \
		-l $(THERMO5_OUT)/parameter_guard/compile.log
	@set +e; cd $(ROOT) && $(THERMO5_OUT)/parameter_guard/simv \
		$(THERMO5_COV_ARGS) -cm_dir $(THERMO5_OUT)/parameter_guard/guard.vdb \
		-l $(THERMO5_OUT)/parameter_guard/run.log; \
	status=$$?; set -e; \
	count=$$(grep -c 'MAX_TAPS must be in \[1,4\]' $(THERMO5_OUT)/parameter_guard/run.log || true); \
	test "$$count" = 2; \
	grep -q 'got 0' $(THERMO5_OUT)/parameter_guard/run.log; \
	grep -q 'got 5' $(THERMO5_OUT)/parameter_guard/run.log; \
	grep -q 'THERMO5_AXIL_PARAMETER_GUARD_TEST_COMPLETE' $(THERMO5_OUT)/parameter_guard/run.log; \
	echo "THERMO5_AXIL_PARAMETER_GUARD_PASS expected_errors=$$count simulator_exit=$$status"

# Standalone configuration-block coverage test for cycle-accurate line-315
# tuples during request/pending overlap and AXI-Lite-only reset. The integrated
# thermo5 SKU still uses the common reset assertion contract.
thermo5-axil-cfg-unit-vcs:
	@mkdir -p $(THERMO5_OUT)/cfg_coverage_unit/csrc
	@cd $(ROOT) && $(VCS) -full64 -sverilog -timescale=1ns/1ps \
		-cm line+cond+fsm+tgl+branch+assert -top thermo5_axil_cfg_coverage_tb \
		-Mdir=$(THERMO5_OUT)/cfg_coverage_unit/csrc \
		rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv \
		dv/verif/block/axil/tb/thermo5_axil_cfg_coverage_tb.sv \
		-o $(THERMO5_OUT)/cfg_coverage_unit/simv \
		-l $(THERMO5_OUT)/cfg_coverage_unit/compile.log
	@cd $(ROOT) && $(THERMO5_OUT)/cfg_coverage_unit/simv -no_save \
		-cm line+cond+fsm+tgl+branch+assert \
		-cm_dir $(THERMO5_OUT)/cfg_coverage_unit/simv.vdb \
		-l $(THERMO5_OUT)/cfg_coverage_unit/run.log
	@grep -Fq 'THERMO5_AXIL_CFG_RESET_WINDOW_COVERAGE_PASS' $(THERMO5_OUT)/cfg_coverage_unit/run.log

thermo5-axil-vcs-regression:
	@$(MAKE) --no-print-directory thermo5-vcs THERMO5_USE_AXIL=1
	@$(MAKE) --no-print-directory thermo5-vcs-run-only UVM_SEED=420100 \
		THERMO5_USE_AXIL=1 THERMO5_TESTNAME=thermo5_sku_axil_register_access_test
	@$(MAKE) --no-print-directory thermo5-vcs-run-only UVM_SEED=420101 \
		THERMO5_USE_AXIL=1 THERMO5_TESTNAME=thermo5_sku_axil_config_test \
		THERMO5_EXTRA_ARGS=+THERMO5_AXIL_INTERNAL_COVERAGE_PROBE
	@$(MAKE) --no-print-directory thermo5-vcs-run-only UVM_SEED=420108 \
		THERMO5_USE_AXIL=1 THERMO5_TESTNAME=thermo5_sku_axil_graceful_stop_test
	@$(MAKE) --no-print-directory thermo5-vcs-run-only UVM_SEED=420104 \
		THERMO5_USE_AXIL=1 THERMO5_TESTNAME=thermo5_sku_axil_coeff_transport_test
	@$(MAKE) --no-print-directory thermo5-vcs-run-only UVM_SEED=420105 \
		THERMO5_USE_AXIL=1 THERMO5_TESTNAME=thermo5_sku_axil_nonlinear_dpd_test
	@$(MAKE) --no-print-directory thermo5-vcs-run-only UVM_SEED=420106 \
		THERMO5_USE_AXIL=1 THERMO5_TESTNAME=thermo5_sku_axil_tap4_identity_test
	@$(MAKE) --no-print-directory thermo5-vcs-run-only UVM_SEED=420107 \
		THERMO5_USE_AXIL=1 THERMO5_TESTNAME=thermo5_sku_axil_boundary_phase_test
	@$(MAKE) --no-print-directory thermo5-axil-vcs-negative THERMO5_USE_AXIL=1
	@$(MAKE) --no-print-directory thermo5-axil-vcs-mailbox-negative THERMO5_USE_AXIL=1
	@$(MAKE) --no-print-directory thermo5-axil-vcs-parameter-guard THERMO5_USE_AXIL=1
	@$(URG) -full64 -dir $(THERMO5_OUT)/simv.vdb \
		$(THERMO5_OUT)/cov_thermo5_sku_axil_register_access_test_seed420100.vdb \
		$(THERMO5_OUT)/cov_thermo5_sku_axil_config_test_seed420101.vdb \
		$(THERMO5_OUT)/cov_thermo5_sku_axil_coeff_transport_test_seed420104.vdb \
		$(THERMO5_OUT)/cov_thermo5_sku_axil_nonlinear_dpd_test_seed420105.vdb \
		$(THERMO5_OUT)/cov_thermo5_sku_axil_tap4_identity_test_seed420106.vdb \
		$(THERMO5_OUT)/cov_thermo5_sku_axil_boundary_phase_test_seed420107.vdb \
		$(THERMO5_OUT)/cov_axil_illegal_frame_seed420102.vdb \
		$(THERMO5_OUT)/cov_axil_mailbox_fault_seed420103.vdb \
		-report $(THERMO5_OUT)/coverage -dbname thermo5_axil_merged \
		> $(THERMO5_OUT)/coverage_merge.log 2>&1
	@! grep -Eq 'Error-|Design Not Loaded' $(THERMO5_OUT)/coverage_merge.log || \
		{ echo "ERROR: AXI-Lite URG merge failed; inspect coverage_merge.log"; exit 1; }
	@echo "THERMO5_AXIL_COVERAGE_MERGE_PASS report=$(THERMO5_OUT)/coverage"

thermo5-axil-stop-restart-vcs-run:
	@$(PYTHON) $(ROOT)/dv/uvm/refmodel/python/generate_thermo5_frontend_vectors.py \
	  --output-dir $(THERMO5_STOP_RESTART_VECTORS) --words 112 --seed 610215 \
	  --interp-mode centered_cubic --frame-start-words 1,57 \
	  --frame-gains 16384,16384 --tidsm-order $(THERMO5_STOP_RESTART_TIDSM_ORDER) \
	  --step $(THERMO5_STOP_RESTART_STEP)
	@$(MAKE) --no-print-directory thermo5-vcs THERMO5_USE_AXIL=1 \
	  THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=$(THERMO5_STOP_RESTART_TIDSM_ORDER) \
	  THERMO5_STEP=$(THERMO5_STOP_RESTART_STEP) THERMO5_VECTORS=$(THERMO5_STOP_RESTART_VECTORS)
	@$(MAKE) --no-print-directory thermo5-vcs-run-only THERMO5_USE_AXIL=1 \
	  THERMO5_CENTERED_CUBIC=1 THERMO5_TESTNAME=thermo5_sku_axil_stop_restart_test \
	  THERMO5_TIDSM_ORDER=$(THERMO5_STOP_RESTART_TIDSM_ORDER) \
	  THERMO5_STEP=$(THERMO5_STOP_RESTART_STEP) \
	  THERMO5_VECTORS=$(THERMO5_STOP_RESTART_VECTORS) UVM_SEED=610215 \
	  THERMO5_EXTRA_ARGS='+CORE_WORDS=112 +PACKET_BEATS=32'

thermo5-vcs-regression: thermo5-vcs
	@$(MAKE) thermo5-vcs-run-only UVM_SEED=1 THERMO5_TESTNAME=thermo5_sku_bittrue_test THERMO5_EXTRA_ARGS=+STRESS_PA_READY
	@$(MAKE) thermo5-vcs-run-only UVM_SEED=2 THERMO5_TESTNAME=thermo5_sku_bubble_backpressure_test
	@$(MAKE) thermo5-vcs-run-only UVM_SEED=2 THERMO5_TESTNAME=thermo5_sku_fifo_boundary_test
	@$(MAKE) thermo5-vcs-run-only UVM_SEED=5 THERMO5_TESTNAME=thermo5_sku_fifo_empty_test
	@$(MAKE) thermo5-vcs-run-only UVM_SEED=3 THERMO5_TESTNAME=thermo5_sku_reset_test
	@$(MAKE) thermo5-vcs-run-only UVM_SEED=6 THERMO5_TESTNAME=thermo5_sku_reset_sweep_test
	@$(MAKE) thermo5-vcs-negative UVM_SEED=4

# Directed full-chain bit-true check for the centered-cubic FIR. The
# matching Python oracle vectors must be supplied through THERMO5_VECTORS.
thermo5-centered-cubic-vcs:
	@$(MAKE) --no-print-directory thermo5-vcs THERMO5_CENTERED_CUBIC=1
	@$(MAKE) --no-print-directory thermo5-vcs-run-only THERMO5_CENTERED_CUBIC=1 \
	  UVM_SEED=610201 THERMO5_TESTNAME=thermo5_sku_bittrue_test \
	  THERMO5_EXTRA_ARGS=+STRESS_PA_READY

# Full directed-IP suite for centered-cubic + fixed-point EF2. Matching oracle
# vectors are supplied by the caller.
thermo5-centered-cubic-ef2-vcs-regression:
	@$(MAKE) --no-print-directory thermo5-vcs-regression \
	  THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120
	@$(MAKE) --no-print-directory thermo5-axil-stop-restart-vcs-run \
	  THERMO5_STOP_RESTART_TIDSM_ORDER=2 THERMO5_STOP_RESTART_STEP=5120

# Repeatable long-frame EF2 qualification with independently hashed vectors,
# VCS logs, targeted URG bins, and a source/revision manifest.
THERMO5_EF2_RANDOM_VECTORS ?= $(ROOT)/runs/thermo5_ef2_qualification/random_vectors
THERMO5_EF2_SUSTAINED_VECTORS ?= $(ROOT)/runs/thermo5_ef2_qualification/sustained_vectors
THERMO5_EF2_EXTREME_VECTORS ?= $(ROOT)/runs/thermo5_ef2_qualification/extreme_vectors
thermo5-ef2-qualification:
	@$(PYTHON) $(ROOT)/dv/uvm/refmodel/python/generate_thermo5_frontend_vectors.py \
	  --output-dir $(THERMO5_EF2_SUSTAINED_VECTORS) --words 2072 --seed 271026 \
	  --profile random --interp-mode centered_cubic --tidsm-order 2 --step 5120 \
	  --frame-start-words 1 --frame-gains 16384
	@$(PYTHON) $(ROOT)/dv/uvm/refmodel/python/generate_thermo5_frontend_vectors.py \
	  --output-dir $(THERMO5_EF2_RANDOM_VECTORS) --words 2072 --seed 271027 \
	  --profile random --interp-mode centered_cubic --tidsm-order 2 --step 5120 \
	  --frame-start-words 1,687,1380 --frame-gains 16384,14336,12288
	@$(PYTHON) $(ROOT)/dv/uvm/refmodel/python/generate_thermo5_frontend_vectors.py \
	  --output-dir $(THERMO5_EF2_EXTREME_VECTORS) --words 2072 --seed 271028 \
	  --profile ef2_saturation --interp-mode centered_cubic --tidsm-order 2 --step 5120 \
	  --frame-start-words 1,687,1380 --frame-gains 16384,14336,12288
	@$(MAKE) --no-print-directory thermo5-vcs THERMO5_CENTERED_CUBIC=1 \
	  THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 THERMO5_VECTORS=$(THERMO5_EF2_SUSTAINED_VECTORS)
	@$(MAKE) --no-print-directory thermo5-vcs-run-only THERMO5_CENTERED_CUBIC=1 \
	  THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 THERMO5_VECTORS=$(THERMO5_EF2_SUSTAINED_VECTORS) \
	  THERMO5_TESTNAME=thermo5_sku_sustained_test UVM_SEED=271027 \
	  THERMO5_EXTRA_ARGS=+CORE_WORDS=2072
	@$(MAKE) --no-print-directory thermo5-vcs-run-only THERMO5_CENTERED_CUBIC=1 \
	  THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 THERMO5_VECTORS=$(THERMO5_EF2_EXTREME_VECTORS) \
	  THERMO5_TESTNAME=thermo5_sku_ef2_corner_test UVM_SEED=271028 \
	  THERMO5_EXTRA_ARGS=+CORE_WORDS=2072
	@$(MAKE) --no-print-directory thermo5-vcs-run-only THERMO5_CENTERED_CUBIC=1 \
	  THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 THERMO5_VECTORS=$(THERMO5_EF2_RANDOM_VECTORS) \
	  THERMO5_TESTNAME=thermo5_sku_long_counter_test UVM_SEED=271029 \
	  THERMO5_EXTRA_ARGS=+CORE_WORDS=2072
	@$(URG) -full64 -dir $(THERMO5_OUT)/simv.vdb \
	  $(THERMO5_OUT)/cov_thermo5_sku_sustained_test_seed271027.vdb \
	  $(THERMO5_OUT)/cov_thermo5_sku_ef2_corner_test_seed271028.vdb \
	  $(THERMO5_OUT)/cov_thermo5_sku_long_counter_test_seed271029.vdb \
	  -report $(THERMO5_OUT)/ef2_qualification_coverage -dbname thermo5_ef2_qualification \
	  > $(THERMO5_OUT)/ef2_qualification_coverage.log 2>&1
	@! grep -Eq 'Error-|Design Not Loaded' $(THERMO5_OUT)/ef2_qualification_coverage.log || \
	  { echo "ERROR: EF2 URG merge failed; inspect ef2_qualification_coverage.log"; exit 1; }
	@$(PYTHON) $(ROOT)/dv/uvm/sim/package_thermo5_ef2_qualification.py \
	  --repo-root $(ROOT) --run-dir $(THERMO5_OUT) \
	  --vectors $(THERMO5_EF2_SUSTAINED_VECTORS) \
	  $(THERMO5_EF2_RANDOM_VECTORS) $(THERMO5_EF2_EXTREME_VECTORS)
	@echo "THERMO5_EF2_QUALIFICATION_PASS report=$(THERMO5_OUT)/ef2_qualification_coverage"

# Exact look-ahead microarchitecture experiment. It is not selected by the
# product wrappers and must not replace the baseline before routed timing.
THERMO5_EF2_PAIR_OUT ?= $(ROOT)/runs/thermo5_ef2_pair_lookahead/vcs
thermo5-ef2-pair-vcs:
	@mkdir -p $(THERMO5_EF2_PAIR_OUT)/csrc
	@cd $(ROOT) && $(VCS) -full64 -sverilog -timescale=1ns/1ps \
	  -top tb_thermo5_ef2_pair_lookahead \
	  -Mdir=$(THERMO5_EF2_PAIR_OUT)/csrc \
	  rtl/gt/gt_tx_user_bridge.sv \
	  rtl/gt/gt_tx_raw64_boundary.sv \
	  rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv \
	  dv/verif/integration/thermo5_ef2_pair_lookahead/tb_thermo5_ef2_pair_lookahead.sv \
	  -o $(THERMO5_EF2_PAIR_OUT)/simv -l $(THERMO5_EF2_PAIR_OUT)/compile.log
	@cd $(THERMO5_EF2_PAIR_OUT) && ./simv -l sim.log
	@grep -Fq 'THERMO5_EF2_PAIR_LOOKAHEAD_PASS cycles=4096 seed=20261028' \
	  $(THERMO5_EF2_PAIR_OUT)/sim.log
	@echo "THERMO5_EF2_PAIR_LOOKAHEAD_PASS report=$(THERMO5_EF2_PAIR_OUT)/sim.log"

# Main-chain EF2 -> four independent raw64 serializer/deserializer models.
THERMO5_EF2_SERDES_DIR ?= $(ROOT)/runs/thermo5_ef2_serdes
thermo5-ef2-serdes-vcs:
	@mkdir -p $(THERMO5_EF2_SERDES_DIR)
	@$(PYTHON) $(ROOT)/dv/uvm/refmodel/python/generate_thermo5_frontend_vectors.py \
	  --output-dir $(THERMO5_EF2_SERDES_DIR) --words 56 --seed 20260918 \
	  --profile random --interp-mode centered_cubic --interp-taps 2 \
	  --tidsm-order 2 --step 5120 --frame-start-words 1,15,36 \
	  --frame-gains 16384,14336,12288
	@cd $(THERMO5_EF2_SERDES_DIR) && $(VCS) -full64 -sverilog \
	  -top tb_tid32_thermo5_frontend_serdes_loopback -o simv \
	  $(ROOT)/rtl/frontend/dsm_frame_gain_vector.sv \
	  $(ROOT)/rtl/gt/gt_tx_user_bridge.sv $(ROOT)/rtl/gt/gt_tx_raw64_boundary.sv \
	  $(ROOT)/rtl/dpd/dpd_poly.v $(ROOT)/rtl/dpd/dpd_memory_poly.v \
	  $(ROOT)/rtl/dpd/dpd_vector16_memory_poly.sv \
	  $(ROOT)/rtl/dpd/dpd_vector_elastic_buffer.sv \
	  $(ROOT)/rtl/interp/dsm_interp_x2_centered_cubic_vector.sv \
	  $(ROOT)/rtl/interp/dsm_interp_x2_polyphase_vector.sv \
	  $(ROOT)/rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv \
	  $(ROOT)/rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv \
	  $(ROOT)/rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv \
	  $(ROOT)/rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv \
	  $(ROOT)/dv/verif/models/raw64_serializer_loopback_model.sv \
	  $(ROOT)/dv/verif/integration/serializer_loopback/tb_tid32_thermo5_frontend_serdes_loopback.sv \
	  > compile.log 2>&1 || { cat $(THERMO5_EF2_SERDES_DIR)/compile.log; exit 1; }
	@cd $(THERMO5_EF2_SERDES_DIR) && ./simv -no_save > sim.log 2>&1 || \
	  { cat $(THERMO5_EF2_SERDES_DIR)/sim.log; exit 1; }
	@grep -Fq 'THERMO5_FOUR_PA_SERDES_LOOPBACK_PASS words=56 bits_per_path=3584' \
	  $(THERMO5_EF2_SERDES_DIR)/sim.log
	@echo "THERMO5_EF2_SERDES_PASS report=$(THERMO5_EF2_SERDES_DIR)/sim.log"

thermo5-gt-parent-link-fault-vcs:
	@command -v $(VCS) >/dev/null 2>&1 || { echo "ERROR: VCS not found"; exit 127; }
	@mkdir -p $(GT_PARENT_FAULT_OUT)
	@cd $(ROOT) && $(VCS) -full64 -sverilog -timescale=1ns/1ps \
	  -top tb_thermo5_gt_parent_link_fault -Mdir=$(GT_PARENT_FAULT_OUT)/csrc \
	  $(GT_PARENT_FAULT_SRCS) -o $(GT_PARENT_FAULT_OUT)/simv \
	  -l $(GT_PARENT_FAULT_OUT)/compile.log
	@cd $(GT_PARENT_FAULT_OUT) && ./simv -l run.log
	@grep -q THERMO5_GT_PARENT_LINK_FAULT_PASS $(GT_PARENT_FAULT_OUT)/run.log
	@echo "THERMO5_GT_PARENT_LINK_FAULT_PASS report=$(GT_PARENT_FAULT_OUT)/run.log"

thermo5-centered-cubic-low-power-vcs:
	@$(PYTHON) $(ROOT)/dv/uvm/refmodel/python/generate_thermo5_frontend_vectors.py \
	  --output-dir $(THERMO5_CENTERED_LP_VECTORS) --words 56 --seed 610212 \
	  --interp-mode centered_cubic --frame-start-words 1 --frame-gains 16384
	@$(MAKE) --no-print-directory thermo5-vcs THERMO5_CENTERED_CUBIC=1 THERMO5_LOW_POWER=1 \
	  THERMO5_VECTORS=$(THERMO5_CENTERED_LP_VECTORS)
	@$(MAKE) --no-print-directory thermo5-vcs-run-only THERMO5_CENTERED_CUBIC=1 THERMO5_LOW_POWER=1 \
	  THERMO5_VECTORS=$(THERMO5_CENTERED_LP_VECTORS) \
	  UVM_SEED=610212 THERMO5_TESTNAME=thermo5_sku_low_power_drain_test

thermo5-axil-centered-nonlinear-bittrue-vcs:
	@$(PYTHON) $(ROOT)/dv/uvm/refmodel/python/generate_thermo5_frontend_vectors.py \
	  --output-dir $(THERMO5_NONLINEAR_SHORT_VECTORS) --words 56 --seed 610213 \
	  --interp-mode centered_cubic --dpd-profile nonlinear_test \
	  --frame-start-words 1 --frame-gains 16384 \
	  --tidsm-order $(THERMO5_TIDSM_ORDER) --step $(THERMO5_STEP)
	@$(PYTHON) $(ROOT)/dv/uvm/refmodel/python/generate_thermo5_frontend_vectors.py \
	  --output-dir $(THERMO5_NONLINEAR_LONG_VECTORS) --words 112 --seed 610214 \
	  --interp-mode centered_cubic --dpd-profile nonlinear_test \
	  --frame-start-words 1,57 --frame-gains 16384,16384 \
	  --tidsm-order $(THERMO5_TIDSM_ORDER) --step $(THERMO5_STEP)
	@$(MAKE) --no-print-directory thermo5-vcs THERMO5_USE_AXIL=1 THERMO5_CENTERED_CUBIC=1 \
	  THERMO5_VECTORS=$(THERMO5_NONLINEAR_SHORT_VECTORS)
	@$(MAKE) --no-print-directory thermo5-vcs-run-only THERMO5_USE_AXIL=1 THERMO5_CENTERED_CUBIC=1 \
	  THERMO5_TESTNAME=thermo5_sku_axil_nonlinear_bittrue_test UVM_SEED=610213 \
	  THERMO5_VECTORS=$(THERMO5_NONLINEAR_SHORT_VECTORS) \
	  THERMO5_EXTRA_ARGS='+CORE_WORDS=56 +PACKET_BEATS=32'
	@$(MAKE) --no-print-directory thermo5-vcs-run-only THERMO5_USE_AXIL=1 THERMO5_CENTERED_CUBIC=1 \
	  THERMO5_TESTNAME=thermo5_sku_axil_nonlinear_bittrue_test UVM_SEED=610214 \
	  THERMO5_VECTORS=$(THERMO5_NONLINEAR_LONG_VECTORS) \
	  THERMO5_EXTRA_ARGS='+CORE_WORDS=112 +PACKET_BEATS=32'

thermo5-vcs-multiseed: thermo5-vcs
	@set -e; for seed in $(THERMO5_STRESS_SEEDS); do \
	  $(MAKE) --no-print-directory thermo5-vcs-run-only UVM_SEED=$$seed \
	    THERMO5_TESTNAME=thermo5_sku_bittrue_test THERMO5_EXTRA_ARGS=+STRESS_PA_READY \
	    THERMO5_COVERAGE=0 >/dev/null; \
	  $(MAKE) --no-print-directory thermo5-vcs-run-only UVM_SEED=$$seed \
	    THERMO5_TESTNAME=thermo5_sku_fifo_boundary_test THERMO5_COVERAGE=0 >/dev/null; \
	done
	@echo "THERMO5_MULTISEED_PASS seeds=$(THERMO5_STRESS_SEEDS) tests_per_seed=2"

thermo5-coverage-merge:
	@command -v $(URG) >/dev/null 2>&1 || { echo "ERROR: URG not found"; exit 127; }
	@test -d $(THERMO5_OUT)/simv.vdb || { echo "ERROR: compiled design VDB missing"; exit 2; }
	@test -d $(THERMO5_OUT)/cov_thermo5_sku_bittrue_test_seed1.vdb
	@test -d $(THERMO5_OUT)/cov_thermo5_sku_bubble_backpressure_test_seed2.vdb
	@test -d $(THERMO5_OUT)/cov_thermo5_sku_fifo_boundary_test_seed2.vdb
	@test -d $(THERMO5_OUT)/cov_thermo5_sku_fifo_empty_test_seed5.vdb
	@test -d $(THERMO5_OUT)/cov_thermo5_sku_reset_test_seed3.vdb
	@test -d $(THERMO5_OUT)/cov_thermo5_sku_reset_sweep_test_seed6.vdb
	@test -d $(THERMO5_OUT)/cov_illegal_frame_seed4.vdb
	@for vdb in $(THERMO5_URG_EXTRA_VDBS); do test -d "$$vdb" || { echo "ERROR: missing extra VDB $$vdb"; exit 2; }; done
	@$(URG) -full64 -dir $(THERMO5_OUT)/simv.vdb \
		$(THERMO5_OUT)/cov_thermo5_sku_bittrue_test_seed1.vdb \
		$(THERMO5_OUT)/cov_thermo5_sku_bubble_backpressure_test_seed2.vdb \
		$(THERMO5_OUT)/cov_thermo5_sku_fifo_boundary_test_seed2.vdb \
		$(THERMO5_OUT)/cov_thermo5_sku_fifo_empty_test_seed5.vdb \
		$(THERMO5_OUT)/cov_thermo5_sku_reset_test_seed3.vdb \
		$(THERMO5_OUT)/cov_thermo5_sku_reset_sweep_test_seed6.vdb \
		$(THERMO5_OUT)/cov_illegal_frame_seed4.vdb $(THERMO5_URG_EXTRA_VDBS) \
		-report $(THERMO5_OUT)/coverage -dbname thermo5_sku_merged \
		> $(THERMO5_OUT)/coverage_merge.log 2>&1
	@! grep -Eq 'Error-|Design Not Loaded' $(THERMO5_OUT)/coverage_merge.log || \
		{ echo "ERROR: URG reported an invalid merge; see coverage_merge.log"; exit 1; }
	@echo "THERMO5_COVERAGE_MERGE_PASS report=$(THERMO5_OUT)/coverage"

vcs-run-only:
	@test -x $(VCS_BIN) || { echo "ERROR: run 'make vcs' first"; exit 2; }
	@mkdir -p $(RUN_DIR)
	@cd $(ROOT) && $(VCS_BIN) $(UVM_ARGS) $(VCS_COV_RUN) $(VCS_FSDB_RUN) \
		$(VCS_RUN_ARGS) -l $(RUN_DIR)/run.log

regression:
	@$(PYTHON) $(UVM_ROOT)/sim/run_regression.py --sim vcs

coverage-merge:
	@mkdir -p $(VCS_OUT)/coverage
	@$(URG) -full64 -dir $(VCS_OUT)/simv.vdb $(foreach tag,$(RUN_TAGS),$(VCS_OUT)/runs/$(tag)/simv.vdb) \
		$(if $(URG_ELFILE),-elfile $(URG_ELFILE),) \
		-report $(VCS_OUT)/coverage -dbname dsm_uvm_merged

verdi:
	@test -f $(RUN_DIR)/waves.fsdb || \
		{ echo "ERROR: $(RUN_DIR)/waves.fsdb not found; rerun with FSDB=1"; exit 2; }
	@cd $(ROOT) && $(VERDI) -ssf $(RUN_DIR)/waves.fsdb -f $(FILELIST) &

questa:
	@mkdir -p $(QUESTA_OUT)
	@cd $(ROOT) && $(VLOG) -sv -mfcu \
		$(if $(UVM_HOME),+incdir+$(UVM_HOME)/src,) \
		$(if $(UVM_HOME),$(UVM_HOME)/src/uvm.sv,) \
		-f $(FILELIST) -l $(QUESTA_OUT)/compile.log

questa-run: questa questa-run-only

questa-run-only:
	@mkdir -p $(QUESTA_OUT)/runs/$(RUN_TAG)
	@cd $(ROOT) && $(VSIM) -c $(UVM_ARGS) dsm_uvm_tb \
		-do "run -all; quit -f" -l $(QUESTA_OUT)/runs/$(RUN_TAG)/run.log

run:
	@if [ "$(SIM)" = "vcs" ]; then $(MAKE) vcs-run; \
	elif [ "$(SIM)" = "questa" ]; then $(MAKE) questa-run; \
	else echo "ERROR: SIM must be vcs or questa"; exit 2; fi

clean:
	@rm -rf $(OUT)
