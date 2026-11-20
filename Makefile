# Workspace housekeeping; simulation targets remain in dv/uvm/sim/Makefile.
ifeq ($(OS),Windows_NT)
PYTHON ?= python
else
PYTHON ?= python3
endif

.PHONY: clean clean-preview
clean:
	$(PYTHON) tools/eda/clean_workspace.py --apply

clean-preview:
	$(PYTHON) tools/eda/clean_workspace.py
