VCS ?= vcs
SIMV := build/simv
VCS_FLAGS := -full64 -sverilog -timescale=1ns/1ps -Mdir=build/csrc

.PHONY: all compile run clean

all: run

compile:
	@mkdir -p build
	$(VCS) $(VCS_FLAGS) -f filelist.f -o $(SIMV)

run: compile
	./$(SIMV) +ntb_random_seed=20260904

clean:
	rm -rf build
