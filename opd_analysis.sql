SELECT DATABASE();
SHOW TABLES;
CREATE TABLE opd_visits (
    patient_id VARCHAR(20),
    visit_date DATE,
    day_of_week VARCHAR(15),
    department VARCHAR(50),
    doctor_name VARCHAR(50),
    registration_type VARCHAR(20),
    payment_type VARCHAR(20),
    checkin_time TIME,
    doctor_entry_time TIME,
    exit_time TIME,
    registration_delay_mins INT,
    doctor_wait_mins INT,
    total_wait_mins INT,
    consultation_duration_mins INT,
    is_peak_hour VARCHAR(5),
    patient_satisfied VARCHAR(5),
    shift VARCHAR(15),
    wait_flag VARCHAR(20),
    bottleneck_source VARCHAR(25),
    wait_bucket VARCHAR(15)
);


SHOW VARIABLES LIKE 'secure_file_priv';


LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/opd_patient_data.csv'
INTO TABLE opd_visits
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(patient_id, @visit_date, day_of_week, department, doctor_name, registration_type, payment_type, 
 checkin_time, doctor_entry_time, exit_time, registration_delay_mins, doctor_wait_mins, 
 total_wait_mins, consultation_duration_mins, is_peak_hour, patient_satisfied, 
 shift, wait_flag, bottleneck_source, wait_bucket)
SET visit_date = STR_TO_DATE(@visit_date, '%d-%m-%Y');

SELECT COUNT(*) FROM opd_visits;

## Query 1: Department × Shift):

SELECT 
    department,
    shift,
    COUNT(*) AS total_visits,
    ROUND(AVG(total_wait_mins), 1) AS avg_wait,
    ROUND(AVG(doctor_wait_mins), 1) AS avg_doctor_wait,
    ROUND(AVG(registration_delay_mins), 1) AS avg_registration_delay
FROM opd_visits
GROUP BY department, shift
ORDER BY avg_wait DESC;

## Doctor-level ranking ##

SELECT 
    doctor_name,
    department,
    COUNT(*) AS patients_seen,
    ROUND(AVG(consultation_duration_mins), 1) AS avg_consult_time,
    ROUND(AVG(doctor_wait_mins), 1) AS avg_wait_caused,
    RANK() OVER (ORDER BY AVG(doctor_wait_mins) DESC) AS delay_rank
FROM opd_visits
GROUP BY doctor_name, department
ORDER BY delay_rank;

## Busiest day + peak load + satisfaction ##

SELECT 
    day_of_week,
    is_peak_hour,
    COUNT(*) AS visit_count,
    ROUND(AVG(total_wait_mins), 1) AS avg_wait,
    ROUND(100.0 * SUM(CASE WHEN patient_satisfied = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS satisfaction_pct
FROM opd_visits
GROUP BY day_of_week, is_peak_hour
ORDER BY avg_wait DESC;

## Root cause diagnosis ##

SELECT 
    department,
    ROUND(AVG(registration_delay_mins), 1) AS avg_reg_delay,
    ROUND(AVG(doctor_wait_mins), 1) AS avg_doctor_delay,
    SUM(CASE WHEN bottleneck_source = 'Doctor Delay' THEN 1 ELSE 0 END) AS doctor_delay_visits,
    SUM(CASE WHEN bottleneck_source = 'Registration Delay' THEN 1 ELSE 0 END) AS registration_delay_visits,
    ROUND(100.0 * SUM(CASE WHEN bottleneck_source = 'Doctor Delay' THEN 1 ELSE 0 END) / COUNT(*), 1) AS doctor_delay_pct
FROM opd_visits
GROUP BY department
ORDER BY avg_doctor_delay DESC;


SELECT COUNT(*) AS delay_alert_count 
FROM opd_visits 
WHERE total_wait_mins > 60;


SELECT COUNT(*) FROM opd_visits WHERE wait_flag = 'Delay Alert';


