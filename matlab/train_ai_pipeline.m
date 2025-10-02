% TRAIN_AI_PIPELINE  Minimální trénink AI modelů pro celý dataset.
% 1) Načte CSV s kohortou (stejný jako v původním projektu)
% 2) Zajistí SUL_LOG (pokud používáš), spočte AI_* sloupce
% 3) Fitne lineární modely a uloží do models/ai_models.mat

cohortCsv = './data/processed/region_means_whole_cohort_merged.csv'; % uprav dle repa
outMat    = './models/ai_models.mat';

T = readtable(cohortCsv);

% Pokud používáš SUL_LOG z původního projektu:
% doseOpts = struct(); % doplň dle potřeby
% [T,~] = azvpet.features.ensureSUL_LOG(T, 'ANY_REGION_BASE', doseOpts); % případně již hotovo

[T, info] = azvpet.ai.ensure_ai_columns(T, struct('method','fracdiff'));
fprintf('Created %d AI columns\n', numel(info.created));

M = azvpet.ai.train_ai_models(T, 'Covariates', {'Age','Sex','BMI','lDose','lTime'});
if ~exist('./models','dir'), mkdir('./models'); end
save(outMat, 'M', '-v7.3');
fprintf('Saved models to %s\n', outMat);
