-- ▶ Q20_p4_partA_locality_P4   (Part A – stacked bar: payment split by RVU component)
SELECT 'Alaska (0210201)' AS locality, 22.87 AS work_usd, 15.66 AS pe_usd, 0.20 AS mp_usd, 38.73 AS total_usd
UNION ALL SELECT 'Mississippi (0730200)', 15.25, 12.06, 0.24, 27.55;

-- ▶ Q21_p4_partB_97140_P4   (Part B – 97140 alone vs inside the 4-code claim)
SELECT 'Billed alone' AS scenario, 27.45 AS payment_usd
UNION ALL SELECT 'Inside claim #1 (MPPR)', 21.18;

-- ▶ Q22_p4_partB_codes_P4   (Part B – PE treatment of each code in claim #1)
SELECT 1 AS n, '97112' AS cpt_code, 0.50 AS pe_rvu, 'Highest PE - paid in full' AS treatment
UNION ALL SELECT 2, '97110', 0.42, 'PE reduced 50%'
UNION ALL SELECT 3, '97140', 0.37, 'PE reduced 50%'
UNION ALL SELECT 4, 'G0283', 0.17, 'PE reduced 50%'
ORDER BY n;

-- ▶ Q23_p4_partC_units_P4   (Part C – 8-minute rule: billed vs correct units)
SELECT 1 AS n, '97110' AS cpt_code, 2 AS billed_units, 2 AS correct_units, 'Correct - 38 min = 2 units + 8 min left' AS issue
UNION ALL SELECT 2, '97112', 1, 2, 'Under-billed - 24 min keeps the leftover unit'
UNION ALL SELECT 3, 'G0283', 3, 1, 'Over-billed - untimed code, 1 unit per visit'
ORDER BY n;

-- ▶ Q24_p4_partC_totals_P4   (Part C – payment by billing option)
SELECT 'As submitted' AS billing_option, 107.59 AS payment_usd
UNION ALL SELECT 'Compliant (original units)', 88.95
UNION ALL SELECT 'Recommended (compliant)', 114.71;
