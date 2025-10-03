function [T, created, missing] = ensure_ai_from_sul_log_sided(T, baseNamesSided, varargin)
% ENSURE_AI_FROM_SUL_LOG_SIDED
% Deterministicky vytvoří AI nad SUL_LOG pro ZADANÉ baseNames se stranou.
% baseNamesSided: cellstr/string, např. {"Median_Fusiform_Right", "Median_Caudal_Anterior_Cingulate_Left", ...}
%
% Pro každý '..._(Left|Right)' se zkonstruuje dvojice:
%   Lvar = <stem>_Left_SUL_LOG
%   Rvar = <stem>_Right_SUL_LOG
% a vytvoří se cíl:
%   AI_<stem>_SUL_LOG     (bez laterality)
%
% Volitelné:
%   'Method'      = 'fracdiff' (default) | 'logratio'
%   'Prefix'      = 'AI'        (default)
%   'MetricSuffix'= '_SUL_LOG'  (default, NEMĚNIT pro tento projekt)
%
% Výstup:
%   created : cellstr se jmény nově vytvořených AI proměnných
%   missing : struct array s položkami (.stem, .missingVar), když chybí L/R vstup

p = inputParser;
addParameter(p,'Method','fracdiff');
addParameter(p,'Prefix','AI');
addParameter(p,'MetricSuffix','_SUL_LOG');
parse(p, varargin{:});
method       = p.Results.Method;
prefix       = string(p.Results.Prefix);
metricSuffix = string(p.Results.MetricSuffix);

if isstring(baseNamesSided) || ischar(baseNamesSided)
    baseNamesSided = cellstr(string(baseNamesSided));
end
baseNamesSided = unique(baseNamesSided, 'stable');

vnames  = string(T.Properties.VariableNames);
created = {};
missing = struct('stem',{},'missingVar',{});

for i = 1:numel(baseNamesSided)
    b = string(baseNamesSided{i}); % např. "Median_Fusiform_Right"
    % striktně vyžadujeme suffix _Left/_Right na konci názvu (bez metrického sufixu)
    if endsWith(b, "_Left")
        stem = extractBefore(b, strlength(b) - strlength("_Left") + 1);
    elseif endsWith(b, "_Right")
        stem = extractBefore(b, strlength(b) - strlength("_Right") + 1);
    else
        error('Base name "%s" neobsahuje laterality suffix "_Left" ani "_Right".', b);
    end

    Lvar = stem + "_Left"  + metricSuffix;   % např. Median_Fusiform_Left_SUL_LOG
    Rvar = stem + "_Right" + metricSuffix;   % např. Median_Fusiform_Right_SUL_LOG
    Avar = prefix + "_" + stem + metricSuffix; % AI_Median_Fusiform_SUL_LOG

    haveL = any(vnames == Lvar);
    haveR = any(vnames == Rvar);

    if ~haveL || ~haveR
        % přesně nahlásíme, co chybí
        if ~haveL
            missing(end+1) = struct('stem',stem, 'missingVar',char(Lvar)); %#ok<AGROW>
        end
        if ~haveR
            missing(end+1) = struct('stem',stem, 'missingVar',char(Rvar)); %#ok<AGROW>
        end
        continue; % tento stem nepočítáme
    end

    if ~any(vnames == Avar)
        L = T.(char(Lvar));
        R = T.(char(Rvar));
        T.(char(Avar)) = azvpet.ai.compute_ai(L, R, method);
        created{end+1} = char(Avar); %#ok<AGROW>
        vnames = string(T.Properties.VariableNames); % refresh
    end
end
end
