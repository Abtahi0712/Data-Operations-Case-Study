/* =====================================================================
   PROBLEM 2 – DASHBOARD QUERIES
   In your Retool app: one query per block, resource = Retool Database, SQL.
   Name each query with the name after ▶  (format: Q<number>_<name>_<Task>)
   Retool names allow only letters, numbers and _ (no spaces or brackets).
   ===================================================================== */

-- ▶ Q1_kpis_reconciliation_Task1   (Task 1 – reconciliation: total = imported + missing)
SELECT COUNT(*)                                                                    AS ehr_encounters,
       SUM(CASE WHEN status = 'Imported' THEN 1 ELSE 0 END)                        AS imported,
       SUM(CASE WHEN status = 'Missing'  THEN 1 ELSE 0 END)                        AS missing,
       ROUND(100.0 * SUM(CASE WHEN status = 'Missing' THEN 1 ELSE 0 END) / COUNT(*), 2) AS missing_pct,
       SUM(CASE WHEN status = 'Missing' AND has_flag = 'No' THEN 1 ELSE 0 END)     AS true_leakage
FROM p2_encounters;


-- ▶ Q2_flag_vs_normal_rate_Task2   (Task 2 – KEY TEST: missing rate with vs without a flag code)
SELECT CASE WHEN has_flag = 'Yes' THEN 'Has flag code (NORCM/SP/TOS)'
            ELSE 'Real CPT codes only' END                             AS segment,
       COUNT(*)                                                        AS encounters,
       SUM(CASE WHEN status = 'Missing' THEN 1 ELSE 0 END)             AS missing,
       ROUND(100.0 * SUM(CASE WHEN status = 'Missing' THEN 1 ELSE 0 END) / COUNT(*), 1) AS missing_rate_pct
FROM p2_encounters
GROUP BY has_flag
ORDER BY missing_rate_pct DESC;


-- ▶ Q3_missing_by_reason_Task2   (Task 2 – missing visits by reason; window function for the % share)
SELECT CASE
         WHEN reason LIKE 'Non-billable%'  THEN 'Flag code'
         WHEN reason LIKE 'Patient-level%' THEN 'Patient block'
         WHEN reason LIKE 'Isolated%'      THEN 'Isolated gap'
         WHEN reason LIKE 'Rendering%'     THEN 'Provider mismatch'
         WHEN reason LIKE 'Date%'          THEN 'Date mismatch'
         ELSE reason
       END                                                 AS reason_short,
       COUNT(*)                                            AS encounters,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)  AS pct_of_missing
FROM p2_encounters
WHERE status = 'Missing'
GROUP BY reason
ORDER BY encounters DESC;


-- ▶ Q4_flag_codes_list_Task2   (Task 2 – the non-CPT codes that never reach the DB)
SELECT cpt AS flag_code, ehr_encounters
FROM flag_codes
ORDER BY ehr_encounters DESC;


-- ▶ Q5_rate_by_cpt_Task2   (Task 2 – missing rate per code, codes on 20+ visits)
SELECT c.cpt,
       COUNT(*)                                                 AS encounters,
       SUM(CASE WHEN p.status = 'Missing' THEN 1 ELSE 0 END)    AS missing,
       ROUND(100.0 * SUM(CASE WHEN p.status = 'Missing' THEN 1 ELSE 0 END) / COUNT(*), 1) AS missing_rate_pct
FROM ehr_codes c
JOIN p2_encounters p
  ON  p.patient  = c.patient
  AND p.provider = c.provider
  AND p.dos      = DATE(c.dos)
GROUP BY c.cpt
HAVING COUNT(*) >= 20
ORDER BY missing_rate_pct DESC;


-- ▶ Q6_rate_by_month_Task2   (Task 2 – per month: flag-code misses vs other misses)
SELECT month,
       SUM(CASE WHEN status = 'Missing' AND has_flag = 'Yes' THEN 1 ELSE 0 END) AS missing_flag_code,
       SUM(CASE WHEN status = 'Missing' AND has_flag = 'No'  THEN 1 ELSE 0 END) AS missing_other,
       ROUND(100.0 * SUM(CASE WHEN status = 'Missing' AND has_flag = 'No' THEN 1 ELSE 0 END)
                   / SUM(CASE WHEN has_flag = 'No' THEN 1 ELSE 0 END), 2)       AS leakage_rate_pct
FROM p2_encounters
GROUP BY month
ORDER BY month;


-- ▶ Q7_rate_by_provider_Task2   (Task 2 – missing rate by provider, flag-code visits excluded)
SELECT provider,
       COUNT(*)                                              AS encounters,
       SUM(CASE WHEN status = 'Missing' THEN 1 ELSE 0 END)   AS missing,
       ROUND(100.0 * SUM(CASE WHEN status = 'Missing' THEN 1 ELSE 0 END) / COUNT(*), 2) AS leakage_rate_pct
FROM p2_encounters
WHERE has_flag = 'No'
GROUP BY provider
ORDER BY leakage_rate_pct DESC;


-- ▶ Q8_top_patients_Task2   (Task 2 – patients with the most missing visits, flag-code visits excluded)
SELECT patient, COUNT(*) AS missing_visits
FROM p2_encounters
WHERE status = 'Missing' AND has_flag = 'No'
GROUP BY patient
ORDER BY missing_visits DESC
LIMIT 8;


-- ▶ Q9_partial_mismatches_Task2   (Task 2 – visits that are in the DB with a different provider or date)
SELECT patient, dos AS ehr_date, provider AS ehr_provider, db_provider, NULL AS db_date, 'Provider mismatch' AS type
FROM provider_mismatch
UNION ALL
SELECT patient, dos, provider, NULL, db_dos, 'Date mismatch'
FROM date_mismatch;


-- ▶ Q10_missing_list_Task1   (Task 1 deliverable – the 282 missing visits, filtered by the dropdown "selReason")
--   {{ }} is Retool: it inserts the value picked in the dropdown. Empty dropdown = show all.
   SELECT patient, dos AS date_of_service, provider, cpt_codes, reason
   FROM p2_encounters
   WHERE status = 'Missing'
   ORDER BY reason, patient, dos;
