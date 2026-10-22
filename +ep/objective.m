function value = objective(p,x)
%OBJECTIVE Convex potential for VI models; the natural zero-centered EP merit.
switch p.type
    case 'nonlinear'
        % This diagnostic is not used as an asserted potential for f.
        h=hypot(1,sqrt(p.a).*x);
        value=sum(h.*(h-1),'all');
    case {'quadratic','electricity','river'}
        value=0.5*x'*p.H*x+p.linear'*x;
    case 'ev'
        value=0.5*sum(sum(x,1).^2);
end
end
