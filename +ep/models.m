function [problems,data_status,data_snapshot] = models(cfg)
%MODELS Fixed mathematical models and imported, actually observed ACN days.
problems={}; data_status='not_requested'; data_snapshot=struct();
if any(strcmp(cfg.scopes,'deterministic'))
    if isfield(cfg,'nonlinear_conditioning')
        conditioning=cfg.nonlinear_conditioning(:)';
    else
        conditioning=1;
    end
    assert(~isempty(conditioning) && all(isfinite(conditioning) &...
        conditioning>=1 & conditioning==round(conditioning)),...
        'EP:Conditioning','Nonlinear condition numbers must be positive integers.');
    for n=cfg.nonlinear_dimensions(:)'
        for kappa=conditioning
            a=logspace(log10(1/kappa),0,n)'; amax=max(a);
            p=struct('id',sprintf('nonlinear_%d_k%d',n,kappa),...
                'name',sprintf('Nonlinear EP (n=%d, kappa=%d)',n,kappa),...
                'type','nonlinear','n',n,'a',a,'kappa',kappa,...
                'gamma',1/amax,'L',amax,'algorithm',1,...
                'reference',zeros(n,1),'reference_kkt',0,'data_source','specified model',...
                'max_iter',cfg.max_iter_deterministic,'n_trials',cfg.n_starts);
            p.signature=struct('type',p.type,'n',n,'a',a,'kappa',kappa);
            problems{end+1}=p; %#ok<AGROW>
        end
    end
    p=struct('id','electricity','name','Electricity','type','electricity',...
        'n',6,'algorithm',3,'max_iter',cfg.max_iter_deterministic,...
        'n_trials',cfg.n_starts,'data_source','specified deterministic coefficients');
    p.lower=zeros(6,1); p.upper=[80;80;50;55;30;40];
    p.hat_alpha=[.04;.03;.125;.0116;.05;.05];
    p.hat_beta=[2;1.75;1;3.25;3;3];
    p.tilde_gamma=[25;28.5714;8;86.2069;20;20];
    p.kappa=max(p.hat_alpha,1./p.tilde_gamma);
    membership=[1 0 0 0 0 0;0 1 1 0 0 0;0 0 0 1 1 1];
    p.H=2*ones(6)+2*(membership'*membership)+diag(p.kappa);
    p.linear=p.hat_beta-378.4;
    p.L=max(eig(p.H)); p.gamma=1/p.L;
    p.A=[-eye(6);eye(6)]; p.b=[-p.lower;p.upper];
    [p.reference,p.reference_kkt]=reference(p,cfg);
    p.signature=struct('H',p.H,'linear',p.linear,'A',p.A,'b',p.b);
    problems{end+1}=p;
    p=struct('id','quadratic','name','Quadratic EP','type','quadratic',...
        'n',5,'algorithm',1,'max_iter',cfg.max_iter_deterministic,...
        'n_trials',cfg.n_starts,'data_source','specified deterministic coefficients');
    p.P=[3.1 2 0 0 0;2 3.6 0 0 0;0 0 3.5 2 0;0 0 2 3.3 0;0 0 0 0 3];
    p.Q=[1.6 1 0 0 0;1 1.6 0 0 0;0 0 1.5 1 0;0 0 1 1.5 0;0 0 0 0 2];
    p.M=p.P-p.Q; p.H=p.P+p.Q; p.linear=[1;-2;-1;2;-1];
    assert(min(eig(p.M))>0 && min(eig(p.Q))>=0);
    p.L=max(eig(p.M)); p.gamma=1/p.L;
    p.A=[-ones(1,5);-eye(5);eye(5)]; p.b=[0;5*ones(10,1)];
    [p.reference,p.reference_kkt]=reference(p,cfg);
    p.signature=struct('P',p.P,'Q',p.Q,'linear',p.linear,'A',p.A,'b',p.b);
    problems{end+1}=p;
    p=struct('id','river','name','River basin','type','river',...
        'n',3,'algorithm',3,'max_iter',cfg.max_iter_deterministic,...
        'n_trials',cfg.n_starts,'data_source','specified deterministic coefficients');
    p.P=[.02 .01 .01;.01 .06 .01;.01 .01 .02];
    p.Q=diag([.02,.06,.02]); p.H=p.P+p.Q; p.linear=[-2.9;-2.88;-2.85];
    p.A=[-eye(3);3.25 1.25 4.125;2.29 1.5625 2.8125];
    p.b=[0;0;0;100;100];
    p.L=max(eig(p.H)); p.gamma=1/p.L;
    [p.reference,p.reference_kkt]=reference(p,cfg);
    p.signature=struct('H',p.H,'linear',p.linear,'A',p.A,'b',p.b);
    problems{end+1}=p;
end
if any(strcmp(cfg.scopes,'ev'))
    if cfg.synthetic_ev_for_smoke
        assert(strcmp(cfg.profile,'smoke'),'EP:Synthetic','Synthetic EV is restricted to smoke.');
        days=ep.synthetic_ev(cfg); data_status='synthetic_software_check_only';
    elseif isfile(cfg.data_file)
        raw=load(cfg.data_file,'days','provenance','audit');
        assert(isfield(raw,'days') && isfield(raw,'provenance') && isfield(raw,'audit'),...
            'EP:Data','Use EP_IMPORT_ACN to prepare the charging data.');
        assert(strcmp(raw.provenance.source_kind,'ACN-Data'),...
            'EP:DataSource','Publication EV inputs must be actual ACN-Data sessions.');
        assert(isequal(raw.provenance.preprocessing,cfg.ev),...
            'EP:DataProtocol','Re-import ACN data with the current EV preprocessing parameters.');
        days=raw.days; data_status='ACN-Data_imported';
        assert(iscell(days) && ~isempty(days),...
            'EP:EmptyData','The requested publication EV data contain no retained days.');
        data_snapshot=struct('audit',raw.audit,'provenance',raw.provenance,...
            'data_file',cfg.data_file);
    else
        error('EP:MissingData',...
            'Requested EV inputs are missing. Run EP_IMPORT_ACN before publication experiments.');
    end
    for k=1:numel(days)
        d=days{k}; p=struct('id',['ev_',strrep(d.date,'-','')],...
            'name',['EV ',d.date],'type','ev','n',size(d.mask,1)*cfg.ev.n_slots,...
            'algorithm',3,'max_iter',cfg.max_iter_ev,'n_trials',1,...
            'data_source',d.source_kind,'date',d.date,'N',size(d.mask,1),...
            'dt',cfg.ev.dt_hours,'energy',d.energy(:),'session_ids',{d.session_ids});
        p.upper=cfg.ev.power_cap_kw*double(d.mask); p.target=p.energy/p.dt;
        p.L=p.N; p.gamma=1/p.L; p.reference=[]; p.reference_kkt=NaN;
        p.signature=struct('source',d.source_kind,'date',d.date,'mask',d.mask,...
            'energy',d.energy,'dt',p.dt,'power_cap_kw',cfg.ev.power_cap_kw,...
            'session_ids',{d.session_ids});
        problems{end+1}=p;
    end
end
end

function [x,kkt] = reference(p,cfg)
plan=ep.qp_plan(p.H,p.A,p.b,cfg.inner_tolerance);
[x,s]=ep.qp_solve(plan,-p.linear,1); kkt=s.kkt;
assert(kkt<=cfg.kkt_tolerance,'EP:Reference','Reference QP certificate failed.');
end
