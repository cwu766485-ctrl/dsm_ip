function T = run_dsm_multibit_smoke()
% Smoke-test all exploratory multibit DSM models.

  rng(3);
  n = 4096;
  t = (0:n-1).';
  x = 0.35*sin(2*pi*0.013*t) + 0.20*sin(2*pi*0.047*t + 0.3);
  xq15 = int64(round(x * 32767));
  algs = ["lp1","lp2","ef1","ef2","mash11","mash111","mash22"];
  rows = cell(numel(algs), 1);
  for k = 1:numel(algs)
    y = dsm_multibit_model(xq15, algs(k), 4);
    rows{k} = {algs(k), 4, min(y), max(y), numel(unique(y)), max(abs(y))};
  end
  T = cell2table(vertcat(rows{:}), 'VariableNames', ...
      {'algorithm','nbits','min_code','max_code','num_levels_seen','max_abs_code'});
end
