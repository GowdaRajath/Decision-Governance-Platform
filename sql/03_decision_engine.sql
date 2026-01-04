/* ============================================================
   PROJECT: Enterprise Decision Intelligence & Governance Platform
   FILE:    sql/03_decision_engine.sql
   DB:      MySQL
   PURPOSE: Run the decision engine (writes decisions + audit trail)
   VERSION: core_v1
   ============================================================ */

USE di_governance;

-- Run key used to generate deterministic IDs for each execution
SET @run_ts  = NOW();
SET @run_key = DATE_FORMAT(@run_ts, '%Y%m%d%H%i%s');

-- Allow clean re-runs in dev
SET SQL_SAFE_UPDATES = 0;

-- Clear outputs (so the run is repeatable)
DELETE FROM di_decision_audit WHERE audit_id IS NOT NULL;
DELETE FROM di_decisions      WHERE decision_id IS NOT NULL;

-- Drop temp tables if they exist (session-scope)
DROP TEMPORARY TABLE IF EXISTS tmp_scoring;
DROP TEMPORARY TABLE IF EXISTS tmp_totals;

-- ------------------------------------------------------------
-- 1) Score each case against the governed rule pack (core_v1)
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- 2) Aggregate risk score + generate explainable decision reason
-- ------------------------------------------------------------
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
-- 3) Write decisions (threshold-based outcomes)
-- ------------------------------------------------------------
INSERT INTO di_decisions (
  decision_id, case_id, evaluated_at, total_risk_score, decision_outcome,
  decision_reason, rule_version_pack
)
SELECT
  CONCAT('D_', t.case_id, '_', @run_key) AS decision_id,
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
-- 4) Write audit trail (per-rule traceability and evidence)
-- ------------------------------------------------------------
INSERT INTO di_decision_audit (
  audit_id, decision_id, rule_id, rule_version, triggered,
  points_applied, evidence, logged_at
)
SELECT
  CONCAT('A_', c.case_id, '_', r.rule_id, '_', @run_key) AS audit_id,
  CONCAT('D_', c.case_id, '_', @run_key) AS decision_id,
  r.rule_id,
  r.rule_version,

  CASE r.rule_id
    WHEN 'R001' THEN CASE WHEN c.amount_in_dispute >= 100 THEN 'Yes' ELSE 'No' END
    WHEN 'R002' THEN CASE WHEN c.amount_in_dispute = c.premium_amount AND c.amount_in_dispute > 0 THEN 'Yes' ELSE 'No' END
    WHEN 'R003' THEN CASE WHEN c.agent_attempted_resolution = 'No' THEN 'Yes' ELSE 'No' END
    WHEN 'R004' THEN CASE WHEN c.explanation_provided = 'No' THEN 'Yes' ELSE 'No' END
    WHEN 'R005' THEN CASE WHEN c.ownership_taken = 'No' THEN 'Yes' ELSE 'No' END
    WHEN 'R006' THEN CASE WHEN c.prior_contacts_30d >= 3 THEN 'Yes' ELSE 'No' END
    WHEN 'R007' THEN CASE WHEN c.vulnerability_flag = 'Yes' THEN 'Yes' ELSE 'No' END
    WHEN 'R008' THEN CASE WHEN c.data_quality_flag = 'Yes' THEN 'Yes' ELSE 'No' END
    WHEN 'R009' THEN CASE WHEN c.journey_stage = 'cooling_period'
                            AND c.issue_type = 'cancellation'
                            AND c.agent_attempted_resolution = 'Yes'
                            AND c.explanation_provided = 'Yes'
                            AND c.ownership_taken = 'Yes'
                          THEN 'Yes' ELSE 'No' END
    WHEN 'R010' THEN CASE WHEN c.issue_type = 'duplication' THEN 'Yes' ELSE 'No' END
    WHEN 'R011' THEN CASE WHEN c.journey_stage = 'renewal' AND c.issue_type = 'billing' THEN 'Yes' ELSE 'No' END
    WHEN 'R012' THEN CASE WHEN c.customer_tenure_days < 30 THEN 'Yes' ELSE 'No' END
    ELSE 'No'
  END AS triggered,

  CASE r.rule_id
    WHEN 'R001' THEN CASE WHEN c.amount_in_dispute >= 100 THEN 30 ELSE 0 END
    WHEN 'R002' THEN CASE WHEN c.amount_in_dispute = c.premium_amount AND c.amount_in_dispute > 0 THEN 15 ELSE 0 END
    WHEN 'R003' THEN CASE WHEN c.agent_attempted_resolution = 'No' THEN 25 ELSE 0 END
    WHEN 'R004' THEN CASE WHEN c.explanation_provided = 'No' THEN 20 ELSE 0 END
    WHEN 'R005' THEN CASE WHEN c.ownership_taken = 'No' THEN 15 ELSE 0 END
    WHEN 'R006' THEN CASE WHEN c.prior_contacts_30d >= 3 THEN 15 ELSE 0 END
    WHEN 'R007' THEN CASE WHEN c.vulnerability_flag = 'Yes' THEN 35 ELSE 0 END
    WHEN 'R008' THEN CASE WHEN c.data_quality_flag = 'Yes' THEN 25 ELSE 0 END
    WHEN 'R009' THEN CASE WHEN c.journey_stage = 'cooling_period'
                            AND c.issue_type = 'cancellation'
                            AND c.agent_attempted_resolution = 'Yes'
                            AND c.explanation_provided = 'Yes'
                            AND c.ownership_taken = 'Yes'
                          THEN -30 ELSE 0 END
    WHEN 'R010' THEN CASE WHEN c.issue_type = 'duplication' THEN 20 ELSE 0 END
    WHEN 'R011' THEN CASE WHEN c.journey_stage = 'renewal' AND c.issue_type = 'billing' THEN 10 ELSE 0 END
    WHEN 'R012' THEN CASE WHEN c.customer_tenure_days < 30 THEN 15 ELSE 0 END
    ELSE 0
  END AS points_applied,

  CASE r.rule_id
    WHEN 'R001' THEN CONCAT('amount_in_dispute=', c.amount_in_dispute)
    WHEN 'R002' THEN CONCAT('amount_in_dispute=', c.amount_in_dispute, ', premium_amount=', c.premium_amount)
    WHEN 'R003' THEN CONCAT('agent_attempted_resolution=', c.agent_attempted_resolution)
    WHEN 'R004' THEN CONCAT('explanation_provided=', c.explanation_provided)
    WHEN 'R005' THEN CONCAT('ownership_taken=', c.ownership_taken)
    WHEN 'R006' THEN CONCAT('prior_contacts_30d=', c.prior_contacts_30d)
    WHEN 'R007' THEN CONCAT('vulnerability_flag=', c.vulnerability_flag)
    WHEN 'R008' THEN CONCAT('data_quality_flag=', c.data_quality_flag)
    WHEN 'R009' THEN CONCAT('journey_stage=', c.journey_stage, ', issue_type=', c.issue_type,
                            ', attempted=', c.agent_attempted_resolution,
                            ', explained=', c.explanation_provided,
                            ', ownership=', c.ownership_taken)
    WHEN 'R010' THEN CONCAT('issue_type=', c.issue_type)
    WHEN 'R011' THEN CONCAT('journey_stage=', c.journey_stage, ', issue_type=', c.issue_type)
    WHEN 'R012' THEN CONCAT('customer_tenure_days=', c.customer_tenure_days)
    ELSE 'n/a'
  END AS evidence,

  @run_ts AS logged_at
FROM di_cases c
JOIN di_rules r
  ON r.is_active = 'Yes' AND r.rule_version = 1;

-- Quick validation (expected: 20 decisions, 240 audit rows)
SELECT COUNT(*) AS decision_rows FROM di_decisions;
SELECT COUNT(*) AS audit_rows FROM di_decision_audit;
