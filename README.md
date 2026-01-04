# Enterprise Decision Intelligence & Governance Platform (SQL-Centric)

## Overview
This project implements a SQL-driven decision governance platform designed to make automated decisions **auditable, explainable, and controllable**. It uses a deterministic rule-based decision engine in MySQL, with Power BI providing executive oversight and transparency.

## What this project demonstrates
- Decision engines implemented in SQL (rule scoring + thresholds)
- Governance-first design (audit trails, explainability, controls)
- Scenario simulation (baseline vs stricter policy thresholds)
- Executive oversight dashboards in Power BI

## Tech stack
- **MySQL** — core decision logic, scoring, audit trails, scenarios
- **Power BI** — governance dashboards and oversight views

---

## Architecture (high level)
**Input Layer**
- `di_cases` captures case-level signals (journey stage, issue type, behaviours, dispute amount, vulnerability, data quality).

**Decision Engine (MySQL)**
- Scores each case using governed rule logic (CTEs avoided; temp tables used for MySQL compatibility).
- Produces deterministic outcomes:
  - `auto_resolve`
  - `manual_review`
  - `escalate`

**Audit & Traceability**
- `di_decision_audit` stores per-rule trace rows:
  - what triggered
  - points applied
  - evidence used
- This enables explainability and audit-ready governance.

**Scenario Simulation**
- `di_decisions_scenarios` compares policy outcomes under:
  - `BASELINE`
  - `STRICT_V1` (stricter thresholds)
- Used to evaluate impact before policy changes go live.

**Oversight (Power BI)**
- Executive KPIs, rule traceability, governance exceptions, and scenario impact views.

---

## How to run (local)
### 1) Create schema
Run:
- `sql/01_schema.sql`

### 2) Load sample data + governed rules
Run:
- `sql/02_seed_data.sql`

### 3) Run the decision engine (baseline decisions + audit)
Run:
- `sql/03_decision_engine.sql`

Outputs:
- `di_decisions`
- `di_decision_audit`

### 4) Run scenario simulation (policy stress test)
Run:
- `sql/04_scenarios.sql`

Outputs:
- `di_decisions_scenarios` (`BASELINE` vs `STRICT_V1`)

---

## Screenshots
*(Representative governance and oversight views)*

- **Executive Oversight**  
  High-level KPIs showing decision volumes, escalation rates, and average risk scores.

- **Rule Traceability**  
  Visualisation of which rules trigger most frequently and contribute the most risk.

- **Governance & Exceptions**  
  Monitoring vulnerable cases, data quality flags, and manual review queues.

- **Scenario Impact (Policy Stress Test)**  
  Comparison of outcomes under BASELINE vs STRICT_V1 governance thresholds.

> Screenshots are intentionally focused on decision governance and explainability rather than visual polish.

---

## Why this project matters
As organisations automate high-impact decisions, the primary challenge is no longer prediction accuracy but **decision governance**.

This project demonstrates how automated decisions can be:
- **Explainable** — every outcome is traceable to specific rules
- **Auditable** — full evidence captured per decision
- **Controllable** — policies can be stress-tested before rollout
- **Transparent** — executive oversight is built in, not added later

The architecture reflects how real-world, regulated systems prioritise accountability and risk management over black-box optimisation.

---

## Author
**Rajath Sagar Gowda**  
Customer Insight Analyst | Decision & Data Systems  
United Kingdom
