function S = classify_from_bundle_ai(new_csv, out_root, varargin)
% Klasifikace nových vyšetření vůči AI-LMEM modelům.
% Flow: load → ensure covariates → ensure SUL_LOG(L/R) → compute AI → sanitize → predict+report
%
% Volitelné:
%   'BundleFile' - path k AI bundle (default './models_ai/trained_bundle_ai.mat' pokud existuje,
%                  jinak './models/_globals/trained_bundle.mat')

azvpet.util.check_requirements();

% --- cesty & config
cfg = jsondecode(fileread('./config/model_config.json'));

% argumenty
p = inputParser;
addParameter(p,'BundleFile','');
parse(p, varargin{:});
bundleFile = string(p.Results.BundleFile);

% default bundle (preferuj AI specifický soubor)
if bundleFile == ""
    if isfile('./models/_globals/trained_bundle_ai.mat')
        bundleFile = './models/_globals/trained_bundle_ai.mat';
    else
        % bundleFile = './models/_globals/trained_bundle.mat';
    end
end
if ~isfile(bundleFile), error('Nenalezen bundle "%s". Spusť train_ai_pipeline.', bundleFile); end

% Načti bundle (AI modely)
B = load(bundleFile,'M','info','cal','nameMap','metaCov');
M = B.M; info = B.info; cal = B.cal; nameMap = B.nameMap;
muAge_tr   = B.metaCov.muAge;
AgeR_knots = B.metaCov.AgeR_knots;

% --- GUARD: bundle musí být AI (responses začínají "AI_")
resp_clean = string(info.responses(:));
if isempty(resp_clean) || ~all(startsWith(resp_clean, "AI_"))
    error(['Načtený bundle není AI bundle.\n' ...
           'První response: "%s".\n' ...
           'Ujisti se, že používáš výstup z train_ai_pipeline (např. models_ai/trained_bundle_ai.mat).'], ...
           resp_clean(1));
end

% --- načti nová data se zachováním ORIG hlaviček
Tnew0 = readtable(new_csv, 'VariableNamingRule','preserve');

% --- stejné kovariáty / spline uzly / centrování jako v tréninku
covOpts = struct( ...
  'lbmVersion',   'James', ...
  'ageKnotsFile', '', ...
  'AgeR_knots',   AgeR_knots, ...
  'muAge',        muAge_tr, ...
  'refs',         string(cfg.global_ref.refs), ...
  'doseVar',      'InjectedDose_MBq', ...
  'doseMultiplier', 1, ...
  'params_dir',   './models/_globals', ... % PC1z se nevyužije, ale ať je kompatibilita
  'mode','predict'...
);
[Tnew0, ~] = azvpet.features.ensure_model_covariates(Tnew0, covOpts);

% --- STEMy (bez laterality) z AI responses: 'AI_Median_X_SUL_LOG' -> 'Median_X'
stems_clean = regexprep(resp_clean, '^AI_','');
stems_clean = regexprep(stems_clean, '_SUL_LOG$','');
stems_clean = regexprep(stems_clean, '_(Left|Right)$',''); % pojistka

% --- SANITY mapování CLEAN -> ORIG stem přes nameMap (kvůli pomlčkám ap.)
orig_from_clean_full = containers.Map(string(nameMap.clean), string(nameMap.orig));
stems_orig = strings(size(stems_clean));
for i = 1:numel(stems_clean)
    c_full = "AI_" + stems_clean(i) + "_SUL_LOG";
    if isKey(orig_from_clean_full, c_full)
        o_full = string(orig_from_clean_full(c_full));
        o = regexprep(o_full, '^AI_', '');
        o = regexprep(o, '_SUL_LOG$','');
        o = regexprep(o, '_(Left|Right)$','');
        stems_orig(i) = o;
    else
        stems_orig(i) = stems_clean(i);
    end
end

% --- zajisti *_SUL_LOG pro všechny L/R báze (deterministicky, z ORIG stemů)
doseOpts = struct('doseVar','InjectedDose_MBq','multiplier',1,'lbmVersion','James');
bases_orig_sided = unique([stems_orig + "_Left"; stems_orig + "_Right"]);
[Tnew0, ~] = azvpet.features.ensureSUL_LOG(Tnew0, cellstr(bases_orig_sided), doseOpts);

% --- referenční regiony (pro jistotu)
if isfield(cfg,'global_ref') && isfield(cfg.global_ref,'metric_suffix') ...
   && strcmpi(cfg.global_ref.metric_suffix,'_SUL_LOG')
  for r = string(cfg.global_ref.refs).'
    [Tnew0, ~] = azvpet.features.ensureSUL_LOG(Tnew0, char(r), doseOpts);
  end
end

% --- spočti AI nad SUL_LOG deterministicky podle ORIG stemů
[Tnew0, createdAI, missingAI] = azvpet.ai.ensure_ai_from_sul_log_sided( ...
    Tnew0, cellstr(bases_orig_sided), 'Method','fracdiff', 'Prefix','AI', 'MetricSuffix','_SUL_LOG');

% sanity: musí vzniknout všechny AI, které model očekává
missing_needed = setdiff(resp_clean, string(createdAI));
if ~isempty(missing_needed)
    warning('[AI] Některé očekávané AI chybí a budou NaN. Např.: %s', missing_needed(1));
end
if ~isempty(missingAI)
    fprintf('[AI][WARN] Chybějící vstupy pro AI (L/R):\n');
    for k = 1:numel(missingAI)
        fprintf('  stem=%s  missing=%s\n', missingAI(k).stem, missingAI(k).missingVar);
    end
end

% --- sjednoť názvy (CLEAN) stejně jako při tréninku
optsSan = struct('grouping','UNIS','response_list',{cellstr(resp_clean)});
[Tnew, ~, optsSan] = azvpet.util.ensure_valid_varnames(Tnew0, optsSan);

% === GUARD: ověř, že všechny modelové responses existují v Tnew
have = ismember(resp_clean, string(Tnew.Properties.VariableNames));
if ~all(have)
    miss = resp_clean(~have);
    error('V Tnew chybí očekávané AI proměnné (CLEAN): např. "%s".', miss(1));
end

% --- zarovnej hladiny kategorií podle prvního modelu (Sex, scanner, …)
km = keys(M);
firstKey = km{1};
Lany  = M(firstKey);
Train = Lany.Variables;
vnames = intersect(Tnew.Properties.VariableNames, Train.Properties.VariableNames);

for j = 1:numel(vnames)
  v = vnames{j};
  if iscategorical(Train.(v))
    levTrain = categories(Train.(v));
    if ~iscategorical(Tnew.(v))
        Tnew.(v) = categorical(string(Tnew.(v)));
    end
    allLevels = union(levTrain, categories(Tnew.(v)), 'stable');
    Tnew.(v) = setcats(Tnew.(v), allLevels);
    newOnly  = setdiff(categories(Tnew.(v)), levTrain, 'stable');
    Tnew.(v) = reordercats(Tnew.(v), [levTrain; newOnly]);
  end
end

% --- výstupní složka
if ~exist(out_root,'dir'), mkdir(out_root); end

% --- klasifikace po řádcích
S = struct('cases',[]);
for i = 1:height(Tnew)
  row = Tnew(i,:);
  sid = "<undefined>";
  if ismember('UNIS', row.Properties.VariableNames)
    sid = string(row.UNIS); sid = sid(1);
  end
  if ismissing(sid) || strlength(sid)==0, sid = sprintf("row_%04d", i); end
  outdir = fullfile(out_root, safe_fname(sid));
  if ~exist(outdir,'dir'), mkdir(outdir); end

  S_case = report_new_patient_all_regions([], row, info, M, cal, outdir);
  S.cases = [S.cases; struct('id',char(sid), 'summary',S_case.summary_table, ...
              'csv',S_case.csv,'json',S_case.json,'zplot',S_case.z_plot)];
end

fprintf('[OK] Classified %d new rows (AI) with bundle "%s" -> %s\n', height(Tnew), bundleFile, out_root);
end

function s = safe_fname(txt)
s = regexprep(char(string(txt)),'[^A-Za-z0-9\-]+','_');
end
