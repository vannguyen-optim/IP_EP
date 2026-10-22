function root = EP_SETUP()
%EP_SETUP Add the package directory to MATLAB's path.
root = fileparts(mfilename('fullpath'));
addpath(root);
fprintf('EP package: %s\nMATLAB: %s\n',root,version);
end
