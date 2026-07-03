function x = lp_read_coe_int16_hex(filename)
% lp_read_coe_int16_hex Read int16 sequence from Xilinx COE (hex vector)
txt = fileread(filename);
k = strfind(lower(txt), 'memory_initialization_vector');
if isempty(k), error('No memory_initialization_vector in %s', filename); end
s = txt(k(1):end);
eqpos = strfind(s, '=');
if isempty(eqpos), error('Malformed .coe: no "="'); end
s = s(eqpos(1)+1:end);
s = regexprep(s, '\s+', '');
tokens = regexp(s, '[0-9A-Fa-f]{1,8}', 'match');
if isempty(tokens), error('No hex tokens'); end
u = uint16(hex2dec(tokens(:)));
x = typecast(u, 'int16');
x = x(:);
end
