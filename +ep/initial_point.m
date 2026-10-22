function x = initial_point(p,seed,cfg)
%INITIAL_POINT Identical feasible starts for every method on a paired instance.
rng(seed,'twister');
switch p.type
    case 'nonlinear'
        x=5*randn(p.n,1);
    case 'electricity'
        x=p.lower+(p.upper-p.lower).*rand(p.n,1);
    case 'quadratic'
        v=-5+10*rand(p.n,1);
        plan=ep.qp_plan(eye(p.n),p.A,p.b,cfg.inner_tolerance);
        x=ep.qp_solve(plan,v);
    case 'river'
        upper=min(p.b(end-1:end)./p.A(end-1:end,:),[],1)';
        v=upper.*rand(p.n,1);
        plan=ep.qp_plan(eye(p.n),p.A,p.b,cfg.inner_tolerance);
        x=ep.qp_solve(plan,v);
    case 'ev'
        counts=sum(p.upper>0,2);
        x=(p.upper>0).*(p.target./counts);
end
assert(ep.feasibility(p,x)<=1e-8,'EP:Initialization','Initial point is infeasible.');
end
