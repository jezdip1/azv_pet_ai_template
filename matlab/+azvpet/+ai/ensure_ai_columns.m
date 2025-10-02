function [T, info] = ensure_ai_columns(T, opts)
% ENSURE_AI_COLUMNS  Najde bilaterální páry (Left/Right) a dopočte AI sloupce.
%   - robustní k názvům jako:
%       Mean_<Region>_Left[_SUL_LOG], Mean_<Region>_Right[_SUL_LOG]
%       Median_<Region>_Left[_SUL_LOG], Median_..._Right[_SUL_LOG]
%
% opts.method  = 'fracdiff' | 'logratio' (default 'fracdiff')
% opts.prefix  = 'AI' (default)
%
% Vrací:
%   T    : rozšířená tabulka
%   info : struct s páry a novými sloupci

if nargin < 2, opts = struct; end
if ~isfield(opts,'method'), opts.method = 'fracdiff'; end
if ~isfield(opts,'prefix'), opts.prefix = 'AI'; end

names = T.Properties.VariableNames;
pat = '^(Mean|Median)_(.+)_(Left|Right)(?:_SUL_LOG)?$';

pairs = containers.Map;   % key: measure|region|suffix -> struct with .L .R .suffix .measure .region
for i = 1:numel(names)
    nm = names{i};
    tok = regexp(nm, pat, 'tokens', 'once');
    if isempty(tok), continue; end
    measure = tok{1};
    region  = tok{2};
    side    = tok{3};
    hasSul  = endsWith(nm, '_SUL_LOG');
    key = sprintf('%s|%s|%d', measure, region, hasSul);

    if ~isKey(pairs, key)
        s = struct('measure',measure,'region',region,'suffix',hasSul,'L','','R','');
    else
        s = pairs(key);
    end

    if strcmpi(side,'Left'),  s.L = nm; else, s.R = nm; end
    pairs(key) = s;
end

created = {};
keys_ = pairs.keys;
for k = 1:numel(keys_)
    s = pairs(keys_{k});
    if isempty(s.L) || isempty(s.R), continue; end

    L = T.(s.L);
    R = T.(s.R);

    ai = azvpet.ai.compute_ai(L, R, opts.method);

    if s.suffix
        newName = sprintf('%s_%s_%s_SUL_LOG', opts.prefix, s.measure, s.region);
    else
        newName = sprintf('%s_%s_%s', opts.prefix, s.measure, s.region);
    end

    T.(newName) = ai;
    created{end+1} = newName; %#ok<AGROW>
end

info = struct('numPairs', numel(keys_), 'created', {created}, 'method', opts.method);
end
