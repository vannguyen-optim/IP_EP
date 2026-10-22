function [z,info,solver] = map(p,first,solver,G,center)
%MAP Minimize step*f(first,z)+0.5*||z-center||^2 over the feasible set.
%   Omitting center sets center=first, including infeasible extrapolates.
%   For VI models a supplied G must equal F(first); otherwise F is evaluated.
%   EG uses (first,center)=(x,x) and then (w,x), with the same step.
if nargin<5 || isempty(center), center=first; end
step=solver.step;
info=struct('kkt',0,'inner_work',0,'operator_evaluations',0,...
    'projection_evaluations',0,'subproblem_evaluations',1);
switch p.type
    case 'nonlinear'
        [z,s]=ep.nonlinear_prox(center,step,solver.inner_tolerance,p.a,first);
        info.kkt=s.kkt; info.inner_work=s.inner_work;
    case 'quadratic'
        rhs=center-step*(p.M*first+p.linear);
        [z,s,solver.warm]=ep.qp_solve(solver.plan,rhs,solver.warm);
        info.kkt=s.kkt; info.inner_work=s.candidate_tests;
    otherwise
        if nargin<4 || isempty(G)
            G=ep.operator(p,first); info.operator_evaluations=1;
        end
        v=center-step*G; info.projection_evaluations=1;
        switch p.type
            case 'electricity'
                z=min(p.upper,max(p.lower,v));
            case 'river'
                [z,s,solver.warm]=ep.qp_solve(solver.plan,v,solver.warm);
                info.kkt=s.kkt; info.inner_work=s.candidate_tests;
            case 'ev'
                [z,s]=ep.capped_simplex(v,p.upper,p.target,solver.inner_tolerance);
                info.kkt=s.kkt; info.inner_work=s.inner_work;
        end
end
end
