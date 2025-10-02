function ai = compute_ai(L, R, method)
% COMPUTE_AI  Základní asymetrický index z levé/pravé hodnoty.
% method: 'fracdiff' (default), 'logratio'
%
%  fracdiff = (L - R) ./ ((L + R)/2)   % sym. procentní rozdíl
%  logratio = log(L) - log(R)          % log poměr; vyžaduje L>0 & R>0

if nargin < 3 || isempty(method), method = 'fracdiff'; end

L = double(L); R = double(R);
ai = nan(size(L));

switch lower(method)
    case 'fracdiff'
        denom = (L + R) ./ 2;
        ai = (L - R) ./ denom;
        ai(denom == 0) = NaN;

    case 'logratio'
        ok = L > 0 & R > 0;
        ai(~ok) = NaN;
        ai(ok) = log(L(ok)) - log(R(ok));

    otherwise
        error('Unknown AI method: %s', method);
end
end
