-- =====================================================================
-- CareLoop Clinics - No-Show Guard : Part 2 queries (MySQL 8)
-- The same queries are run, with their results, in notebooks/02_sql_analysis.ipynb
-- On SQLiteOnline skip the CREATE DATABASE / USE lines.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Task 2.1  Build and load the database
-- ---------------------------------------------------------------------
CREATE DATABASE noshowguard;
USE noshowguard;

CREATE TABLE clinics (
  clinic_id VARCHAR(5) PRIMARY KEY, clinic_name VARCHAR(40) NOT NULL, city VARCHAR(20) NOT NULL,
  tier VARCHAR(10), latitude DECIMAL(8,4), longitude DECIMAL(8,4), temp_c DECIMAL(5,1));

CREATE TABLE appointments (
  appointment_id VARCHAR(8) PRIMARY KEY, patient_id VARCHAR(8) NOT NULL, clinic_id VARCHAR(5) NOT NULL,
  booked_on DATE, appt_date DATE, age INT, gender VARCHAR(1), distance_km DECIMAL(5,1), fee_inr INT,
  booking_channel VARCHAR(10), visit_type VARCHAR(12), reminder_sent VARCHAR(3), prior_no_shows INT,
  status VARCHAR(10), lead_days INT, no_show INT,
  FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id));

-- Now run outputs/load_data.sql (998 INSERT statements: 8 clinics first, then 990 appointments).

-- Check the load: expect 8 clinics, 990 appointments, 218 no-shows.
SELECT
  (SELECT COUNT(*) FROM clinics)          AS clinics,
  (SELECT COUNT(*) FROM appointments)     AS appointments,
  (SELECT SUM(no_show) FROM appointments) AS no_shows;

-- Try to insert a second row with an appointment_id that already exists.
INSERT INTO appointments VALUES
  ('A0001','P999','C01','2025-01-01','2025-01-02',30,'F',5.0,500,'App','Consultation','Yes',0,'Attended',1,0);
-- Error returned by MySQL (the primary key refuses the duplicate):
--   Error Code: 1062 (23000): Duplicate entry 'A0001' for key 'appointments.PRIMARY'
-- (SQLite words the same refusal as: UNIQUE constraint failed: appointments.appointment_id)

-- ---------------------------------------------------------------------
-- Task 2.2  No-show rate by clinic
-- ---------------------------------------------------------------------
-- (a) Only clinics with at least 95 appointments.
SELECT c.clinic_name,
       c.city,
       COUNT(*)                                   AS appointments,
       SUM(a.no_show)                             AS no_shows,
       ROUND(100.0 * SUM(a.no_show) / COUNT(*), 1) AS no_show_pct
FROM appointments a
JOIN clinics c ON a.clinic_id = c.clinic_id
GROUP BY c.clinic_id, c.clinic_name, c.city
HAVING COUNT(*) >= 95
ORDER BY no_show_pct DESC;

-- (b) The same query without HAVING: all 8 clinics.
--     Gomti Nagar Care Point (Lucknow) has the highest rate, 33.3%, but only 90 appointments.
SELECT c.clinic_name,
       c.city,
       COUNT(*)                                   AS appointments,
       SUM(a.no_show)                             AS no_shows,
       ROUND(100.0 * SUM(a.no_show) / COUNT(*), 1) AS no_show_pct
FROM appointments a
JOIN clinics c ON a.clinic_id = c.clinic_id
GROUP BY c.clinic_id, c.clinic_name, c.city
ORDER BY no_show_pct DESC;

-- ---------------------------------------------------------------------
-- Task 2.3  Does booking far ahead matter? (lead-time bands)
-- ---------------------------------------------------------------------
SELECT CASE
         WHEN lead_days <= 7  THEN '1-7'
         WHEN lead_days <= 14 THEN '8-14'
         WHEN lead_days <= 30 THEN '15-30'
         ELSE '31+'
       END                                      AS lead_band,
       COUNT(*)                                 AS appointments,
       SUM(no_show)                             AS no_shows,
       ROUND(100.0 * SUM(no_show) / COUNT(*), 1) AS no_show_pct
FROM appointments
GROUP BY CASE
         WHEN lead_days <= 7  THEN '1-7'
         WHEN lead_days <= 14 THEN '8-14'
         WHEN lead_days <= 30 THEN '15-30'
         ELSE '31+'
       END
ORDER BY MIN(lead_days);

-- ---------------------------------------------------------------------
-- Task 2.4  Month-by-month trend (CTE + LAG)
-- ---------------------------------------------------------------------
WITH monthly AS (
  SELECT SUBSTR(appt_date, 1, 7)                    AS month,
         COUNT(*)                                   AS appointments,
         ROUND(100.0 * SUM(no_show) / COUNT(*), 1)  AS no_show_pct
  FROM appointments
  GROUP BY SUBSTR(appt_date, 1, 7)
)
SELECT month,
       appointments,
       no_show_pct,
       ROUND(no_show_pct - LAG(no_show_pct) OVER (ORDER BY month), 1) AS change_pp
FROM monthly
ORDER BY month;

-- ---------------------------------------------------------------------
-- Task 2.5  Rank clinics inside each city (CTE + RANK + scalar subquery)
-- ---------------------------------------------------------------------
-- The overall no-show rate that every clinic is compared with (22.02%).
SELECT ROUND(100.0 * SUM(no_show) / COUNT(*), 2) AS overall_no_show_pct
FROM appointments;

WITH clinic_rates AS (
  SELECT c.clinic_name                               AS clinic,
         c.city                                      AS city,
         ROUND(100.0 * SUM(a.no_show) / COUNT(*), 1) AS no_show_pct
  FROM appointments a
  JOIN clinics c ON a.clinic_id = c.clinic_id
  GROUP BY c.clinic_id, c.clinic_name, c.city
)
SELECT clinic,
       city,
       no_show_pct,
       RANK() OVER (PARTITION BY city ORDER BY no_show_pct DESC) AS rank_in_city,
       CASE
         WHEN no_show_pct > (SELECT 100.0 * SUM(no_show) / COUNT(*) FROM appointments) THEN 'above'
         WHEN no_show_pct < (SELECT 100.0 * SUM(no_show) / COUNT(*) FROM appointments) THEN 'below'
         ELSE 'equal'
       END                                                       AS vs_overall
FROM clinic_rates
ORDER BY city, rank_in_city;
