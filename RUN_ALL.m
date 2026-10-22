function RUN_ALL()
%RUN_ALL Run checks and the complete publication experiment from a fresh copy.
%   Set MATLAB's Current Folder to this package directory, then run RUN_ALL.
%   The bundled charging data are imported automatically. Results and figures
%   are written under results_publication. Compatible completed runs resume.
ep_package_root=fileparts(mfilename('fullpath'));
addpath(ep_package_root);
EP_SETUP();
fprintf('\n[1/2] Running mathematical, solver, data and export checks...\n');
EP_RUN_CHECKS();
fprintf('\n[2/2] Running or resuming the complete publication experiment...\n');
cfg=EP_CONFIG('publication');
EP_RUN_PUBLICATION(cfg);
fprintf('\nThe scheduled run and export procedure has finished.\n');
fprintf('Results folder: %s\n',cfg.output_dir);
fprintf('Review the status summary above and all_runs.csv for individual outcomes.\n');
fprintf('Use EP_STATUS to inspect completion, or RUN_ALL to resume.\n');
end
