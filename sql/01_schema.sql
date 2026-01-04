/* ============================================================
   PROJECT: Enterprise Decision Intelligence & Governance Platform
   FILE:    sql/01_schema.sql
   DB:      MySQL
   PURPOSE: Create the core schema (cases, rules, decisions, audit)
   ============================================================ */

-- Create and select database
CREATE DATABASE IF NOT EXISTS di_governance;
USE di_governance;

-- Core input table (cases evaluated by the decision engine)
CREATE TABLE IF NOT EXISTS di_cases (
    case_id              VARCHAR(20) PRIMARY KEY,
    created_at           DATETIME NOT NULL,
    channel              VARCHAR(30) NOT NULL,        -- phone / email / web / social
    journey_stage        VARCHAR(30) NOT NULL,        -- renewal / cooling_period / post_renewal
    issue_type           VARCHAR(50) NOT NULL,        -- billing / cancellation / documents / duplication / other
    customer_tenure_days INT NOT NULL,
    premium_amount       DECIMAL(10,2) NOT NULL,
    amount_in_dispute    DECIMAL(10,2) NOT NULL,
    agent_attempted_resolution VARCHAR(3) NOT NULL,   -- Yes/No
    explanation_provided VARCHAR(3) NOT NULL,         -- Yes/No
    ownership_taken      VARCHAR(3) NOT NULL,         -- Yes/No
    prior_contacts_30d   INT NOT NULL,
    vulnerability_flag   VARCHAR(3) NOT NULL,         -- Yes/No
    data_quality_flag    VARCHAR(3) NOT NULL          -- Yes/No (input completeness/consistency)
);

-- Governed rule registry (versioned rules, active flags, descriptions)
CREATE TABLE IF NOT EXISTS di_rules (
    rule_id          VARCHAR(20) PRIMARY KEY,
    rule_name        VARCHAR(100) NOT NULL,
    rule_category    VARCHAR(50) NOT NULL,            -- eligibility / risk / governance / compliance
    rule_version     INT NOT NULL,
    is_active        VARCHAR(3) NOT NULL,             -- Yes/No
    effective_from   DATE NOT NULL,
    effective_to     DATE NULL,
    severity_points  INT NOT NULL,                    -- risk points contributed by the rule
    rule_description VARCHAR(300) NOT NULL
);

-- Decision outputs (engine results)
CREATE TABLE IF NOT EXISTS di_decisions (
    decision_id       VARCHAR(30) PRIMARY KEY,
    case_id           VARCHAR(20) NOT NULL,
    evaluated_at      DATETIME NOT NULL,
    total_risk_score  INT NOT NULL,
    decision_outcome  VARCHAR(30) NOT NULL,           -- auto_resolve / manual_review / escalate
    decision_reason   VARCHAR(300) NOT NULL,
    rule_version_pack VARCHAR(50) NOT NULL,
    CONSTRAINT fk_dec_case FOREIGN KEY (case_id) REFERENCES di_cases(case_id)
);

-- Per-rule traceability (audit trail explaining why decisions happened)
CREATE TABLE IF NOT EXISTS di_decision_audit (
    audit_id        VARCHAR(40) PRIMARY KEY,
    decision_id     VARCHAR(30) NOT NULL,
    rule_id         VARCHAR(20) NOT NULL,
    rule_version    INT NOT NULL,
    triggered       VARCHAR(3) NOT NULL,              -- Yes/No
    points_applied  INT NOT NULL,
    evidence        VARCHAR(300) NOT NULL,
    logged_at       DATETIME NOT NULL,
    CONSTRAINT fk_aud_dec FOREIGN KEY (decision_id) REFERENCES di_decisions(decision_id),
    CONSTRAINT fk_aud_rule FOREIGN KEY (rule_id) REFERENCES di_rules(rule_id)
);

-- Scenario decisions (policy stress-testing: baseline vs stricter thresholds)
CREATE TABLE IF NOT EXISTS di_decisions_scenarios (
  scenario_id        VARCHAR(20) NOT NULL,            -- BASELINE, STRICT_V1
  decision_id        VARCHAR(50) NOT NULL,
  case_id            VARCHAR(20) NOT NULL,
  evaluated_at       DATETIME NOT NULL,
  total_risk_score   INT NOT NULL,
  decision_outcome   VARCHAR(30) NOT NULL,
  decision_reason    VARCHAR(300) NOT NULL,
  rule_version_pack  VARCHAR(50) NOT NULL,
  PRIMARY KEY (scenario_id, decision_id),
  INDEX idx_case (case_id)
);

-- Optional scenario audit table (kept for extensibility; not required for MVP dashboards)
CREATE TABLE IF NOT EXISTS di_decision_audit_scenarios (
  scenario_id     VARCHAR(20) NOT NULL,
  audit_id        VARCHAR(60) NOT NULL,
  decision_id     VARCHAR(50) NOT NULL,
  rule_id         VARCHAR(20) NOT NULL,
  rule_version    INT NOT NULL,
  triggered       VARCHAR(3) NOT NULL,
  points_applied  INT NOT NULL,
  evidence        VARCHAR(300) NOT NULL,
  logged_at       DATETIME NOT NULL,
  PRIMARY KEY (scenario_id, audit_id),
  INDEX idx_dec (decision_id),
  INDEX idx_rule (rule_id)
);
