function v = feasibility(p,x)
%FEASIBILITY Absolute constraint violation in the original model units.
switch p.type
    case 'nonlinear'
        v=0;
    case {'quadratic','river'}
        v=max([0;p.A*x-p.b]);
    case 'electricity'
        v=max([0;p.lower-x;x-p.upper]);
    case 'ev'
        v=max([0;reshape(-x,[],1);reshape(x-p.upper,[],1);...
            abs(p.dt*sum(x,2)-p.energy)]);
end
end
