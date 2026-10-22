function [x,info,warm] = qp_solve(plan,rhs,warm)
%QP_SOLVE Find a primal/dual feasible KKT candidate, checking original residuals.
if nargin<3 || isempty(warm), warm=1; end
nc=numel(plan.items); order=[warm,1:(warm-1),(warm+1):nc];
best=Inf; bestx=[]; bestmu=[]; bestid=0;
for j=1:numel(order)
    id=order(j); c=plan.items{id}; z=c.W*rhs+c.v;
    nu=c.D*rhs+c.e;
    scaleP=max([1;abs(plan.b);abs(plan.A*z)]);
    scaleD=max([1;abs(rhs);abs(plan.H*z)]);
    primal=max([0;plan.A*z-plan.b])/scaleP;
    dual=max([0;-nu])/scaleD;
    if max(primal,dual)>plan.tol, continue; end
    mu=zeros(plan.m,1); mu(c.active)=nu;
    stat=norm(plan.H*z-rhs+plan.A'*mu,Inf)/scaleD;
    comp=max([0;abs(mu.*(plan.A*z-plan.b))])/...
        max(1,scaleP*scaleD);
    residual=max([primal,dual,stat,comp]);
    if residual<best
        best=residual; bestx=z; bestmu=mu; bestid=id;
    end
    if residual<=plan.tol
        x=z; warm=id;
        info=struct('kkt',residual,'candidate_tests',j,'multipliers',mu);
        return;
    end
end
if best<=10*plan.tol
    x=bestx; warm=bestid;
    info=struct('kkt',best,'candidate_tests',numel(order),'multipliers',bestmu);
    return;
end
error('EP:QPSolve','No acceptable KKT point found; smallest residual %.3g.',best);
end
