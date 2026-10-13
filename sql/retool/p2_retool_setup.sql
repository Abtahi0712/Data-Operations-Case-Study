/* =====================================================================
   PROBLEM 2 – SETUP: build the analysis tables (run ONCE)
   Needs 4 tables uploaded from CSV:
     ehr_encounters, db_encounters   -> one row per visit
     ehr_codes,      db_codes        -> one row per visit + code
   DATE(dos) = keep only the date part (Retool stored dos as date + time)
   ===================================================================== */

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
