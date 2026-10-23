function report = EP_RUN_CHECKS()
%EP_RUN_CHECKS Mathematical, solver, accounting, and data-preprocessing checks.
%   These checks do not generate or export publication results.
cfg=EP_CONFIG('smoke'); cfg.scopes={'deterministic'}; cfg.nonlinear_dimensions=10;
cfg.export_tables=false; cfg.export_figures=false;
rng(8072026,'twister'); names={};
methods=ep.methods(cfg);
assert(numel(methods)==9 && sum([methods.main])==6);
for j=1:numel(methods)
    a=methods(j).alpha; q=1-methods(j).step_ratio/2;
    assert(q*(1-a)^2-a*(1+a)>0);
end
names{end+1}='Admissible parameters, including NM-fast';
bad=cfg; bad.alpha=-0.1;
rejected=false; try, ep.methods(bad); catch err, rejected=strcmp(err.identifier,'EP:Parameters'); end
assert(rejected);
bad=cfg; bad.lambda_over_gamma=-0.5;
rejected=false; try, ep.methods(bad); catch err, rejected=strcmp(err.identifier,'EP:Parameters'); end
assert(rejected);
bad=cfg; bad.residual_eta_over_gamma=0;
rejected=false; try, ep.validate_config(bad); catch, rejected=true; end
assert(rejected);
names{end+1}='Negative inertia, negative steps and zero diagnostic step are rejected';
[models,~]=ep.models(cfg);
for j=1:numel(models)
    p=models{j}; assert(p.reference_kkt<cfg.kkt_tolerance);
    if ~strcmp(p.type,'nonlinear'), assert(min(eig(p.H))>0); end
end
names{end+1}='Independent convex reference QPs and positivity';
% Original quadratic EP identity, separately from the VI at its diagonal.
p=models{find(cellfun(@(s)strcmp(s.type,'quadratic'),models),1)};
for j=1:40
    x=randn(5,1); y=randn(5,1); z=randn(5,1);
    f=@(a,b)(p.P*a+p.Q*b+p.linear)'*(b-a);
    identity=f(x,z)-f(y,z)-f(x,y);
    exact=(p.M*(x-y))'*(z-y);
    assert(abs(identity-exact)<1e-10);
    g=norm(p.M*(x-y))^2;
    assert(f(x,y)+f(y,x)<=-p.gamma*g+1e-10);
    assert(identity<=p.gamma*g+(p.L/4)*norm(z-y)^2+1e-10);
end
names{end+1}='Quadratic EP structural assumptions B1/B2';
for j=1:40
    x=randn(10,1); y=randn(10,1); z=randn(10,1);
    h=@(a)hypot(1,a); f=@(a,b)sum(h(a).*(h(b)-h(a)));
    g=norm(h(x)-h(y))^2;
    assert(abs(f(x,y)+f(y,x)+g)<1e-10);
    assert(f(x,z)-f(y,z)-f(x,y)<=g+.25*norm(z-y)^2+1e-10);
end
names{end+1}='Nonlinear EP structural assumptions B1/B2';
weighted=models{find(cellfun(@(s)strcmp(s.type,'nonlinear') && s.kappa==100,models),1)};
for j=1:20
    x=randn(weighted.n,1); y=randn(weighted.n,1); z=randn(weighted.n,1);
    h=@(t)hypot(1,sqrt(weighted.a).*t);
    f=@(u,v)sum(h(u).*(h(v)-h(u)));
    g=max(weighted.a)*norm(h(x)-h(y))^2;
    assert(f(x,y)+f(y,x)<=-weighted.gamma*g+1e-10);
    assert(f(x,z)-f(y,z)-f(x,y)<=weighted.gamma*g+...
        norm(z-y)^2/(4*weighted.gamma)+1e-10);
    assert(norm(ep.operator(weighted,x)-weighted.a.*x,Inf)<eps);
end
names{end+1}='Weighted nonlinear structural bounds and diagonal operator';
% Scalar convex optimality and an independent bisection reference.
y=[0;1e-12;-1e-12;1;-1;1e3;-1e3;20*randn(200,1)];
for step=[.5,1,1.8]
    [z,s]=ep.nonlinear_prox(y,step,cfg.inner_tolerance);
    lo=zeros(size(y)); hi=abs(y); a=step*hypot(1,y);
    for j=1:100
        mid=(lo+hi)/2; f=mid-abs(y)+a.*mid./hypot(1,mid);
        below=f<0; lo(below)=mid(below); hi(~below)=mid(~below);
    end
    ref=sign(y).*((lo+hi)/2);
    assert(s.kkt<=10*cfg.inner_tolerance);
    assert(max(abs(z-ref)./max(1,abs(y)))<2e-11);
end
names{end+1}='Nonlinear subproblem against independent bisection';
% Distinct first argument and centre are essential in EG's second subproblem.
v=5*randn(weighted.n,1); u=3*randn(weighted.n,1); step=.9*weighted.gamma;
[z,s]=ep.nonlinear_prox(v,step,cfg.inner_tolerance,weighted.a,u);
lo=zeros(size(v)); hi=abs(v); factor=step*weighted.a.*hypot(1,sqrt(weighted.a).*u);
for j=1:100
    mid=(lo+hi)/2;
    f=mid-abs(v)+factor.*mid./hypot(1,sqrt(weighted.a).*mid);
    below=f<0; lo(below)=mid(below); hi(~below)=mid(~below);
end
ref=sign(v).*((lo+hi)/2);
assert(s.kkt<=10*cfg.inner_tolerance && max(abs(z-ref)./max(1,abs(v)))<2e-11);
names{end+1}='Weighted subproblem with distinct first argument and centre';
% Small QP certificates checked directly in original primal/dual variables.
plan=ep.qp_plan(eye(3)+ones(3),[-eye(3);eye(3);ones(1,3)],[zeros(3,1);ones(3,1);1.7],cfg.inner_tolerance);
for j=1:50
    rhs=8*randn(3,1); [x,s]=ep.qp_solve(plan,rhs);
    assert(max(plan.A*x-plan.b)<1e-9 && min(s.multipliers)>-1e-9);
    assert(norm(plan.H*x-rhs+plan.A'*s.multipliers,Inf)<1e-8);
    assert(max(abs(s.multipliers.*(plan.A*x-plan.b)))<1e-8);
end
names{end+1}='Finite active-set solver original KKT certificates';
% Capped simplex, including unavailable intervals and near-boundary energies.
v=15*randn(100,96); upper=7.2*double(rand(100,96)>.4);
upper(:,1)=7.2; cap=sum(upper,2); target=cap.*rand(100,1);
target(1)=0; target(2)=cap(2); target(3)=cap(3)*1e-10; target(4)=cap(4)*(1-1e-10);
[x,s]=ep.capped_simplex(v,upper,target,cfg.inner_tolerance);
lo=min(v-upper,[],2); hi=max(v,[],2);
for j=1:120
    mid=(lo+hi)/2; z=min(upper,max(0,v-mid)); high=sum(z,2)>target;
    lo(high)=mid(high); hi(~high)=mid(~high);
end
ref=min(upper,max(0,v-(lo+hi)/2)); ref(1,:)=0; ref(2,:)=upper(2,:);
assert(norm(x-ref,'fro')/max(1,norm(ref,'fro'))<1e-10 && s.kkt<2e-11);
names{end+1}='Capped-simplex projection against independent bisection';
% A known exact solution must stop at iteration zero, with one diagnostic.
p=models{1}; r=ep.run_one(p,zeros(p.n,1),methods(1),cfg);
assert(strcmp(r.status,'converged') && r.iterations==0 && r.counts.update_subproblems==0);
assert(r.counts.diagnostic_subproblems==1);
names{end+1}='Current-point stopping and iteration-zero accounting';
eg=methods(find(strcmp({methods.kind},'eg'),1));
p=weighted; p.max_iter=1; shortcfg=cfg; shortcfg.tolerance=1e-16;
x0=5*ones(p.n,1); r=ep.run_one(p,x0,eg,shortcfg);
solver=ep.prepare(p,eg.step_ratio*p.gamma,cfg);
w=ep.map(p,x0,solver); expected=ep.map(p,w,solver,[],x0);
assert(r.iterations==1 && r.counts.update_subproblems==2 &&...
    r.counts.diagnostic_subproblems==2 && norm(r.x-expected,Inf)<1e-11);
wrong=ep.map(p,w,solver);
assert(norm(expected-wrong,Inf)>1e-4);
names{end+1}='EG uses two subproblems and the original centre in its second step';
evcfg=cfg; evcfg.scopes={'ev'}; evcfg.synthetic_ev_for_smoke=true;
[ev,~]=ep.models(evcfg); p=ev{1}; p.max_iter=2;
shortcfg=evcfg; shortcfg.tolerance=1e-16;
x0=ep.initial_point(p,2026,shortcfg); r=ep.run_one(p,x0,methods(4),shortcfg);
assert(r.iterations==2 && r.counts.update_projections==2 && r.counts.diagnostic_projections==3);
assert(r.energy_error_kwh<1e-8 && r.bound_error_kw<1e-10 && r.gap_upper_bound>=0);
ev_result_fixture=r;
names{end+1}='EV update/diagnostic counts and physical feasibility';
assert(max(abs(ep.percentile([1,2,3,4],[.25,.5,.75])-[1.75,2.5,3.25]))<eps(4));
names{end+1}='Deterministic linear-interpolation quartiles';
assert(all(isnan(ep.percentile([1,NaN,3],[.25,.5,.75]))));
assert(isinf(ep.percentile([1,Inf],.5)));
names{end+1}='Nonfinite outcomes are not silently removed from quantiles';
% Temporary, explicitly synthetic records test schema/timezone filtering only.
tmp=tempname; mkdir(tmp); cleanup=onCleanup(@()rmdir(tmp,'s')); %#ok<NASGU>
hash_path=fullfile(tmp,'hash_fixture.txt'); ep.write_text(hash_path,'abc');
assert(strcmp(ep.sha256_file(hash_path),...
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'));
rec=@(id,a,b,e)struct('sessionID',id,'connectionTime',a,'disconnectTime',b,'kWhDelivered',e);
records={rec('ok','Wed, 1 May 2019 15:00:00 GMT','Wed, 1 May 2019 17:15:00 GMT',6),...
    rec('bad','invalid','invalid',1),...
    rec('night','Thu, 2 May 2019 06:00:00 GMT','Thu, 2 May 2019 08:00:00 GMT',1),...
    rec('short','Wed, 1 May 2019 15:01:00 GMT','Wed, 1 May 2019 15:10:00 GMT',1),...
    rec('power','Wed, 1 May 2019 15:00:00 GMT','Wed, 1 May 2019 15:15:00 GMT',2),...
    rec('april','Wed, 1 May 2019 06:00:00 GMT','Wed, 1 May 2019 06:30:00 GMT',1),...
    rec('ok','Wed, 1 May 2019 15:00:00 GMT','Wed, 1 May 2019 17:15:00 GMT',6)};
path=fullfile(tmp,'synthetic_acn_schema_fixture.json');
ep.write_text(path,jsonencode(struct('sessions',{records})));
[days,audit]=EP_IMPORT_ACN(path,fullfile(tmp,'synthetic_fixture.mat'),cfg);
assert(audit.raw_sessions==7 && audit.retained_sessions==1 && audit.retained_days==1);
assert(all([audit.duplicates,audit.invalid_records,audit.different_local_day,...
    audit.empty_window,audit.energy_infeasible,audit.outside_month]==1));
assert(isequal(find(days{1}.mask),33:41));
names{end+1}='ACN UTC/local dates, complete slots, exclusions, and duplicate audit';
% An invalid first duplicate must not suppress a later valid session.
duplicates={rec('same','invalid','invalid',1),...
    rec('same','Wed, 1 May 2019 15:00:00 GMT','Wed, 1 May 2019 17:15:00 GMT',6),...
    rec('same','Wed, 1 May 2019 15:00:00 GMT','Wed, 1 May 2019 17:15:00 GMT',6)};
dup_path=fullfile(tmp,'duplicate_fixture.json');
upstream=struct('cache_revision','test_revision');
ep.write_text(dup_path,jsonencode(struct('sessions',{duplicates},'provenance',upstream)));
prepared_path=fullfile(tmp,'duplicates.mat');
[~,dup_audit]=EP_IMPORT_ACN(dup_path,prepared_path,cfg);
saved=load(prepared_path,'provenance');
assert(dup_audit.raw_sessions==3 && dup_audit.invalid_records==1 &&...
    dup_audit.retained_sessions==1 && dup_audit.duplicates==1 && dup_audit.distinct_session_ids==1);
assert(strcmp(saved.provenance.upstream.cache_revision,'test_revision'));
names{end+1}='First valid duplicate and upstream provenance are preserved';
bundle_cfg=EP_CONFIG('publication');
assert(strcmp(ep.sha256_file(bundle_cfg.acn_source_file),...
    '669a4a118b77afb4626b0da5cfa7132e2de770172ee0d7c8f54ee1b42ccfb01b'));
bundle_mat=fullfile(tmp,'bundle.mat');
[~,bundle_audit]=EP_IMPORT_ACN(bundle_cfg.acn_source_file,bundle_mat,bundle_cfg);
assert(bundle_audit.raw_sessions==964 && bundle_audit.valid_same_day==913 &&...
    bundle_audit.empty_window==10 && bundle_audit.energy_infeasible==33 &&...
    bundle_audit.retained_sessions==870 && bundle_audit.retained_days==31);
saved=load(bundle_mat,'provenance');
assert(strcmp(saved.provenance.upstream.cache_revision,...
    '11d9bbdad7ace18d3d182c9a1f98f2f3339dad86'));
names{end+1}='Bundled observed ACN data retain 870 sessions across 31 days';
empty_path=fullfile(tmp,'empty_api_result.json');
ep.write_text(empty_path,'{"_items":[],"_meta":{"total":0}}');
[empty_days,empty_audit]=EP_IMPORT_ACN(empty_path,fullfile(tmp,'empty_api_result.mat'),cfg);
assert(isempty(empty_days) && empty_audit.raw_sessions==0 && empty_audit.invalid_records==0);
missing_cfg=EP_CONFIG('publication'); missing_cfg.scopes={'ev'};
missing_cfg.data_file=fullfile(tmp,'missing.mat');
rejected=false;
try, ep.models(missing_cfg); catch err, rejected=strcmp(err.identifier,'EP:MissingData'); end
assert(rejected);
missing_cfg.data_file=fullfile(tmp,'empty_api_result.mat');
rejected=false;
try, ep.models(missing_cfg); catch err, rejected=strcmp(err.identifier,'EP:EmptyData'); end
assert(rejected);
names{end+1}='Requested publication EV cannot silently skip missing or empty actual input';
page_path=fullfile(tmp,'incomplete_api_page.json');
tails={',"_links":{"next":{"href":"sessions/caltech?page=2"}}}',...
    ',"_meta":{"total":2}}'};
for j=1:numel(tails)
    ep.write_text(page_path,['{"_items":',jsonencode(records(1)),tails{j}]);
    rejected=false;
    try
        EP_IMPORT_ACN(page_path,fullfile(tmp,'partial_should_not_exist.mat'),cfg);
    catch err
        rejected=strcmp(err.identifier,'EP:PartialData');
    end
    assert(rejected);
end
names{end+1}='Empty API arrays and rejection of incomplete pagination';
% Stale signatures cannot be counted or exported after a protocol change.
manifest=struct('expected_keys',{{'fixture'}},'expected_signatures',{{'new'}},'data_status','fixture');
ep.atomic_save(fullfile(tmp,'manifest.mat'),struct('manifest',manifest));
ep.atomic_save(fullfile(tmp,'checkpoints','fixture.mat'),...
    struct('signature','old','meta',struct(),'result',struct('status','converged')));
state=EP_STATUS(tmp); assert(state.complete==0 && state.remaining==1 && state.stale_checkpoints==1);
[t,~]=ep.load_results(tmp); assert(isempty(t));
names{end+1}='Stale-checkpoint rejection in status and export loading';
% A determinant-only current manifest must not whitelist any old EV output.
sm=table("quadratic",'VariableNames',{'model_id'});
em=struct('cfg',cfg); em.cfg.export_tables=true; em.cfg.export_figures=false;
rr={struct('meta',struct('reference',zeros(5,1)))};
listed=ep.current_exports(sm,table(),rr,em);
assert(~any(contains(string(listed),'ev_')));
names{end+1}='Current-manifest artifact whitelist excludes stale EV files';
% Export-only fixtures stay in this temporary directory and never enter a
% publication run. A changed live data file must not alter frozen counts.
export_root=fullfile(tmp,'export_regression'); mkdir(export_root);
fixture_cfg=EP_CONFIG('publication'); fixture_cfg.scopes={'ev'};
fixture_cfg.export_figures=false;
fixture_cfg.data_file=fullfile(export_root,'mutable_input.mat');
live_audit=bundle_audit; live_audit.retained_sessions=999;
ep.atomic_save(fixture_cfg.data_file,struct('audit',live_audit));
fixture_key='ev_fixture_r001_nm';
frozen=struct('audit',bundle_audit,'provenance',saved.provenance);
fixture_manifest=struct('cfg',fixture_cfg,'methods',methods(1),...
    'model_ids',{{'ev_fixture'}},'data_status','ACN-Data_imported',...
    'expected_keys',{{fixture_key}},'expected_signatures',{{'fixture_current'}},...
    'data_snapshot',frozen,'matlab_version',version,'computer',computer);
meta=struct('model_id','ev_fixture','model_name','Synthetic export fixture',...
    'model_type','ev','method_key','nm','method_name','NM','matched_step',true,...
    'trial',1,'seed',1,'n',numel(ev_result_fixture.x),...
    'data_source','SOFTWARE_TEST_ONLY','parallel',false,'reference',[],'reference_kkt',NaN);
ep.atomic_save(fullfile(export_root,'manifest.mat'),struct('manifest',fixture_manifest));
ep.atomic_save(fullfile(export_root,'checkpoints',[fixture_key '.mat']),...
    struct('signature','fixture_current','meta',meta,'result',ev_result_fixture));
[fixture_runs,fixture_records,fixture_manifest]=ep.load_results(export_root);
fixture_summary=ep.summarize(fixture_runs,fixture_manifest);
ep.export_tables(fixture_summary,table(),fixture_records,fixture_manifest,fullfile(export_root,'tables'));
selection=fileread(fullfile(export_root,'tables','ev_data_summary.tex'));
assert(contains(selection,'Retained sessions & 870') && ~contains(selection,'Retained sessions & 999'));
names{end+1}='Export uses frozen selection counts rather than a changed live data file';
% Mixed checkpoint schemas must load in either order without adding columns.
schema_root=fullfile(tmp,'result_schema_regression');
schema_manifest=fixture_manifest;
schema_manifest.expected_keys={'ev_fixture_r001_nm','ev_fixture_r002_nm','ev_fixture_r003_nm'};
schema_manifest.expected_signatures=repmat({'schema_current'},1,3);
schema_results={ev_result_fixture,ev_result_fixture,...
    struct('status','solver_error','message','SOFTWARE_TEST_ONLY')};
schema_results{2}.counts=struct('update_subproblems',7,'extra_counter',123);
for j=1:3
    schema_meta=meta; schema_meta.trial=j;
    ep.atomic_save(fullfile(schema_root,'checkpoints',[schema_manifest.expected_keys{j} '.mat']),...
        struct('signature','schema_current','meta',schema_meta,'result',schema_results{j}));
end
ep.atomic_save(fullfile(schema_root,'manifest.mat'),struct('manifest',schema_manifest));
[mixed_runs,mixed_records]=ep.load_results(schema_root);
assert(height(mixed_runs)==3 && numel(mixed_records)==3);
assert(isequal(mixed_runs.Properties.VariableNames,fixture_runs.Properties.VariableNames));
assert(mixed_runs.update_subproblems(1)==ev_result_fixture.counts.update_subproblems);
assert(mixed_runs.update_subproblems(2)==7 && isnan(mixed_runs.diagnostic_subproblems(2)));
assert(mixed_records{2}.result.counts.extra_counter==123);
assert(mixed_runs.status(3)=="solver_error" && isnan(mixed_runs.iterations(3)) &&...
    isnan(mixed_runs.update_subproblems(3)) && isnan(mixed_runs.total_subproblems(3)));
schema_manifest.expected_keys=schema_manifest.expected_keys(3:-1:1);
schema_manifest.expected_signatures=schema_manifest.expected_signatures(3:-1:1);
ep.atomic_save(fullfile(schema_root,'manifest.mat'),struct('manifest',schema_manifest));
reordered_runs=ep.load_results(schema_root);
assert(isequaln(reordered_runs,mixed_runs(3:-1:1,:)));
names{end+1}='Result loading handles partial counters and failures in either order';
% A successful pair with zero elapsed-time denominator is eligible for I only.
paired=fixture_runs([1,1],:);
paired.status(:)="converged";
paired.method_key=["nm";"i010"]; paired.method_name=["NM";"I-0.10"];
paired.alpha=[0;.1]; paired.iterations=[10;5]; paired.time_seconds=[1;0];
pair_manifest=fixture_manifest; pair_manifest.methods=methods;
[~,pair_summary]=ep.paired_speedups(paired,pair_manifest);
assert(height(pair_summary)==1 && pair_summary.n_positive_iteration_pairs==1 &&...
    pair_summary.n_positive_time_pairs==0 && isnan(pair_summary.time_ratio_median));
names{end+1}='Iteration and time ratios have separate positive-denominator counts';
% More than one eligible method exercises every subsequent struct append.
paired_many=paired([1,2,2],:);
paired_many.method_key(3)="i020"; paired_many.method_name(3)="I-0.20";
paired_many.alpha(3)=.2; paired_many.iterations(3)=4; paired_many.time_seconds(3)=.5;
pair_manifest.expected_keys={'ev_fixture_r001_nm','ev_fixture_r001_i010','ev_fixture_r001_i020'};
many_summary=ep.summarize(paired_many,pair_manifest);
assert(height(many_summary)==3 && all(many_summary.n_recorded==1) &&...
    all(many_summary.n_expected==1) && all(many_summary.n_success==1));
[many_details,many_pairs]=ep.paired_speedups(paired_many,pair_manifest);
i020=many_pairs(many_pairs.method_key=="i020",:);
assert(height(many_details)==2 && height(many_pairs)==2 && height(i020)==1);
assert(i020.iteration_ratio_median==2.5 && i020.time_ratio_median==2 &&...
    i020.n_positive_iteration_pairs==1 && i020.n_positive_time_pairs==1);
names{end+1}='Summary and paired comparisons retain multiple method rows';
failed=fixture_runs([1,1],:); failed.status=["converged";"solver_error"];
failed.iterations(2)=NaN; failed.time_seconds(2)=NaN; failed.residual(2)=Inf;
failure_manifest=fixture_manifest;
failure_manifest.expected_keys={'ev_fixture_r001_nm','ev_fixture_r002_nm'};
failure_summary=ep.summarize(failed,failure_manifest);
assert(failure_summary.n_other==1 && isnan(failure_summary.iterations_median) &&...
    isnan(failure_summary.time_median) && isinf(failure_summary.residual_median));
names{end+1}='Failure outcomes remain visible in summary statistics';
report=struct('passed',true,'checks',{names},'matlab_version',version);
for j=1:numel(names), fprintf('PASS: %s\n',names{j}); end
fprintf('PASS: %d checks.\n',numel(names));
end
