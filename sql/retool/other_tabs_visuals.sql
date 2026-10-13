-- ▶ Q11_p4_claimC_payment_P4   (P4 Part C – payment by billing option)
SELECT 'As submitted' AS billing_option, 107.59 AS payment_usd
UNION ALL SELECT 'Compliant (original units)', 88.95
UNION ALL SELECT 'Recommended (compliant)', 114.71;

-- ▶ Q12_p1_claims_per_day_P1   (P1 – completed vs target per day)
SELECT 'Completed now' AS status, 50 AS claims_per_day
UNION ALL SELECT 'Stuck', 450
UNION ALL SELECT 'Target', 500;

-- ▶ Q13_p3_days_to_clear_P3   (P3 – working days to clear 10,000 claims)
SELECT 'One by one' AS method, 35 AS working_days
UNION ALL SELECT 'Fixed in groups (40%)', 21;

-- ▶ Q14_p1_now_vs_target_P1   (P1 – bar chart)
SELECT 'Completed now' AS status, 50 AS claims_per_day
UNION ALL SELECT 'After fix (~12 ops x 42/day)', 500
UNION ALL SELECT 'Target', 500;

-- ▶ Q15_p3_burndown_P3   (JavaScript query, not SQL)
-- const rows = [];
-- for (let d = 0; d <= 35; d++) {
--   rows.push({ day: d,
--     one_by_one: Math.max(0, 10000 - 288 * d),
--     grouped: Math.max(0, Math.round(10000 - (10000 / 21) * d)) });
-- }
-- return rows;

-- ▶ Q16_p1_timeline_P1
SELECT 1 AS n, 'Days 1–3' AS period, '2 operators log 100 stuck claims; others continue' AS india_team_20, '1 operator reviews sample, calls main WC insurers' AS mountain_view_3, 'Reviews tool error logs' AS engineer_2h_week
UNION ALL SELECT 2, 'Week 1', 'Use checklist + stuck queue', 'Delivers training', 'Fixes largest tool issue'
UNION ALL SELECT 3, 'Weeks 2–4', 'Return to full volume', 'Reviews weekly figures', 'Fixes next issue'
ORDER BY n;

-- ▶ Q17_p1_metrics_P1
SELECT 1 AS n, 'Claims completed per day' AS metric, '500' AS target
UNION ALL SELECT 2, 'Share completed without getting stuck', 'Above 90%'
UNION ALL SELECT 3, 'Stuck claims by reason (weekly)', 'Decreasing'
UNION ALL SELECT 4, 'Minutes per claim', 'Decreasing'
UNION ALL SELECT 5, 'After fix: vendor mailing time, days to payment', 'Within agreed time'
ORDER BY n;

-- ▶ Q18_p3_actions_P3
SELECT 1 AS n, 'Claim was never sent' AS finding, 'Submit it' AS action
UNION ALL SELECT 2, 'Wrong insurer or ID', 'Correct and resubmit'
UNION ALL SELECT 3, 'Past filing deadline, with proof of timely submission', 'Appeal with the proof'
UNION ALL SELECT 4, 'Small amount that cannot be recovered', 'Write off'
ORDER BY n;
