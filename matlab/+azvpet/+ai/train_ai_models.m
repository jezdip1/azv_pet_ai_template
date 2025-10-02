function M = train_ai_models(T, varargin)
% TRAIN_AI_MODELS  Natrénuje lineární model pro všechny AI_* sloupce.
% Volitelně: 'Covariates', {'Age','Sex','BMI','lDose','lTime'} (použijí se jen existující)
%            'ZExclude'  true/false  – odstranit zjevné outliery (|z|>4) před fitem (default=false)

p = inputParser;
addParameter(p,'Covariates', {'Age','Sex','BMI','lDose','lTime'});
addParameter(p,'ZExclude', false);
parse(p, varargin{:});
covarsWanted = p.Results.Covariates;

names = T.Properties.VariableNames;
aiVars = names(startsWith(names, 'AI_'));

M = struct;
M.meta = struct('covarsWanted',{covarsWanted}, 'date', datestr(now), 'type','AI-linear');

for i = 1:numel(aiVars)
    yname = aiVars{i};
    presentCov = covarsWanted(ismember(covarsWanted, names));
    X = T(:, presentCov);
    y = T.(yname);

    % vyhoď řádky s NaN v y nebo prediktorech
    ok = ~isnan(y);
    for c = 1:width(X)
        ok = ok & ~isnan(X{:,c});
    end
    X = X(ok,:); y = y(ok);

    % volitelně odříznout extrémy
    if p.Results.ZExclude && numel(y)>10
        z = (y - mean(y)) ./ std(y);
        keep = abs(z) <= 4;
        X = X(keep,:); y = y(keep);
    end

    if isempty(presentCov)
        mdl = fitlm(y); %#ok<NASGU>
        formula = 'AI ~ 1';
        mdl = fitlm(table(y,'VariableNames',{'AI'}), 'AI ~ 1');
    else
        tbl = [table(y,'VariableNames',{'AI'}) X];
        % kategorizuj string/char proměnné
        vnames = tbl.Properties.VariableNames;
        for v = 2:numel(vnames)
            if iscellstr(tbl.(vnames{v})) || isstring(tbl.(vnames{v}))
                tbl.(vnames{v}) = categorical(tbl.(vnames{v}));
            end
        end
        formula = ['AI ~ 1 + ' strjoin(presentCov, ' + ')];
        mdl = fitlm(tbl, formula);
    end

    M.models.(yname).formula = formula;
    M.models.(yname).predictors = presentCov;
    M.models.(yname).coeffs = mdl.Coefficients;
    M.models.(yname).RMSE = mdl.RMSE;
    M.models.(yname).R2 = mdl.Rsquared.Ordinary;
    M.models.(yname).n = mdl.NumObservations;
    M.models.(yname).mdl = mdl;  % můžeš uložit i celý model (větší .mat)
end
end
