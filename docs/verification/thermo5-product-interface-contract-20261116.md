# Product Interface Contract

The current Thermo5 product remains four equal-weight PA planes and is not
replaced by the independent two-PA 1:2 Weighted MASH candidate. Weighted MASH
currently accepts one 32-lane vector per cycle (`II=1`), has a documented
35-word internal alignment and no downstream ready/valid or STOP input. A
product wrapper must define output buffering, clock-domain ownership, reset
flush semantics, physical PA weights and parent input/output timing budgets
before integration.
