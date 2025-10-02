function R = classify_ai_from_bundle_ai(csvPath, modelsMat)
% CLASSIFY_AI_FROM_BUNDLE_AI  Z CSV (nový pacient) spočte AI a vyhodnotí vůči modelům.

Tp = readtable(csvPath);
[Tp,~] = azvpet.ai.ensure_ai_columns(Tp, struct('method','fracdiff'));

S = load(modelsMat, 'M'); M = S.M;
R = azvpet.ai.score_ai_patient(Tp, M, 'ZThresh', 2.58);

% volitelně ulož výstup
outDir = './reports/new_patients_ai';
if ~exist(outDir,'dir'), mkdir(outDir); end
[~,base,~] = fileparts(csvPath);
writetable(R, fullfile(outDir, base + "_ai_eval.csv"));
end
