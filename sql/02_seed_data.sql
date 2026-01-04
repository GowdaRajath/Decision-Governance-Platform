/* ============================================================
   PROJECT: Enterprise Decision Intelligence & Governance Platform
   FILE:    sql/02_seed_data.sql
   DB:      MySQL
   PURPOSE: Seed sample cases + governed rule pack (core_v1)
   ============================================================ */

USE di_governance;

-- Optional: clear existing data for clean re-runs
-- (If Safe Updates blocks deletes, run: SET SQL_SAFE_UPDATES = 0; )
SET SQL_SAFE_UPDATES = 0;

DELETE FROM di_decision_audit WHERE audit_id IS NOT NULL;
DELETE FROM di_decisions      WHERE decision_id IS NOT NULL;
DELETE FROM di_rules          WHERE rule_id IS NOT NULL;
DELETE FROM di_cases          WHERE case_id IS NOT NULL;

-- ---------------------------
-- Seed sample cases (20 rows)
-- ---------------------------
INSERT INTO di_cases (
  case_id, created_at, channel, journey_stage, issue_type,
  customer_tenure_days, premium_amount, amount_in_dispute,
  agent_attempted_resolution, explanation_provided, ownership_taken,
  prior_contacts_30d, vulnerability_flag, data_quality_flag
) VALUES
('C001','2025-01-12 10:15:00','phone','renewal','billing',420,85.00,85.00,'No','No','No',2,'No','No'),
('C002','2025-01-18 14:22:00','email','cooling_period','cancellation',95,62.50,62.50,'Yes','Yes','Yes',1,'No','No'),
('C003','2025-02-03 09:05:00','web','renewal','documents',780,110.00,0.00,'Yes','No','Yes',3,'No','No'),
('C004','2025-02-14 16:40:00','phone','post_renewal','duplication',30,54.99,54.99,'No','No','No',4,'No','No'),
('C005','2025-02-27 11:30:00','social','renewal','billing',1200,140.00,70.00,'Yes','Yes','No',2,'Yes','No'),
('C006','2025-03-04 13:10:00','phone','cooling_period','billing',365,75.00,75.00,'Yes','No','Yes',2,'No','No'),
('C007','2025-03-11 08:55:00','email','post_renewal','documents',60,49.00,0.00,'No','No','Yes',1,'No','Yes'),
('C008','2025-03-22 19:20:00','web','renewal','cancellation',520,95.00,95.00,'No','Yes','No',2,'No','No'),
('C009','2025-04-02 12:05:00','phone','renewal','billing',210,68.00,68.00,'Yes','Yes','Yes',0,'No','No'),
('C010','2025-04-15 17:45:00','email','cooling_period','duplication',140,59.99,59.99,'Yes','Yes','Yes',2,'No','No'),
('C011','2025-05-01 09:35:00','phone','renewal','billing',900,130.00,130.00,'No','No','No',3,'No','No'),
('C012','2025-05-09 15:00:00','web','post_renewal','cancellation',20,45.00,45.00,'No','No','No',2,'No','No'),
('C013','2025-05-18 10:50:00','phone','renewal','documents',660,102.00,0.00,'Yes','Yes','Yes',1,'No','No'),
('C014','2025-06-06 11:25:00','email','cooling_period','billing',410,88.00,88.00,'Yes','No','No',4,'No','No'),
('C015','2025-06-19 16:05:00','web','renewal','duplication',75,55.00,55.00,'No','No','No',5,'No','No'),
('C016','2025-07-03 13:55:00','phone','post_renewal','billing',1500,160.00,80.00,'Yes','Yes','Yes',2,'Yes','No'),
('C017','2025-07-21 09:15:00','email','renewal','cancellation',300,70.00,70.00,'No','Yes','No',3,'No','No'),
('C018','2025-08-08 18:10:00','web','cooling_period','documents',45,52.00,0.00,'Yes','No','Yes',1,'No','No'),
('C019','2025-08-19 10:05:00','phone','renewal','billing',600,105.00,105.00,'No','No','No',2,'No','No'),
('C020','2025-09-07 14:35:00','social','post_renewal','duplication',10,49.99,49.99,'No','No','No',4,'No','No');

-- ------------------------------------
-- Governed rule pack (12 rules, v1)
-- ------------------------------------
INSERT INTO di_rules (
  rule_id, rule_name, rule_category, rule_version, is_active,
  effective_from, effective_to, severity_points, rule_description
) VALUES
('R001','High dispute amount','risk',1,'Yes','2025-01-01',NULL,30,'Amount in dispute is high (>= 100)'),
('R002','Any dispute equals full premium','risk',1,'Yes','2025-01-01',NULL,15,'Amount in dispute equals premium amount'),
('R003','Agent did not attempt resolution','governance',1,'Yes','2025-01-01',NULL,25,'Agent_attempted_resolution = No'),
('R004','No explanation provided','governance',1,'Yes','2025-01-01',NULL,20,'Explanation_provided = No'),
('R005','No ownership taken','governance',1,'Yes','2025-01-01',NULL,15,'Ownership_taken = No'),
('R006','Multiple contacts in last 30 days','risk',1,'Yes','2025-01-01',NULL,15,'Prior_contacts_30d >= 3 indicates repeat failure'),
('R007','Vulnerability flag present','compliance',1,'Yes','2025-01-01',NULL,35,'Vulnerability_flag = Yes requires higher safeguards'),
('R008','Data quality issue in input','compliance',1,'Yes','2025-01-01',NULL,25,'Data_quality_flag = Yes reduces automation confidence'),
('R009','Cooling period cancellation fast-track','eligibility',1,'Yes','2025-01-01',NULL,-30,'Cooling_period + cancellation + good behaviours -> easier auto-resolve'),
('R010','Duplicate policy is high-risk','risk',1,'Yes','2025-01-01',NULL,20,'Duplication cases often require careful review'),
('R011','Renewal billing sensitivity','risk',1,'Yes','2025-01-01',NULL,10,'Renewal + billing has elevated complaint sensitivity'),
('R012','Very new customer protection','compliance',1,'Yes','2025-01-01',NULL,15,'Tenure < 30 days requires extra care');
