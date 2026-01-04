/* ============================================================
   PROJECT: Enterprise Decision Intelligence & Governance Platform
   FILE:    sql/04_scenarios.sql
   DB:      MySQL
   PURPOSE: Scenario simulation (policy threshold stress-test)
            - BASELINE thresholds (engine defaults)
            - STRICT_V1 thresholds (stricter governance)
   ============================================================ */

USE di_governance;

SET @run_ts  = NOW();
SET @run_key = DATE_FORMAT(@run_ts, '%Y%m%d%H%i%s');

SET SQL_SAFE_UPDATES = 0;

-- Clean prior scenario outputs for repeatable runs
DELETE FROM di_decisions_scenarios WHERE decision_id IS NOT NULL;

-- Rebuild temp scoring tables (aligned to core_v1 rule pack)
DROP TEMPORARY TABLE IF EXISTS tmp_scoring;
DROP TEMPORARY TABLE IF EXISTS tmp_totals;

CREATE TEMPORARY TABLE tmp_scoring AS
SELECT
  c.case_id,
  (CASE WHEN c.amount_in_dispute >= 100 THEN 30 ELSE 0 END) AS p_r001,
  (CASE WHEN c.amount_in_dispute = c.premium_amount AND c.amount_in_dispute > 0 THEN 15 ELSE 0 END) AS p_r002,
  (CASE WHEN c.agent_attempted_resolution = 'No' THEN 25 ELSE 0 END) AS p_r003,
  (CASE WHEN c.explanation_provided = 'No' THEN 20 ELSE 0 END) AS p_r004,
  (CASE WHEN c.ownership_taken = 'No' THEN 15 ELSE 0 END) AS p_r005,
  (CASE WHEN c.prior_contacts_30d >= 3 THEN 15 ELSE 0 END) AS p_r006,
  (CASE WHEN c.vulnerability_flag = 'Yes' THEN 35 ELSE 0 END) AS p_r007,
  (CASE WHEN c.data_quality_flag = 'Yes' THEN 25 ELSE 0 END) AS p_r008,
  (CASE WHEN c.journey_stage = 'cooling_period'
         AND c.issue_type = 'cancellation'
         AND c.agent_attempted_resolution = 'Yes'
         AND c.explanation_provided = 'Yes'
         AND c.ownership_taken = 'Yes'
        THEN -30 ELSE 0 END) AS p_r009,
  (CASE WHEN c.issue_type = 'duplication' THEN 20 ELSE 0 END) AS p_r010,
  (CASE WHEN c.journey_stage = 'renewal' AND c.issue_type = 'billing' THEN 10 ELSE 0 END) AS p_r011,
  (CASE WHEN c.customer_tenure_days < 30 THEN 15 ELSE 0 END) AS p_r012
FROM di_cases c;

CREATE TEMPORARY TABLE tmp_totals AS
SELECT
  s.case_id,
  (s.p_r001+s.p_r002+s.p_r003+s.p_r004+s.p_r005+s.p_r006+s.p_r007+s.p_r008+s.p_r009+s.p_r010+s.p_r011+s.p_r012) AS total_risk_score,
  CONCAT_WS('; ',
    NULLIF(CASE WHEN s.p_r007 > 0 THEN 'Vulnerability safeguard triggered (R007)' END, ''),
    NULLIF(CASE WHEN s.p_r008 > 0 THEN 'Input data quality issue reduces automation confidence (R008)' END, ''),
    NULLIF(CASE WHEN s.p_r003 > 0 THEN 'No agent resolution attempt (R003)' END, ''),
    NULLIF(CASE WHEN s.p_r004 > 0 THEN 'No explanation provided (R004)' END, ''),
    NULLIF(CASE WHEN s.p_r005 > 0 THEN 'No ownership taken (R005)' END, ''),
    NULLIF(CASE WHEN s.p_r006 > 0 THEN 'Multiple contacts in 30 days (R006)' END, ''),
    NULLIF(CASE WHEN s.p_r001 > 0 THEN 'High dispute amount (R001)' END, ''),
    NULLIF(CASE WHEN s.p_r002 > 0 THEN 'Dispute equals full premium (R002)' END, ''),
    NULLIF(CASE WHEN s.p_r010 > 0 THEN 'Duplicate policy risk (R010)' END, ''),
    NULLIF(CASE WHEN s.p_r011 > 0 THEN 'Renewal billing sensitivity (R011)' END, ''),
    NULLIF(CASE WHEN s.p_r012 > 0 THEN 'Very new customer protection (R012)' END, ''),
    NULLIF(CASE WHEN s.p_r009 < 0 THEN 'Cooling period cancellation fast-track (R009)' END, '')
  ) AS decision_reason
FROM tmp_scoring s;

-- ------------------------------------------------------------
-- Scenario 1: BASELINE (same thresholds as decision engine)
-- escalate >= 70, manual_review 35–69, else auto_resolve
-- ------------------------------------------------------------
INSERT INTO di_decisions_scenarios (
  scenario_id, decision_id, case_id, evaluated_at,
  total_risk_score, decision_outcome, decision_reason, rule_version_pack
)
SELECT
  'BASELINE' AS scenario_id,
  CONCAT('SD_BASE_', t.case_id, '_', @run_key) AS decision_id,
  t.case_id,
  @run_ts AS evaluated_at,
  t.total_risk_score,
  CASE
    WHEN t.total_risk_score >= 70 THEN 'escalate'
    WHEN t.total_risk_score BETWEEN 35 AND 69 THEN 'manual_review'
    ELSE 'auto_resolve'
  END AS decision_outcome,
  CASE
    WHEN t.decision_reason IS NULL OR t.decision_reason = '' THEN 'No elevated risk factors triggered under core_v1'
    ELSE t.decision_reason
  END AS decision_reason,
  'core_v1' AS rule_version_pack
FROM tmp_totals t;

-- ------------------------------------------------------------
-- Scenario 2: STRICT_V1 (stricter governance thresholds)
-- escalate >= 60, manual_review 25–59, else auto_resolve
-- ------------------------------------------------------------
INSERT INTO di_decisions_scenarios (
  scenario_id, decision_id, case_id, evaluated_at,
  total_risk_score, decision_outcome, decision_reason, rule_version_pack
)
SELECT
  'STRICT_V1' AS scenario_id,
  CONCAT('SD_STRICT_', t.case_id, '_', @run_key) AS decision_id,
  t.case_id,
  @run_ts AS evaluated_at,
  t.total_risk_score,
  CASE
    WHEN t.total_risk_score >= 60 THEN 'escalate'
    WHEN t.total_risk_score BETWEEN 25 AND 59 THEN 'manual_review'
    ELSE 'auto_resolve'
  END AS decision_outcome,
  CASE
    WHEN t.decision_reason IS NULL OR t.decision_reason = '' THEN 'No elevated risk factors triggered under core_v1'
    ELSE t.decision_reason
  END AS decision_reason,
  'core_v1_strict_thresholds' AS rule_version_pack
FROM tmp_totals t;

-- Quick validation (expected: 20 rows per scenario)
SELECT scenario_id, COUNT(*) AS rows_per_scenario
FROM di_decisions_scenarios
GROUP BY scenario_id;

-- Outcome changes between BASELINE and STRICT_V1
SELECT
  b.case_id,
  b.total_risk_score,
  b.decision_outcome AS baseline_outcome,
  s.decision_outcome AS strict_outcome
FROM di_decisions_scenarios b
JOIN di_decisions_scenarios s
  ON s.case_id = b.case_id
 AND s.scenario_id = 'STRICT_V1'
WHERE b.scenario_id = 'BASELINE'
  AND b.decision_outcome <> s.decision_outcome
ORDER BY b.total_risk_score DESC;
