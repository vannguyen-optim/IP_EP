function cfg = validate_config(cfg)
%VALIDATE_CONFIG Reject invalid numerical and execution settings before a run.
cfg.profile=validatestring(cfg.profile,{'publication','smoke'});
assert(iscell(cfg.scopes) && ~isempty(cfg.scopes) && ...
    all(ismember(cfg.scopes,{'deterministic','ev'})),...
    'EP:Scopes','Scopes must be a nonempty cell array containing deterministic and/or ev.');
assert(numel(unique(cfg.scopes))==numel(cfg.scopes),'EP:Scopes','Scopes must be unique.');
validateattributes(cfg.base_seed,{'numeric'},{'real','scalar','integer','nonnegative','finite'});
validateattributes(cfg.n_starts,{'numeric'},{'real','scalar','integer','positive','finite'});
validateattributes(cfg.n_workers,{'numeric'},{'real','scalar','integer','positive','finite'});
validateattributes(cfg.max_iter_deterministic,{'numeric'},{'real','scalar','integer','nonnegative','finite'});
validateattributes(cfg.max_iter_ev,{'numeric'},{'real','scalar','integer','nonnegative','finite'});
positive={'tolerance','inner_tolerance','kkt_tolerance','residual_eta_over_gamma'};
for j=1:numel(positive)
    validateattributes(cfg.(positive{j}),{'numeric'},{'real','scalar','positive','finite'});
end
validateattributes(cfg.nonlinear_dimensions,{'numeric'},{'real','vector','integer','positive','finite','nonempty'});
validateattributes(cfg.nonlinear_conditioning,{'numeric'},{'real','vector','integer','finite','>=',1,'nonempty'});
cfg.nonlinear_dimensions=cfg.nonlinear_dimensions(:)';
cfg.nonlinear_conditioning=cfg.nonlinear_conditioning(:)';
validateattributes(cfg.ev.n_slots,{'numeric'},{'real','scalar','integer','positive','finite'});
validateattributes(cfg.ev.dt_hours,{'numeric'},{'real','scalar','positive','finite'});
validateattributes(cfg.ev.power_cap_kw,{'numeric'},{'real','scalar','positive','finite'});
assert(abs(cfg.ev.n_slots*cfg.ev.dt_hours-24)<=1e-10,...
    'EP:Slots','The slot count and slot length must describe one 24-hour day.');
if strcmp(cfg.profile,'publication')
    assert(~cfg.synthetic_ev_for_smoke,'EP:Data','Publication runs cannot use synthetic EV data.');
end
ep.methods(cfg); % Validate every inertial and extragradient parameter.
end
