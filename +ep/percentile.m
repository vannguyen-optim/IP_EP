function q = percentile(x,p)
%PERCENTILE Type-7 quantiles; nonfinite failures are never silently removed.
x=double(x(:)); p=double(p(:)');
assert(all(isfinite(p)) && all(p>=0 & p<=1),'EP:Quantile','Quantile probabilities must lie in [0,1].');
if isempty(x) || any(isnan(x)), q=NaN(size(p)); return; end
x=sort(x); h=1+(numel(x)-1)*p; lo=floor(h); hi=ceil(h); w=h-lo;
q=zeros(size(p));
for j=1:numel(p)
    if lo(j)==hi(j) || x(lo(j))==x(hi(j))
        q(j)=x(lo(j));
    else
        q(j)=(1-w(j))*x(lo(j))+w(j)*x(hi(j));
    end
end
end
