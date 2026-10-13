DROP TABLE IF EXISTS flag_codes;

-- Step 1: Codes in the EHR that are NEVER in the DB--

CREATE TABLE flag_codes AS 
SELECT cpt, COUNT(*) AS ehr_encounters
FROM ehr_codes
WHERE cpt NOT IN (SELECT cpt FROM db_codes WHERE cpt is not NULL)
GROUP BY cpt;


select * from flag_codes
ORDER BY ehr_encounters DESC;

