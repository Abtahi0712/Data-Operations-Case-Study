SELECT 'ehr_encounters' AS tbl, COUNT(*) AS n_rows FROM ehr_encounters
UNION ALL SELECT 'db_encounters', COUNT(*) FROM db_encounters
UNION ALL SELECT 'ehr_codes',     COUNT(*) FROM ehr_codes
UNION ALL SELECT 'db_codes',      COUNT(*) FROM db_codes;


SELECT MIN(dos), MAX(dos) FROM ehr_encounters;