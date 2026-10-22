function solver = prepare(p,step,cfg)
%PREPARE Excluded-from-timing factorization of the fixed subproblem Hessian.
solver.step=step; solver.warm=1; solver.inner_tolerance=cfg.inner_tolerance;
switch p.type
    case 'quadratic'
        solver.plan=ep.qp_plan(eye(p.n)+2*step*p.Q,p.A,p.b,cfg.inner_tolerance);
    case 'river'
        solver.plan=ep.qp_plan(eye(p.n),p.A,p.b,cfg.inner_tolerance);
end
end
