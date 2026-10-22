function G = operator(p,x)
%OPERATOR Diagonal bifunction gradient, or the VI operator as appropriate.
switch p.type
    case 'nonlinear'
        G=p.a.*x;
    case {'quadratic','electricity','river'}
        G=p.H*x+p.linear;
    case 'ev'
        G=repmat(sum(x,1),size(x,1),1);
    otherwise
        error('EP:Model','Unknown model type.');
end
end
