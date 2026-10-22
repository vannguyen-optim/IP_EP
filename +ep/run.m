function manifest = run(cfg)
%RUN Assemble experiments, checkpoint every run, and export completed results.
cfg=ep.validate_config(cfg);
cfg.source_fingerprint=ep.code_fingerprint();
if any(strcmp(cfg.scopes,'ev')) && ~cfg.synthetic_ev_for_smoke && ~isfile(cfg.data_file)
    assert(isfield(cfg,'acn_source_file') && isfile(cfg.acn_source_file),...
        'EP:MissingData','Real EV input is missing. Import ACN data before requesting the EV scope.');
    EP_IMPORT_ACN(cfg.acn_source_file,cfg.data_file,cfg);
end
if ~isfolder(cfg.output_dir), mkdir(cfg.output_dir); end
if ~isfolder(fullfile(cfg.output_dir,'checkpoints')), mkdir(fullfile(cfg.output_dir,'checkpoints')); end
if cfg.parallel
    assert(license('test','Distrib_Computing_Toolbox'),...
        'EP:Parallel','Parallel mode requires Parallel Computing Toolbox.');
    pool=gcp('nocreate');
    if isempty(pool), pool=parpool('Processes',cfg.n_workers); end
    cfg.n_workers=pool.NumWorkers;
end
methods=ep.methods(cfg);
[problems,data_status,data_snapshot]=ep.models(cfg);
model_ids=cellfun(@(p)p.id,problems,'UniformOutput',false);
assert(~isempty(model_ids) && numel(unique(model_ids))==numel(model_ids),...
    'EP:Models','The requested model identifiers must be nonempty and unique.');
jobs=struct('problem',{},'trial',{},'seed',{});
for i=1:numel(problems)
    p=problems{i};
    % A model-specific offset is independent of the presence of other models.
    offset=sum(double(p.id).*(1:numel(p.id)))*1000;
    for trial=1:p.n_trials
        assert(cfg.base_seed+offset+trial+777<=2^32-1,...
            'EP:Seed','The base seed is too large for the model-specific random streams.');
        jobs(end+1)=struct('problem',i,'trial',trial,...
            'seed',cfg.base_seed+offset+trial); %#ok<AGROW>
    end
end
expected={}; expected_signatures={};
for j=1:numel(jobs)
    p=problems{jobs(j).problem};
    for m=1:numel(methods)
        expected{end+1}=sprintf('%s_r%03d_%s',p.id,jobs(j).trial,methods(m).key); %#ok<AGROW>
        expected_signatures{end+1}=ep.signature(p,methods(m),cfg,jobs(j).seed); %#ok<AGROW>
    end
end
manifest=struct('cfg',cfg,'methods',methods,'data_status',data_status,...
    'expected_keys',{expected},'expected_signatures',{expected_signatures},...
    'created_utc',char(datetime('now','TimeZone','UTC')),...
    'matlab_version',version,'computer',computer,'number_of_pairs',numel(jobs));
manifest.model_ids=model_ids;
manifest.data_snapshot=data_snapshot;
manifest.environment=ep.environment();
manifest.source_fingerprint=cfg.source_fingerprint;
ep.atomic_save(fullfile(cfg.output_dir,'manifest.mat'),struct('manifest',manifest));
fprintf('%d paired instances; %d methods; %d total runs.\n',numel(jobs),numel(methods),numel(expected));
if cfg.parallel
    parfor j=1:numel(jobs)
        job=jobs(j); ep.run_pair(problems{job.problem},job.trial,job.seed,methods,cfg);
    end
else
    for j=1:numel(jobs)
        job=jobs(j); ep.run_pair(problems{job.problem},job.trial,job.seed,methods,cfg);
    end
end
EP_EXPORT(cfg.output_dir);
EP_STATUS(cfg.output_dir);
end
