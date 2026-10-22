function value = json_field(s,name,default)
%JSON_FIELD Read original or MATLAB-normalized JSON object keys.
if nargin<3, default=[]; end
if isstruct(s) && isscalar(s)
    if isfield(s,name), value=s.(name); return; end
    key=matlab.lang.makeValidName(name);
    if isfield(s,key), value=s.(key); return; end
end
value=default;
end
