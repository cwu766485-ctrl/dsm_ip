// Common TB helpers for P0 wrappers.

localparam int W       = 16;
localparam int ADDR_W  = 16;
localparam int DEPTH   = 65536;

`ifdef TB_NSAMPLES
  localparam int N_SAMPLES = `TB_NSAMPLES;
`else
  localparam int N_SAMPLES = DEPTH;
`endif

`ifdef TB_MAX_CYCLES
  localparam int MAX_CYCLES = `TB_MAX_CYCLES;
`else
  localparam int MAX_CYCLES = (N_SAMPLES * 5) + 10000;
`endif

function automatic string plusarg_or_default(string key, string def);
  string v;
  if ($value$plusargs({key,"=%s"}, v)) plusarg_or_default = v;
  else plusarg_or_default = def;
endfunction

