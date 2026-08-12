function result = compare_python_bp_ef2_reference(csv_path)
%COMPARE_PYTHON_BP_EF2_REFERENCE Check Python integer and MATLAB fixed models.

  if nargin < 1 || isempty(csv_path)
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(fileparts(here));
    csv_path = fullfile(repo, 'uvm_verif', 'refmodel', 'python', 'out', ...
      'bp_ef2_equivalence.csv');
  end

  input = readtable(csv_path);
  if_sample = int64(input.if_q15);
  [registered, core] = bp_ef2_fs4_model(if_sample);
  registered_mismatch = int64(registered ~= int64(input.python_registered_bit));
  core_mismatch = int64(core ~= int64(input.python_core_bit));

  result = table(height(input), sum(registered_mismatch), sum(core_mismatch), ...
    'VariableNames', {'samples', 'registered_mismatch', 'core_mismatch'});
  disp(result);
  assert(result.registered_mismatch == 0, ...
    'Python and MATLAB registered traces differ.');
  assert(result.core_mismatch == 0, ...
    'Python and MATLAB core traces differ.');
end
