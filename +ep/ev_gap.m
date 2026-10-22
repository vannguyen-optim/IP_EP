function [gap,z] = ev_gap(p,x)
%EV_GAP Frank-Wolfe upper bound on J(x)-min_C J; row-wise exact linear oracle.
load=sum(x,1); z=zeros(size(x));
for i=1:size(x,1)
    ids=find(p.upper(i,:)>0);
    [~,order]=sort(load(ids),'ascend'); ids=ids(order);
    remaining=p.target(i);
    for j=1:numel(ids)
        amount=min(p.upper(i,ids(j)),remaining);
        z(i,ids(j))=amount; remaining=remaining-amount;
        if remaining<=0, break; end
    end
end
gap=sum(load.*(sum(x,1)-sum(z,1)));
% Only negative roundoff is removed; the raw gap is also returned by the runner.
end
