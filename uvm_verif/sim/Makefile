# Primary Linux regression flow for VCS/Verdi. Questa remains available for
# portability, while Windows XSim is an optional smoke-only path.

SHELL := /bin/bash
ROOT := $(abspath $(CURDIR)/../..)
UVM_ROOT := $(ROOT)/uvm_verif
FILELIST := $(UVM_ROOT)/sim/uvm_filelist.f
OUT := $(UVM_ROOT)/sim/out

SIM ?= vcs
VCS ?= vcs
URG ?= urg
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
COVERAGE ?= 1
FSDB ?= 0

VCS_OUT := $(OUT)/vcs
VCS_BIN := $(VCS_OUT)/simv
VCS_LOG := $(VCS_OUT)/compile.log
RUN_DIR := $(VCS_OUT)/runs/$(RUN_TAG)
QUESTA_OUT := $(OUT)/questa

VCS_COV_COMPILE := $(if $(filter 1,$(COVERAGE)),-cm line+cond+fsm+tgl+branch+assert,)
VCS_COV_RUN := $(if $(filter 1,$(COVERAGE)),-cm line+cond+fsm+tgl+branch+assert -cm_dir $(RUN_DIR)/simv.vdb,)
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

.PHONY: help check-tools vcs vcs-run vcs-run-only regression coverage-merge \
        verdi questa questa-run questa-run-only run clean

help:
	@echo "Primary targets:"
	@echo "  make vcs                 Compile once with VCS"
	@echo "  make vcs-run             Compile and run one test/seed"
	@echo "  make regression          Run Python test/seed matrix"
	@echo "  make coverage-merge      Merge selected VCS coverage databases with URG"
	@echo "  PowerShell bridge: .\\uvm_verif\\sim\\run_control_coverage_bridge.ps1"
	@echo "  make verdi RUN_TAG=...   Open an FSDB generated with FSDB=1"
	@echo "Optional targets: questa-run, check-tools, clean"
	@echo "Variables: UVM_TESTNAME, UVM_SEED, RUN_TAGS, UVM_VERBOSITY, COVERAGE, FSDB, VERDI_HOME"

check-tools:
	@command -v $(VCS) >/dev/null 2>&1 || { echo "ERROR: VCS not found"; exit 127; }
	@command -v $(PYTHON) >/dev/null 2>&1 || { echo "ERROR: $(PYTHON) not found"; exit 127; }
	@echo "VCS:   $$(command -v $(VCS))"
	@echo "Python: $$(command -v $(PYTHON))"
	@echo "Verdi: $$(command -v $(VERDI) 2>/dev/null || echo NOT_FOUND)"

vcs:
	@mkdir -p $(VCS_OUT)
	@$(PYTHON) $(UVM_ROOT)/refmodel/python/generate_performance_sku_vectors.py
	@cd $(ROOT) && $(VCS) -full64 -sverilog -ntb_opts uvm \
		-timescale=1ns/1ps -f $(FILELIST) -Mdir=$(VCS_OUT)/csrc \
		-kdb -debug_access+all $(VCS_COV_COMPILE) $(VCS_FSDB_COMPILE) \
		-o $(VCS_BIN) -l $(VCS_LOG)

vcs-run: vcs vcs-run-only

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
