/* =====================================================================
   PROBLEM 2 – Closed Encounters: Task 1 + Task 2 (PostgreSQL, basic SQL only)
   Input tables (from P2_Step1_Cleaning.ipynb):
     ehr_encounters, db_encounters  -> one row per visit
     ehr_codes, db_codes            -> one row per visit + code
   Part A builds the analysis tables. Part B answers Task 1 and Task 2.
   (Same logic as the Retool files: Retool/p2_retool_setup.sql + p2_retool_app_queries.sql)
   ===================================================================== */

/* ============================ PART A – BUILD ============================ */
-- STEP 0 – delete old versions so this file can be re-run
DROP TABLE IF EXISTS flag_codes;
DROP TABLE IF EXISTS flagged_visits;
DROP TABLE IF EXISTS p2_encounters;
DROP TABLE IF EXISTS db_only;
DROP TABLE IF EXISTS provider_mismatch;
DROP TABLE IF EXISTS date_mismatch;


-- STEP 1 – Codes that are in the EHR but NEVER in the DB  ("flag codes")
CREATE TABLE flag_codes AS
SELECT cpt, COUNT(*) AS ehr_encounters
FROM ehr_codes
WHERE cpt NOT IN (SELECT cpt FROM db_codes)
GROUP BY cpt;


-- STEP 2 – Visits that contain at least one flag code
CREATE TABLE flagged_visits AS
SELECT DISTINCT patient, provider, DATE(dos) AS dos
FROM ehr_codes
WHERE cpt IN (SELECT cpt FROM flag_codes);


-- STEP 3 – MAIN TABLE: every EHR visit + status (Task 1) + has_flag
CREATE TABLE p2_encounters AS
SELECT e.patient,
       e.provider,
       DATE(e.dos)                       AS dos,
       TO_CHAR(DATE(e.dos), 'YYYY-MM')   AS month,
       e.cpt_codes,
       e.n_codes,
       CASE WHEN d.patient IS NULL THEN 'Missing' ELSE 'Imported' END AS status,
       CASE WHEN f.patient IS NULL THEN 'No'      ELSE 'Yes'      END AS has_flag
FROM ehr_encounters e
LEFT JOIN db_encounters d                      -- Task 1: find the visit in the DB
       ON  d.patient     = e.patient
       AND d.provider    = e.provider
       AND DATE(d.dos)   = DATE(e.dos)
LEFT JOIN flagged_visits f                     -- does the visit have a flag code?
       ON  f.patient     = e.patient
       AND f.provider    = e.provider
       AND f.dos         = DATE(e.dos);


-- STEP 4 – DB visits with NO exact match in the EHR (reverse of Task 1)
CREATE TABLE db_only AS
SELECT d.patient, d.provider, DATE(d.dos) AS dos
FROM db_encounters d
LEFT JOIN ehr_encounters e
       ON  e.patient   = d.patient
       AND e.provider  = d.provider
       AND DATE(e.dos) = DATE(d.dos)
WHERE e.patient IS NULL;


-- STEP 5 – Missing visits that ARE in the DB, but under a DIFFERENT provider (same patient + same date)
CREATE TABLE provider_mismatch AS
SELECT p.patient, p.provider, p.dos, o.provider AS db_provider
FROM p2_encounters p
JOIN db_only o
  ON  o.patient = p.patient
  AND o.dos     = p.dos
WHERE p.status = 'Missing' AND p.has_flag = 'No';


-- STEP 6 – Missing visits that ARE in the DB, but with a date up to 7 days off (same patient + provider)
CREATE TABLE date_mismatch AS
SELECT p.patient, p.provider, p.dos, o.dos AS db_dos, ABS(p.dos - o.dos) AS days_apart
FROM p2_encounters p
JOIN db_only o
  ON  o.patient  = p.patient
  AND o.provider = p.provider
WHERE p.status = 'Missing' AND p.has_flag = 'No'
  AND ABS(p.dos - o.dos) <= 7;


-- STEP 7 – Give every visit ONE reason.
-- Each UPDATE only fills rows that are still empty (reason IS NULL),
-- so the ORDER of the updates = the priority.
ALTER TABLE p2_encounters ADD COLUMN reason TEXT;

UPDATE p2_encounters SET reason = 'Imported'
WHERE status = 'Imported';

UPDATE p2_encounters SET reason = 'Non-billable flag code (NORCM/SP/TOS)'
WHERE reason IS NULL AND has_flag = 'Yes';

UPDATE p2_encounters SET reason = 'Rendering provider mismatch'
WHERE reason IS NULL
  AND (patient, provider, dos) IN (SELECT patient, provider, dos FROM provider_mismatch);

UPDATE p2_encounters SET reason = 'Date of service mismatch'
WHERE reason IS NULL
  AND (patient, provider, dos) IN (SELECT patient, provider, dos FROM date_mismatch);

UPDATE p2_encounters SET reason = 'Patient-level block (run of visits)'
WHERE reason IS NULL
  AND patient IN (SELECT patient
                  FROM p2_encounters
                  WHERE status = 'Missing' AND has_flag = 'No'
                  GROUP BY patient
                  HAVING COUNT(*) >= 3);

UPDATE p2_encounters SET reason = 'Isolated gap (no pattern)'
WHERE reason IS NULL;


-- STEP 8 – CHECK: must return 6612 | 6330 | 282
SELECT COUNT(*)                                            AS ehr_encounters,
       SUM(CASE WHEN status = 'Imported' THEN 1 ELSE 0 END) AS imported,
       SUM(CASE WHEN status = 'Missing'  THEN 1 ELSE 0 END) AS missing
FROM p2_encounters;

/* ============================ PART B – ANSWERS ============================ */

-- TASK 1a – The list of missing visits (anti-join: LEFT JOIN + IS NULL)
SELECT e.patient, DATE(e.dos) AS date_of_service, e.provider, e.cpt_codes
FROM ehr_encounters e
LEFT JOIN db_encounters d
       ON  d.patient   = e.patient
       AND d.provider  = e.provider
       AND DATE(d.dos) = DATE(e.dos)
WHERE d.patient IS NULL
ORDER BY e.patient, e.dos;

-- TASK 1b + TASK 2 queries (same as the dashboard queries)
-- q_kpis   (Task 1 – reconciliation: total = imported + missing)
SELECT COUNT(*)                                                                    AS ehr_encounters,
       SUM(CASE WHEN status = 'Imported' THEN 1 ELSE 0 END)                        AS imported,
       SUM(CASE WHEN status = 'Missing'  THEN 1 ELSE 0 END)                        AS missing,
       ROUND(100.0 * SUM(CASE WHEN status = 'Missing' THEN 1 ELSE 0 END) / COUNT(*), 2) AS missing_pct,
       SUM(CASE WHEN status = 'Missing' AND has_flag = 'No' THEN 1 ELSE 0 END)     AS true_leakage
FROM p2_encounters;


-- q_flag_rate   (Task 2 – KEY TEST: missing rate with vs without a flag code)
SELECT CASE WHEN has_flag = 'Yes' THEN 'Has flag code (NORCM/SP/TOS)'
            ELSE 'Real CPT codes only' END                             AS segment,
       COUNT(*)                                                        AS encounters,
       SUM(CASE WHEN status = 'Missing' THEN 1 ELSE 0 END)             AS missing,
       ROUND(100.0 * SUM(CASE WHEN status = 'Missing' THEN 1 ELSE 0 END) / COUNT(*), 1) AS missing_rate_pct
FROM p2_encounters
GROUP BY has_flag
ORDER BY missing_rate_pct DESC;


-- q_reasons   (Task 2 – missing visits by reason; window function for the % share)
SELECT reason,
       COUNT(*)                                            AS encounters,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)  AS pct_of_missing
FROM p2_encounters
WHERE status = 'Missing'
GROUP BY reason
ORDER BY encounters DESC;


-- q_flag_codes   (Task 2 – the non-CPT codes that never reach the DB)
SELECT cpt AS flag_code, ehr_encounters
FROM flag_codes
ORDER BY ehr_encounters DESC;


-- q_code_rates   (Task 2 – missing rate per code, codes on 20+ visits)
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


-- q_month   (Task 2 – per month: flag-code misses vs other misses)
SELECT month,
       SUM(CASE WHEN status = 'Missing' AND has_flag = 'Yes' THEN 1 ELSE 0 END) AS missing_flag_code,
       SUM(CASE WHEN status = 'Missing' AND has_flag = 'No'  THEN 1 ELSE 0 END) AS missing_other,
       ROUND(100.0 * SUM(CASE WHEN status = 'Missing' AND has_flag = 'No' THEN 1 ELSE 0 END)
                   / SUM(CASE WHEN has_flag = 'No' THEN 1 ELSE 0 END), 2)       AS leakage_rate_pct
FROM p2_encounters
GROUP BY month
ORDER BY month;


-- q_provider   (Task 2 – missing rate by provider, flag-code visits excluded)
SELECT provider,
       COUNT(*)                                              AS encounters,
       SUM(CASE WHEN status = 'Missing' THEN 1 ELSE 0 END)   AS missing,
       ROUND(100.0 * SUM(CASE WHEN status = 'Missing' THEN 1 ELSE 0 END) / COUNT(*), 2) AS leakage_rate_pct
FROM p2_encounters
WHERE has_flag = 'No'
GROUP BY provider
ORDER BY leakage_rate_pct DESC;


-- q_patients   (Task 2 – patients with the most missing visits, flag-code visits excluded)
SELECT patient, COUNT(*) AS missing_visits
FROM p2_encounters
WHERE status = 'Missing' AND has_flag = 'No'
GROUP BY patient
ORDER BY missing_visits DESC
LIMIT 8;


-- q_mismatches   (Task 2 – visits that are in the DB with a different provider or date)
SELECT patient, dos AS ehr_date, provider AS ehr_provider, db_provider, NULL AS db_date, 'Provider mismatch' AS type
FROM provider_mismatch
UNION ALL
SELECT patient, dos, provider, NULL, db_dos, 'Date mismatch'
FROM date_mismatch;

-- Missing visits with their reason (export = p2_missing_encounters.csv)
SELECT patient, dos AS date_of_service, provider, cpt_codes, reason
FROM p2_encounters
WHERE status = 'Missing'
ORDER BY reason, patient, dos;
