function result = run_one(p,x0,method,cfg)
%RUN_ONE Time updates AND current-point diagnostics; exclude setup and file I/O.
lambda=method.step_ratio*p.gamma;
eta=cfg.residual_eta_over_gamma*p.gamma;
main=ep.prepare(p,lambda,cfg); diagnostic=ep.prepare(p,eta,cfg);
% Five untimed updates warm the numerical paths. The measured run still starts
% at the ORIGINAL x0=x1, and all counters/active-set states are reset below.
warmx=x0; warmprevious=x0;
for warmk=1:5
    [~,~,diagnostic]=ep.map(p,warmx,diagnostic);
    if strcmp(method.kind,'eg')
        [warmw,~,main]=ep.map(p,warmx,main);
        [warmnew,~,main]=ep.map(p,warmw,main,[],warmx);
    else
        warmy=warmx+method.alpha*(warmx-warmprevious);
        [warmnew,~,main]=ep.map(p,warmy,main);
    end
    warmprevious=warmx; warmx=warmnew;
end
main.warm=1; diagnostic.warm=1;
x=x0; previous=x0; maxiter=p.max_iter;
history=zeros(maxiter+1,8);
% Columns: iteration, residual, wall seconds, reference error, objective,
%          ||y-x||, ||x_new-y||, maximum subproblem KKT residual so far.
count=struct('update_subproblems',0,'diagnostic_subproblems',0,...
    'update_projections',0,'diagnostic_projections',0,...
    'update_operator_evaluations',0,'diagnostic_operator_evaluations',0,...
    'update_inner_work',0,'diagnostic_inner_work',0);
maxkkt=0; extrapolation=0; displacement=0; status='iteration_cap';
run_timer=tic;
for k=0:maxiter
    G=ep.operator(p,x);
    count.diagnostic_operator_evaluations=count.diagnostic_operator_evaluations+1;
    [u,stat,diagnostic]=ep.map(p,x,diagnostic,G);
    assert(isfinite(stat.kkt),'EP:Certificate','Subproblem certificate must be finite.');
    residual=norm(x(:)-u(:))/(eta*max(1,norm(G(:))));
    count.diagnostic_subproblems=count.diagnostic_subproblems+1;
    count.diagnostic_projections=count.diagnostic_projections+stat.projection_evaluations;
    count.diagnostic_operator_evaluations=count.diagnostic_operator_evaluations+stat.operator_evaluations;
    count.diagnostic_inner_work=count.diagnostic_inner_work+stat.inner_work;
    maxkkt=max(maxkkt,stat.kkt);
    if isempty(p.reference)
        referror=NaN;
    else
        referror=norm(x(:)-p.reference(:))/max(1,norm(p.reference(:)));
    end
    value=ep.objective(p,x);
    history(k+1,:)=[k,residual,toc(run_timer),referror,value,extrapolation,displacement,maxkkt];
    if ~isfinite(residual) || any(~isfinite(x(:)))
        status='numerical_failure'; break;
    end
    if residual<=cfg.tolerance
        status='converged'; break;
    end
    if k==maxiter, break; end
    if strcmp(method.kind,'eg')
        y=x; extrapolation=0;
        [w,stat,main]=ep.map(p,x,main);
        count=update_counts(count,stat);
        maxkkt=max(maxkkt,stat.kkt);
        [xnew,stat,main]=ep.map(p,w,main,[],x);
    else
        y=x+method.alpha*(x-previous);
        extrapolation=norm(y(:)-x(:));
        [xnew,stat,main]=ep.map(p,y,main);
    end
    displacement=norm(xnew(:)-y(:));
    count=update_counts(count,stat);
    maxkkt=max(maxkkt,stat.kkt);
    previous=x; x=xnew;
end
feasibility=ep.feasibility(p,x); gap=NaN; energy_error=NaN; bound_error=NaN;
if strcmp(p.type,'ev')
    gap=ep.ev_gap(p,x);
    assert(gap>=-1e-10*max(1,abs(value)),...
        'EP:GapCertificate','The linear-oracle gap is negative beyond roundoff.');
    energy_error=max(abs(p.dt*sum(x,2)-p.energy));
    bound_error=max([0;reshape(-x,[],1);reshape(x-p.upper,[],1)]);
end
elapsed=toc(run_timer);
gap_bound=gap; if isfinite(gap), gap_bound=max(gap,0); end
if ~isfinite(maxkkt) || ~isfinite(feasibility) || maxkkt>cfg.kkt_tolerance || feasibility>1e-7
    status='certificate_failure';
end
history=history(1:k+1,:);
history(end,3)=elapsed; history(end,8)=maxkkt;
result=struct('status',status,'iterations',k,'time_seconds',elapsed,...
    'residual',residual,'reference_error',referror,'objective',value,...
    'feasibility',feasibility,'energy_error_kwh',energy_error,'bound_error_kw',bound_error,...
    'gap_upper_bound_raw',gap,...
    'gap_upper_bound',gap_bound,'max_subproblem_kkt',maxkkt,...
    'counts',count,'lambda',lambda,'eta',eta,'gamma',p.gamma,...
    'alpha',method.alpha,'x0',x0,'x',x,'history',history,...
    'history_columns',{{'iteration','residual','time_seconds','reference_error',...
    'objective','extrapolation_norm','subproblem_displacement','max_subproblem_kkt'}});
end

function count=update_counts(count,stat)
assert(isfinite(stat.kkt),'EP:Certificate','Subproblem certificate must be finite.');
count.update_subproblems=count.update_subproblems+stat.subproblem_evaluations;
count.update_projections=count.update_projections+stat.projection_evaluations;
count.update_operator_evaluations=count.update_operator_evaluations+stat.operator_evaluations;
count.update_inner_work=count.update_inner_work+stat.inner_work;
end
