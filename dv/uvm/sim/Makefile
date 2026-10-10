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
THERMO5_FILELIST := $(UVM_ROOT)/sim/thermo5_sku_filelist.f
THERMO5_EXTRA_ARGS ?=
THERMO5_TESTNAME ?= thermo5_sku_bittrue_test
THERMO5_RUN_LOG := $(THERMO5_OUT)/$(THERMO5_TESTNAME)_seed$(UVM_SEED).log
THERMO5_COVERAGE ?= 1
THERMO5_COV_ARGS := $(if $(filter 1,$(THERMO5_COVERAGE)),-cm line+cond+fsm+tgl+branch+assert,)
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
        thermo5-vcs-run-only thermo5-vcs-regression thermo5-vcs-negative thermo5-coverage-merge thermo5-vcs-multiseed

help:
	@echo "Primary targets:"
	@echo "  make vcs                 Compile once with VCS"
	@echo "  make vcs-run             Compile and run one test/seed"
	@echo "  make regression          Run Python test/seed matrix"
	@echo "  make coverage-merge      Merge selected VCS coverage databases with URG"
	@echo "  make thermo5-vcs-run     Compile/run two-clock thermo5/2-tap/DPD1 subsystem"
	@echo "  make thermo5-vcs-regression  Run bittrue/reset/FIFO/negative-frame suite"
	@echo "  make thermo5-vcs-multiseed   Run ten seeds each of PA stalls and FIFO boundary"
	@echo "  make thermo5-vcs-regression THERMO5_FIFO_IMPL=xpm THERMO5_XPM_ROOT=<Vivado root>"
	@echo "  make thermo5-coverage-merge  Merge passing thermo5 VCS VDBs with URG"
	@echo "  make formal-check-tools  Probe the Linux EDA environment for a formal engine"
	@echo "  IP functional closure: ./dv/uvm/sim/run_ip_coverage_linux.sh"
	@echo "  PowerShell bridge: .\\dv\\uvm\\sim\\run_ip_coverage_bridge.ps1"
	@echo "  make verdi RUN_TAG=...   Open an FSDB generated with FSDB=1"
	@echo "Optional targets: questa-run, check-tools, clean"
	@echo "Variables: UVM_TESTNAME, UVM_SEED, RUN_TAGS, UVM_VERBOSITY, COVERAGE, FSDB, VERDI_HOME"
	@echo "Thermo5: UVM_SEED, THERMO5_EXTRA_ARGS=+STRESS_PA_READY"

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
	@test -f $(THERMO5_VECTORS)/tid32_thermo5_frontend_pa3.mem || { echo "ERROR: generate thermo5 MATLAB vectors first"; exit 2; }
	@mkdir -p $(THERMO5_OUT)
	@cd $(ROOT) && $(VCS) -full64 -sverilog -ntb_opts uvm +lint=TFIPC-L \
		-timescale=1ns/1ps -f $(THERMO5_FILELIST) $(THERMO5_XPM_ARGS) \
		-top thermo5_sku_uvm_tb -Mdir=$(THERMO5_OUT)/csrc \
		$(THERMO5_COV_ARGS) \
		-o $(THERMO5_OUT)/simv -l $(THERMO5_OUT)/compile.log

thermo5-vcs-run: thermo5-vcs thermo5-vcs-run-only

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

thermo5-vcs-regression: thermo5-vcs
	@$(MAKE) thermo5-vcs-run-only UVM_SEED=1 THERMO5_TESTNAME=thermo5_sku_bittrue_test THERMO5_EXTRA_ARGS=+STRESS_PA_READY
	@$(MAKE) thermo5-vcs-run-only UVM_SEED=2 THERMO5_TESTNAME=thermo5_sku_bubble_backpressure_test
	@$(MAKE) thermo5-vcs-run-only UVM_SEED=2 THERMO5_TESTNAME=thermo5_sku_fifo_boundary_test
	@$(MAKE) thermo5-vcs-run-only UVM_SEED=5 THERMO5_TESTNAME=thermo5_sku_fifo_empty_test
	@$(MAKE) thermo5-vcs-run-only UVM_SEED=3 THERMO5_TESTNAME=thermo5_sku_reset_test
	@$(MAKE) thermo5-vcs-run-only UVM_SEED=6 THERMO5_TESTNAME=thermo5_sku_reset_sweep_test
	@$(MAKE) thermo5-vcs-negative UVM_SEED=4

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
