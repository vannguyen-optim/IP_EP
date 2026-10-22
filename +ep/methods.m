function methods = methods(cfg)
%METHODS Shared-step, larger-step, extragradient, and scaled-step methods.
%   step_ratio is lambda/gamma for inertial methods and beta/gamma for EG.
alphas=cfg.alpha(:)';
assert(~isempty(alphas) && all(isfinite(alphas) & alphas>=0 & alphas<1/3),...
    'EP:Parameters','Inertial parameters must be finite and in [0,1/3).');
template=struct('key','','name','','alpha',0,'step_ratio',0,...
    'matched_step',false,'kind','inertial','main',true);
methods=repmat(template,1,numel(alphas));
for j=1:numel(alphas)
    a=alphas(j);
    if a==0
        key='nm'; name='NM';
    else
        key=sprintf('i%03d',round(100*a)); name=sprintf('I-%.2f',a);
    end
    methods(j)=struct('key',key,'name',name,'alpha',a,...
        'step_ratio',cfg.lambda_over_gamma,'matched_step',true,...
        'kind','inertial','main',true);
end
if cfg.include_fast_noninertial
    methods(end+1)=struct('key','nm_fast','name','NM-fast','alpha',0,...
        'step_ratio',cfg.fast_lambda_over_gamma,'matched_step',false,...
        'kind','inertial','main',true);
end
if isfield(cfg,'include_eg') && cfg.include_eg
    methods(end+1)=struct('key','eg','name','EG','alpha',0,...
        'step_ratio',cfg.eg_step_over_gamma,'matched_step',false,...
        'kind','eg','main',true);
end
if isfield(cfg,'include_scaled_inertial') && cfg.include_scaled_inertial
    scaled=cfg.scaled_alpha(:)';
    fraction=cfg.scaled_step_fraction;
    assert(isscalar(fraction) && isfinite(fraction) && fraction>0 && fraction<1,...
        'EP:Parameters','The scaled-step fraction must lie strictly between zero and one.');
    assert(~isempty(scaled) && all(isfinite(scaled) & scaled>=0 & scaled<1/3),...
        'EP:Parameters','Scaled inertial parameters must be finite and in [0,1/3).');
    for a=scaled
        ratio=fraction*2*(1-3*a)/(1-a)^2;
        methods(end+1)=struct('key',sprintf('is%03d',round(100*a)),...
            'name',sprintf('IS-%.2f',a),'alpha',a,'step_ratio',ratio,...
            'matched_step',false,'kind','inertial','main',false); %#ok<AGROW>
    end
end
for j=1:numel(methods)
    ratio=methods(j).step_ratio; a=methods(j).alpha;
    assert(isscalar(ratio) && isfinite(ratio) && ratio>0,...
        'EP:Parameters','Every step ratio must be finite and positive.');
    if strcmp(methods(j).kind,'eg')
        assert(ratio<1,'EP:Parameters','The EG step ratio must be less than one.');
    else
        q=1-ratio/2; mu=q*(1-a)^2-a*(1+a);
        assert(a>=0 && a<1/3 && q>0 && mu>0,...
            'EP:Parameters','Parameters violate the proved inertial bound.');
    end
end
assert(numel(unique({methods.key}))==numel(methods),...
    'EP:Parameters','Method keys must be unique; use distinct parameters at two-decimal precision.');
end
