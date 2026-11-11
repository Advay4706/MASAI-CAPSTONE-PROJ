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
