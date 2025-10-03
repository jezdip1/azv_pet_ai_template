# AZV PET AI Template

**Normative modelling of FDG-PET brain asymmetry indexes (AI)**  
This branch focuses exclusively on **asymmetry indexes** (left vs right homologous regions).  
We derive asymmetry from normalized **SUL_LOG** values and fit statistical models to quantify typical patterns across age, sex, and acquisition parameters.

> ⚠️ Research prototype, not a medical device.

---

## Why asymmetry indexes?

- PET intensities can vary across scanners, patients, or global uptake.  
- Left/right asymmetry is more robust: each patient is their own control.  
- This makes deviations in focal epilepsy or neurodegeneration more detectable.  

Asymmetry Index (AI) is computed as:  
\[
AI = \frac{X_{Left} - X_{Right}}{(X_{Left} + X_{Right})/2}
\]

We apply this after SUL normalization and log-transform (`SUL_LOG`).

---

## Data processing

1. **Input data**: same cohort as before (~420 PETs).  
2. **Normalization**: affine MNI alignment, parcellation with CerebrA, thresholding < 5000 → NaN.  
3. **SUL + log transform**: values standardized per lean body mass and log-transformed.  
4. **Asymmetry computation**: for each bilateral parcel, compute AI from median SUL_LOG.  
5. **Tabulation**: build cohort-wide AI tables for modelling.

---

## Statistical model

We fit linear mixed models for each asymmetry index:

```
AgeR1 + AgeR2 + AgeR3 + AgeR4 + Sex + BMI + lTime + lDose +
logVoxelVol + logAcqDur_s + HasTOF + HasPSF + Subsets + FilterFWHM_mm +
MMI_to_MNIGMS + NCC_to_MNIGMS + Sex:cAge + lDose:lTime + (1|UNIS)
```

**Notes:**  
- `GlobalRefPC1_z` is dropped (no longer needed).  
- Age is modeled with **restricted cubic splines** (4 df).  
- Centering is applied consistently as in the previous pipeline.  
- Random intercept `(1|UNIS)` adjusts for scanner/site differences.

---

## Example region: Insula (AI of median SUL_LOG)

- **Age effect with CI & PI**  
  ![Age effect](docs/img/AI_Median_Insula_SUL_LOG_age_effect.png)

- **Calibration**  
  ![Calibration](docs/img/AI_Median_Insula_SUL_LOG_calibration.png)

- **Partial residuals**  
  ![Partial residuals](docs/img/AI_Median_Insula_SUL_LOG_partial_resid.png)  
  ![Spline fit](docs/img/AI_Median_Insula_SUL_LOG_partial_resid_fitted.png)

- **Predicted vs Observed (LOO)**  
  ![Pred vs Obs](docs/img/AI_Median_Insula_SUL_LOG_pred_vs_obs.png)

- **Residuals vs Age**  
  ![Z vs Age](docs/img/AI_Median_Insula_SUL_LOG_zscore_vs_age.png)

**Interpretation**  
- Insula AI is generally stable (R²m ≈ 0.64).  
- Model captures age/sex effects, but inter-individual spread remains wide.  
- PIs are broader than CIs → asymmetry has higher variability than absolute uptake.  

---

## Stability across regions

Based on `summary.json`:

- **High stability** (R²m > 0.8):  
  - *Middle Temporal* (0.82)  
  - *Superior Parietal* (0.81)  
  - *Inferior Parietal* (0.76)

- **Moderate stability** (0.5–0.7):  
  - *Insula* (0.64)  
  - *Lateral Orbitofrontal* (0.67)  
  - *Rostral Middle Frontal* (0.73)

- **Low stability** (< 0.3):  
  - *Basal Forebrain* (0.27)  
  - *Optic Chiasm* (0.11)  
  - *Third Ventricle* (0.19)

**Take-home**: Cortical association areas show the most reproducible asymmetry; small deep structures are noisy.

---

## Classifying a new patient (AI mode)

### Step 1: Prepare input
- Input table same as before, but including **AI columns** (computed per bilateral region).  
- Covariates centered by training cohort means.  
- PCA is not needed.

### Step 2: Predict
For each AI region, the model outputs mean prediction, CI, PI, z-score, and outlier flags.

Example JSON output (Postcentral AI):  
```json
{
  "Pred_orig": 1.0033,
  "CI_orig": [0.9915, 1.0004],
  "PI_orig": [0.9839, 1.0232],
  "z": -0.93,
  "p_two_sided": 0.353,
  "is_outlier_95": false,
  "is_outlier_99": false
}
```

### Step 3: Visualize

- **Boxplot (matched controls)**  
  ![Box matched](docs/img/AI_Median_Postcentral_SUL_LOG_box_matched.png)

- **Boxplot (model)**  
  ![Box model](docs/img/AI_Median_Postcentral_SUL_LOG_box_model.png)

---

## Summary

- AI modelling offers a **complementary perspective** to absolute uptake.  
- Variability is higher, but systematic asymmetries (e.g., temporal lobe) are well captured.  
- Classification outputs z-scores and summary plots analogous to the absolute model.  
- **Caution:** small structures yield unstable AIs; interpret only consistent cortical signals.

---

## License

MIT

---
