function y = dsm_singlebit_model(x, alg)
% Convenience wrapper for verified single-bit DSM MATLAB models.
%
% This function maps project naming to p0_dsm_bittrue. The returned sequence
% is the native model output used by the existing bit-true flow.

  alg = lower(string(alg));
  alg = erase(alg, "dsm");
  switch alg
    case {"lp", "lp1"}
      key = "lp1";
    case {"lp2", "lpdsm2"}
      key = "lp2";
    case {"ef", "ef1"}
      key = "ef1";
    case {"ef2"}
      key = "ef2";
    case {"mash11", "mash111", "mash22"}
      key = alg;
    otherwise
      error('Unsupported single-bit DSM algorithm: %s', alg);
  end
  y = p0_dsm_bittrue(x, key);
end
