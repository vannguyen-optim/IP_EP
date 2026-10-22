function run_pair(p,trial,seed,methods,cfg)
%RUN_PAIR A reproducible paired initial point, with randomized method order.
x0=ep.initial_point(p,seed,cfg);
rng(seed+777,'twister'); order=randperm(numel(methods));
for pos=1:numel(order)
    method=methods(order(pos));
    key=sprintf('%s_r%03d_%s',p.id,trial,method.key);
    path=fullfile(cfg.output_dir,'checkpoints',[key,'.mat']);
    signature=ep.signature(p,method,cfg,seed);
    if cfg.reuse_checkpoints && isfile(path)
        old=load(path,'signature','result');
        if isfield(old,'signature') && strcmp(old.signature,signature) && ...
                isfield(old,'result') && ~strcmp(old.result.status,'solver_error')
            fprintf('Reused %s\n',key); continue;
        end
    end
    meta=struct('key',key,'model_id',p.id,'model_name',p.name,'model_type',p.type,...
        'method_key',method.key,'method_name',method.name,'matched_step',method.matched_step,...
        'method_kind',method.kind,'main_method',method.main,...
        'trial',trial,'seed',seed,'method_order',pos,'data_source',p.data_source,...
        'n',p.n,'max_iter',p.max_iter,'tolerance',cfg.tolerance,...
        'reference',p.reference,'reference_kkt',p.reference_kkt,...
        'matlab_version',version,'computer',computer,'parallel',cfg.parallel,...
        'code_version',cfg.code_version,'source_fingerprint',cfg.source_fingerprint);
    if strcmp(p.type,'ev')
        meta.N=p.N; meta.date=p.date; meta.energy=p.energy;
        meta.dt=p.dt; meta.power_cap_kw=cfg.ev.power_cap_kw;
    end
    try
        result=ep.run_one(p,x0,method,cfg);
    catch err
        result=struct('status','solver_error','message',err.message,...
            'identifier',err.identifier,'stack',err.stack);
    end
    ep.atomic_save(path,struct('signature',signature,'meta',meta,'result',result));
    if strcmp(result.status,'solver_error')
        fprintf('%s: %s\n',key,result.message);
    else
        fprintf('%s: %s, %d iterations, R=%.3e, %.3f s\n',...
            key,result.status,result.iterations,result.residual,result.time_seconds);
    end
end
end
