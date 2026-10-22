function cfg = EP_CONFIG(profile)
%EP_CONFIG Reproducible parameters for the accompanying equilibrium paper.
%   cfg = EP_CONFIG('publication'); cfg = EP_CONFIG('smoke');
if nargin < 1, profile = 'publication'; end
root = fileparts(mfilename('fullpath'));
cfg.code_version = 'EP-2026-10-22-v1.1.1';
cfg.source_fingerprint = '';
cfg.profile = lower(char(profile));
cfg.base_seed = 2026;
cfg.alpha = [0, 0.10, 0.20, 0.25];
cfg.include_fast_noninertial = true;
cfg.lambda_over_gamma = 0.5;
cfg.fast_lambda_over_gamma = 1.8;
cfg.include_eg = true;
cfg.eg_step_over_gamma = 0.9;
cfg.include_scaled_inertial = true;
cfg.scaled_alpha = [0.10, 0.20, 0.25];
cfg.scaled_step_fraction = 0.9;
cfg.residual_eta_over_gamma = 1;
cfg.tolerance = 1e-5;
cfg.inner_tolerance = 1e-12;
cfg.kkt_tolerance = 1e-9;
cfg.max_iter_deterministic = 50000;
cfg.max_iter_ev = 10000;
cfg.n_starts = 30;
cfg.nonlinear_dimensions = [100,1000];
cfg.nonlinear_conditioning = [1,100];
cfg.scopes = {'deterministic','ev'};
cfg.parallel = false;
cfg.n_workers = 12;
cfg.reuse_checkpoints = true;
cfg.export_figures = true;
cfg.export_tables = true;
cfg.figure_visible = 'off';
cfg.data_file = fullfile(root,'data','acn_caltech_may2019.mat');
cfg.acn_source_file = fullfile(root,'data','caltech_may2019.json');
cfg.output_dir = fullfile(root,['results_',cfg.profile]);
cfg.synthetic_ev_for_smoke = false;
cfg.ev.dt_hours = 0.25;
cfg.ev.n_slots = 96;
cfg.ev.power_cap_kw = 7.2;
cfg.ev.timezone = 'America/Los_Angeles';
cfg.ev.first_day = '2019-05-01';
cfg.ev.end_day_exclusive = '2019-06-01';
switch lower(char(profile))
    case 'publication'
    case 'smoke'
        cfg.n_starts = 2;
        cfg.nonlinear_dimensions = [10,100];
        cfg.max_iter_deterministic = 200;
        cfg.max_iter_ev = 200;
        cfg.synthetic_ev_for_smoke = true;
    otherwise
        error('EP:Profile','Unknown profile: %s.',char(profile));
end
end
