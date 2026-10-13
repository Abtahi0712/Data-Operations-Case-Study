=====================================================================
PASTE EACH BLOCK INTO ONE "Text" COMPONENT (Inspector → Value)
=====================================================================

########## TAB: Summary ##########
## Central Operations Case Study
**Abtahi Bin Jahangir Chowdhury** · Data Operations Analyst candidate

**Approach used for every problem:** Understand → Get the data → Find the pattern (rates, not counts) → Group & rank → Fix the largest group → Measure

| Problem | Finding | Impact | Recommendation |
|---|---|---|---|
| **P2 – Missing encounters** | Import filter blocks visits with non-CPT flag codes (NORCM, SP, TOS): 98.6% missing vs 1.2% | 282 of 6,612 encounters (4.26%) not imported | Confirm flags with client, review queue, daily EHR-vs-Normandy check |
| **P4 – Debugging revenue** | A: location indexes (GPCI) · B: multiple-procedure reduction · C: wrong units | Claim C billed G0283 ×3 and missed a timed unit | Bill 97110 ×2, 97112 ×2, G0283 ×1 → $114.71 (+29%) |
| **P1 – Workers' Comp** | Team blocked while pulling data / formatting PDF | 450 claims/day not sent (2,250/week) | Sample 100 stuck claims, fix the biggest reason first |
| **P3 – Claim not found** | Claims the insurer never received or cannot match | 10,000 claims (~$1M, assumption) | Group by insurer, age, $; sample; fix in groups; daily no-response check |


########## TAB: P2 Encounters – insight box (bottom) ##########
**Root cause:** 205 of 282 missing encounters (72.7%) contain a non-CPT flag code (NORCM, SP, TOS). These are missing **98.6%** of the time vs **1.2%** for normal encounters → the import filter blocks them. *(Assumption: NORCM = "No RCM", SP = self-pay, TOS = paid at time of service.)*

**Other causes:** patient-level blocks 55 (19.5%, e.g. Layla Brown 20, Carter Lee 15) · isolated gaps 13 · provider mismatch 8 · date mismatch 1.

**Risks:** 202 of 208 flagged encounters also contain billable CPT codes · 3 flagged encounters were imported (inconsistent filter) · 108 encounters stored twice in the DB.

**Fix:** confirm flag codes with the client → send flagged visits with billable codes to a review queue → fix setup for blocked patients.
**Monitor:** daily EHR-vs-Normandy check; alert if a non-excluded encounter is missing > 48 h (target < 0.5%).


########## TAB: P4 Revenue ##########
## Problem 4 – Debugging Revenue
**Medicare payment = (Work RVU × Work GPCI + PE RVU × PE GPCI + MP RVU × MP GPCI) × Conversion Factor** (CY2023 CF = $33.8872)

### Part A – 97110 costs more in Alaska than Mississippi
| Locality | GPCI (Work / PE / MP) | Work | PE | MP | Total RVU | Payment |
|---|---|---|---|---|---|---|
| Alaska (0210201) | 1.500 / 1.100 / 0.603 | 0.675 | 0.462 | 0.006 | 1.143 | **$38.73** |
| Mississippi (0730200) | 1.000 / 0.847 / 0.720 | 0.450 | 0.356 | 0.007 | 0.813 | **$27.55** |

Same code, same RVUs, same CF – only the GPCIs differ (Alaska has a legislated work GPCI floor of 1.5).

### Part B – 97140 paid ~$20 in a 4-code claim vs ~$40 alone
| Code (2023) | Work | PE | MP | In claim #1 |
|---|---|---|---|---|
| 97112 | 0.50 | **0.50 (highest)** | 0.01 | Paid in full |
| 97110 | 0.45 | 0.42 | 0.01 | PE reduced 50% |
| 97140 | 0.43 | 0.37 | 0.01 | PE reduced 50% |
| G0283 | 0.18 | 0.17 | 0.01 | PE reduced 50% |

Multiple Procedure Payment Reduction (MPPR): 97140 alone $27.45 → in claim $21.18 (−23%). Aetna applies the same therapy rule; its deeper cut is an assumption to confirm from the remittance reason code (CARC 59). Not an error.

### Part C – 8-minute rule
| Code | Billed | Correct | Why |
|---|---|---|---|
| 97110 | 2 | 2 | 38 min = 2 full units + 8 min left |
| 97112 | 1 | **2** | 24 min = 1 full unit + 9 min left → gets the extra unit |
| G0283 | 3 | **1** | Untimed code → 1 unit per visit |

62 timed minutes = 4 units. **As submitted $107.59** (incl. $18.64 not allowed) · **compliant original $88.95** · **recommended $114.71 (+29%)**.


########## TAB: P1 Workers' Comp ##########
## Problem 1 – Workers' Compensation Claims
**Target 500/day · Completed 50/day · Stuck 450/day (2,250/week)** · *Assumption: ~$100/claim → ~$45k/day delayed*

**Process:** 1. Pull data → 2. Fill & format PDF → 3. Upload → 4. Vendor mails. **The team gets stuck at steps 1–2**, before the vendor.

| Question | Answer |
|---|---|
| 1. Diagnose | Log 100 stuck claims (step + reason) → group → Pareto → fix the biggest reason |
| 2. Tool fix | Check required WC fields before creating the PDF, clear error messages, auto-fill known data, error log |
| 3. Workflow fix | 1-page checklist, 30-min training, "stuck" queue with a reason |
| 4. Other causes | WC info never captured by the clinic / never pulled in (fix upstream); upload rejects the file |
| 5. Metrics | Completions/day (500), % without getting stuck (>90%), stuck by reason, minutes per claim; after fix: vendor mailing time, days to payment |

| Period | India team (20) | Mountain View (3) | Engineer (2 h/week) |
|---|---|---|---|
| Days 1–3 | 2 ops log 100 stuck claims; others keep working | 1 op reviews sample, calls top WC insurers | Reads tool error logs |
| Week 1 | Checklist + stuck queue | Runs training | Fixes #1 tool issue |
| Weeks 2–4 | Full volume | Reviews weekly Pareto | Fixes next issue |

After the fix ~12 operators handle 500/day (assumption: 10 min/claim) → ~8 freed for P3.


########## TAB: P3 Claim Not Found ##########
## Problem 3 – Reconciliation: "Claim Not Found"
**10,000 claims · 150 insurers · ~$1M at risk (assumption) · ~4 weeks to clear**

**Steps:** 1. Put all claims in one table → 2. Group & count by insurer, age, amount → 3. Sample ~20 per top-5 insurer and find why → 4. Fix in groups → 5. Daily check

| What we found | Action |
|---|---|
| Never sent | Submit it |
| Wrong insurer or ID | Correct and resubmit |
| Past deadline, with proof of timely submission | Appeal with the proof |
| Small amount that cannot be recovered | Write off |

**Capacity (assumption):** 8 India operators × 6 h × 6 claims/h = 288/day → ~35 working days one-by-one, **~21 days** if 40% fixed in groups.
**Prevention:** daily list of claims with no insurer response after 7 days · validate insurer + patient ID before sending · weekly "not found" count by insurer.


########## QUERY Q10_missing_list_Task1 (simple version, no dropdown) ##########
SELECT patient, dos AS date_of_service, provider, cpt_codes, reason
FROM p2_encounters
WHERE status = 'Missing'
ORDER BY reason, patient, dos;
