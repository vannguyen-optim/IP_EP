function plan = qp_plan(H,A,b,tol)
%QP_PLAN Precompute every independent active set for a small strictly convex QP.
%   min_z 0.5*z'*H*z-rhs'*z, subject to A*z<=b.
%   For dimension <=6, exhaustive active-set enumeration is inexpensive.
%   The returned affine KKT candidates solve the ORIGINAL QP, without a
%   penalty, smoothing approximation, or toolbox dependency.
if nargin<4, tol=1e-10; end
n=size(H,1); m=size(A,1);
assert(n<=6,'EP:QPSize','This exact finite solver is for dimension at most 6.');
H=(H+H')/2;
[R,p]=chol(H); assert(p==0,'EP:QPHessian','QP Hessian must be positive definite.');
Hi=R\(R'\eye(n));
items=cell(1,1+sum(arrayfun(@(k)nchoosek(m,k),1:min(n,m))));
count=1;
items{count}=struct('W',Hi,'v',zeros(n,1),'D',zeros(0,n),...
    'e',zeros(0,1),'active',zeros(0,1));
for k=1:min(n,m)
    sets=nchoosek(1:m,k);
    for j=1:size(sets,1)
        ids=sets(j,:); As=A(ids,:); bs=b(ids);
        M=As*Hi*As'; M=(M+M')/2;
        if rcond(M)<1e-12, continue; end
        D=M\(As*Hi); e=-(M\bs);
        W=Hi-Hi*As'*D; v=-Hi*As'*e;
        count=count+1;
        items{count}=struct('W',W,'v',v,'D',D,'e',e,'active',ids(:));
    end
end
plan.H=H; plan.A=A; plan.b=b(:); plan.n=n; plan.m=m;
plan.items=items(1:count); plan.tol=tol;
end
