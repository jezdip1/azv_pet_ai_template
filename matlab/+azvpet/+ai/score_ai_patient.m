function R = score_ai_patient(Tp, M, varargin)
% SCORE_AI_PATIENT  Vyhodnotí pacienta vůči AI modelům.
% Volitelně: 'ZThresh', 2.58 (≈99% PI)

p = inputParser;
addParameter(p,'ZThresh', 2.58);
parse(p, varargin{:});
zthr = p.Results.ZThresh;

mdlNames = fieldnames(M.models);
rows = [];

for i = 1:numel(mdlNames)
    yname = mdlNames{i};
    m = M.models.(yname);
    preds = m.predictors;
    if ~all(ismember(preds, Tp.Properties.VariableNames)) || ~ismember(yname, Tp.Properties.VariableNames)
        continue;
    end

    Xp = Tp(1, preds);
    % kategorizace
    for v = 1:width(Xp)
        if iscellstr(Xp{:,v}) || isstring(Xp{:,v})
            Xp{:,v} = categorical(Xp{:,v});
        end
    end

    yobs = Tp.(yname)(1);
    yhat = predict(m.mdl, Xp);
    resid = yobs - yhat;
    z = resid ./ m.RMSE;

    out = struct;
    out.Variable = yname;
    out.Yobs = yobs;
    out.Yhat = yhat;
    out.Resid = resid;
    out.Z = z;
    out.Flag_OutOfRange = abs(z) > zthr;
    rows = [rows; out]; %#ok<AGROW>
end

if isempty(rows)
    R = table();
else
    R = struct2table(rows);
end
end
