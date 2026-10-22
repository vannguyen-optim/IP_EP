function [x,info] = capped_simplex(v,u,target,tol)
%CAPPED_SIMPLEX Row-wise Euclidean projection onto 0<=x<=u, sum(x)=target.
%   Sorted breakpoints give the Lagrange multiplier. Newton polishing and a
%   bracketed fallback control roundoff at nearly coincident breakpoints.
if nargin<4, tol=1e-12; end
[n,t]=size(v); target=target(:); capacity=sum(u,2);
assert(all(target>=0 & target<=capacity),'EP:Capacity','Infeasible energy targets.');
x=zeros(n,t); tau=zeros(n,1);
full=target==capacity; zero=target==0;
x(full,:)=u(full,:);
ids=find(~full & ~zero);
work=0;
if ~isempty(ids)
    vv=v(ids,:); uu=u(ids,:); ee=target(ids); nr=numel(ids);
    [knots,order]=sort([vv-uu,vv],2,'ascend');
    signs=[ones(1,t),-ones(1,t)];
    free=cumsum(signs(order),2);
    ss=[sum(uu,2),sum(uu,2)-cumsum(free(:,1:end-1).*diff(knots,1,2),2)];
    cross=(ss(:,1:end-1)>=ee) & (ss(:,2:end)<=ee) & (free(:,1:end-1)>0);
    [has,j]=max(cross,[],2);
    lin=sub2ind(size(knots),(1:nr)',j);
    ff=free(lin); ff=max(ff,1);
    tt=knots(lin)+(ss(lin)-ee)./ff;
    xx=min(uu,max(0,vv-tt));
    for k=1:3
        err=sum(xx,2)-ee;
        ok=abs(err)<=tol*max(1,ee);
        if all(ok), break; end
        nfree=sum(xx>0 & xx<uu,2);
        polish=~ok & nfree>0 & has;
        tt(polish)=tt(polish)+err(polish)./nfree(polish);
        xx=min(uu,max(0,vv-tt));
    end
    bad=abs(sum(xx,2)-ee)>tol*max(1,ee) | ~has;
    if any(bad)
        vb=vv(bad,:); ub=uu(bad,:); eb=ee(bad);
        lower=min(vb-ub,[],2); upper=max(vb,[],2);
        for k=1:80
            mid=(lower+upper)/2;
            xm=min(ub,max(0,vb-mid));
            high=sum(xm,2)>eb;
            lower(high)=mid(high); upper(~high)=mid(~high);
        end
        tt(bad)=(lower+upper)/2;
        xx(bad,:)=min(ub,max(0,vb-tt(bad)));
        work=work+80*nnz(bad)*t;
    end
    x(ids,:)=xx; tau(ids)=tt;
    work=work+2*nr*t;
end
% Boundary rows admit any multiplier past the extreme breakpoint.
tau(zero)=max(v(zero,:),[],2);
tau(full)=min(v(full,:)-u(full,:),[],2);
eq=max(abs(sum(x,2)-target)./max(1,target),[],'all');
box=max([0;reshape(-x,[],1);reshape(x-u,[],1)]);
station=norm(x-min(u,max(0,v-tau)),'fro')/max(1,norm(v,'fro'));
kkt=max([eq,box,station]);
assert(kkt<=20*tol,'EP:Projection','Capped-simplex projection residual too large.');
info=struct('kkt',kkt,'inner_work',work,'multiplier',tau);
end
