function [z,info] = nonlinear_prox(y,step,tol,weights,first)
%NONLINEAR_PROX Solve z-y+step*h_a(first).*a.*z./h_a(z)=0.
%   h_a(t)=sqrt(1+a.*t.^2); y is the quadratic regularization centre.
%   The original three-argument form uses a=1 and first=y.
%   A safeguarded scalar Newton method preserves the unique root bracket.
if nargin<4 || isempty(weights), weights=ones(size(y)); end
if isscalar(weights), weights=repmat(weights,size(y)); end
if nargin<5 || isempty(first), first=y; end
assert(isequal(size(weights),size(y)) && isequal(size(first),size(y)) &&...
    all(isfinite(weights(:)) & weights(:)>0),...
    'EP:NonlinearWeights','Weights must be positive and match the argument size.');
rootweights=sqrt(weights);
t=abs(y); a=step*weights.*hypot(1,rootweights.*first);
lo=zeros(size(t)); hi=t;
z=t./(1+a);
active=t>0; work=0;
for k=1:80
    ids=find(active);
    if isempty(ids), break; end
    zz=z(ids); hh=hypot(1,rootweights(ids).*zz);
    f=zz-t(ids)+a(ids).*zz./hh;
    work=work+numel(ids);
    done=abs(f)<=tol*(1+t(ids));
    active(ids(done))=false; ids=ids(~done);
    if isempty(ids), continue; end
    zz=z(ids); hh=hypot(1,rootweights(ids).*zz);
    f=zz-t(ids)+a(ids).*zz./hh;
    neg=f<0; lo(ids(neg))=zz(neg); hi(ids(~neg))=zz(~neg);
    cand=zz-f./(1+a(ids)./hh.^3);
    unsafe=~isfinite(cand) | cand<=lo(ids) | cand>=hi(ids);
    cand(unsafe)=(lo(ids(unsafe))+hi(ids(unsafe)))/2;
    z(ids)=cand;
end
z=sign(y).*z;
r=z-y+a.*z./hypot(1,rootweights.*z);
err=max(abs(r)./(1+abs(y)),[],'all');
assert(err<=10*tol,'EP:NonlinearProx','Scalar optimality residual is too large.');
info=struct('kkt',err,'inner_work',work);
end
