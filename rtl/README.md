# RTL Map

- `dsm/singlebit/`: scalar one-bit low-pass LP/EF/MASH cores.
- `dsm/multibit/`: scalar multi-bit generic core and algorithm wrappers.
- `top/p0_top_*.v`: I/Q regression carriers around the scalar cores.
- `duc/` and `mem/`: Fs/4 and ROM dependencies for those carriers.

The P0 carriers are test/measurement wrappers. The algorithm boundary is the
core under `rtl/dsm/`; it has no streaming bus or transmitter integration.
