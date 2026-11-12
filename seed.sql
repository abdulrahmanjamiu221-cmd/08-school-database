-- Sample data for schema.sql. Safe to run repeatedly against an existing
-- schema: unique natural keys are updated rather than duplicated.

INSERT INTO teachers
    (staff_no, first_name, last_name, email, phone, hire_date)
VALUES
    ('STF-001', 'Amina', 'Yusuf', 'amina.yusuf@greenfield.edu.ng', '08031234501', '2018-09-03'),
    ('STF-002', 'Chinedu', 'Okafor', 'chinedu.okafor@greenfield.edu.ng', '08031234502', '2019-01-14'),
    ('STF-003', 'Grace', 'Adeyemi', 'grace.adeyemi@greenfield.edu.ng', '08031234503', '2020-09-07'),
    ('STF-004', 'Ibrahim', 'Bello', 'ibrahim.bello@greenfield.edu.ng', '08031234504', '2017-04-10'),
    ('STF-005', 'Ngozi', 'Eze', 'ngozi.eze@greenfield.edu.ng', '08031234505', '2021-01-11'),
    ('STF-006', 'Tunde', 'Balogun', 'tunde.balogun@greenfield.edu.ng', '08031234506', '2016-09-05')
ON DUPLICATE KEY UPDATE
    first_name = VALUES(first_name),
    last_name = VALUES(last_name),
    email = VALUES(email),
    phone = VALUES(phone),
    hire_date = VALUES(hire_date);

INSERT INTO terms (term_name, start_date, end_date)
VALUES ('2026/2027 First Term', '2026-09-07', '2026-12-18')
ON DUPLICATE KEY UPDATE
    start_date = VALUES(start_date),
    end_date = VALUES(end_date);

INSERT INTO subjects (subject_code, subject_name)
VALUES
    ('ENG', 'English Studies'),
    ('MTH', 'Mathematics'),
    ('BSC', 'Basic Science'),
    ('BST', 'Basic Technology'),
    ('ICT', 'Information and Communication Technology'),
    ('CIV', 'Civic Education'),
    ('CRS', 'Christian Religious Studies'),
    ('HPE', 'Health and Physical Education')
ON DUPLICATE KEY UPDATE
    subject_name = VALUES(subject_name);

INSERT INTO classes (class_name, form_teacher_id)
SELECT v.class_name, t.teacher_id
FROM (
    SELECT 'JSS1 A' AS class_name, 'STF-001' AS staff_no
    UNION ALL SELECT 'JSS1 B', 'STF-002'
    UNION ALL SELECT 'JSS2 A', 'STF-003'
) AS v
JOIN teachers AS t ON t.staff_no = v.staff_no
ON DUPLICATE KEY UPDATE
    form_teacher_id = VALUES(form_teacher_id);

INSERT INTO class_subjects (class_id, subject_code, teacher_id)
SELECT c.class_id, v.subject_code, t.teacher_id
FROM (
    SELECT 'JSS1 A' AS class_name, 'ENG' AS subject_code, 'STF-001' AS staff_no
    UNION ALL SELECT 'JSS1 A', 'MTH', 'STF-002'
    UNION ALL SELECT 'JSS1 A', 'BSC', 'STF-003'
    UNION ALL SELECT 'JSS1 A', 'BST', 'STF-004'
    UNION ALL SELECT 'JSS1 A', 'CIV', 'STF-005'
    UNION ALL SELECT 'JSS1 B', 'ENG', 'STF-002'
    UNION ALL SELECT 'JSS1 B', 'MTH', 'STF-003'
    UNION ALL SELECT 'JSS1 B', 'ICT', 'STF-004'
    UNION ALL SELECT 'JSS1 B', 'CRS', 'STF-005'
    UNION ALL SELECT 'JSS1 B', 'HPE', 'STF-006'
    UNION ALL SELECT 'JSS2 A', 'ENG', 'STF-003'
    UNION ALL SELECT 'JSS2 A', 'MTH', 'STF-004'
    UNION ALL SELECT 'JSS2 A', 'BSC', 'STF-005'
    UNION ALL SELECT 'JSS2 A', 'ICT', 'STF-006'
    UNION ALL SELECT 'JSS2 A', 'CIV', 'STF-001'
    UNION ALL SELECT 'JSS2 A', 'HPE', 'STF-002'
) AS v
JOIN classes AS c ON c.class_name = v.class_name
JOIN teachers AS t ON t.staff_no = v.staff_no
ON DUPLICATE KEY UPDATE
    teacher_id = VALUES(teacher_id);

INSERT INTO students
    (admission_no, first_name, last_name, date_of_birth, gender, guardian_name, guardian_phone)
VALUES
    ('SS2026-001', 'Adaeze', 'Okonkwo', '2013-02-14', 'Female', 'Chika Okonkwo', '08045670001'),
    ('SS2026-002', 'Abdulrahman', 'Sani', '2013-06-22', 'Male', 'Musa Sani', '08045670002'),
    ('SS2026-003', 'Tomiwa', 'Adebayo', '2013-09-08', 'Male', 'Kemi Adebayo', '08045670003'),
    ('SS2026-004', 'Zainab', 'Lawal', '2013-01-30', 'Female', 'Aisha Lawal', '08045670004'),
    ('SS2026-005', 'Chisom', 'Nwosu', '2013-11-17', 'Female', 'Emeka Nwosu', '08045670005'),
    ('SS2026-006', 'Faruq', 'Ibrahim', '2013-04-05', 'Male', 'Bilkisu Ibrahim', '08045670006'),
    ('SS2026-007', 'Yetunde', 'Ojo', '2013-07-26', 'Female', 'Babatunde Ojo', '08045670007'),
    ('SS2026-008', 'Obinna', 'Eze', '2013-12-03', 'Male', 'Ngozi Eze', '08045670008'),
    ('SS2026-009', 'Maryam', 'Abubakar', '2013-03-19', 'Female', 'Hauwa Abubakar', '08045670009'),
    ('SS2026-010', 'Samuel', 'Ogunleye', '2013-08-11', 'Male', 'Tosin Ogunleye', '08045670010'),
    ('SS2026-011', 'Amarachi', 'Umeh', '2013-05-02', 'Female', 'Ifeanyi Umeh', '08045670011'),
    ('SS2026-012', 'Danjuma', 'Garba', '2013-10-24', 'Male', 'Fatima Garba', '08045670012'),
    ('SS2026-013', 'Bisola', 'Fashola', '2013-02-07', 'Female', 'Ronke Fashola', '08045670013'),
    ('SS2026-014', 'Kelvin', 'Opara', '2013-06-15', 'Male', 'Grace Opara', '08045670014'),
    ('SS2026-015', 'Safiya', 'Mohammed', '2013-09-29', 'Female', 'Suleiman Mohammed', '08045670015'),
    ('SS2026-016', 'Chukwudi', 'Ibe', '2013-01-12', 'Male', 'Nneka Ibe', '08045670016'),
    ('SS2026-017', 'Morenike', 'Alabi', '2013-11-05', 'Female', 'Seyi Alabi', '08045670017'),
    ('SS2026-018', 'Ismail', 'Tanko', '2013-04-27', 'Male', 'Rabi Tanko', '08045670018'),
    ('SS2026-019', 'Oluwatobi', 'Akinola', '2013-07-09', 'Male', 'Funmi Akinola', '08045670019'),
    ('SS2026-020', 'Nneka', 'Onyema', '2013-12-21', 'Female', 'Peter Onyema', '08045670020'),
    ('SS2026-021', 'Aisha', 'Yahaya', '2012-03-13', 'Female', 'Abubakar Yahaya', '08045670021'),
    ('SS2026-022', 'Bamidele', 'Olaniyan', '2012-08-04', 'Male', 'Bukola Olaniyan', '08045670022'),
    ('SS2026-023', 'Chiamaka', 'Ekwueme', '2012-05-18', 'Female', 'Ikenna Ekwueme', '08045670023'),
    ('SS2026-024', 'Mustapha', 'Adamu', '2012-10-09', 'Male', 'Maryam Adamu', '08045670024'),
    ('SS2026-025', 'Folake', 'Oladipo', '2012-01-25', 'Female', 'Bisi Oladipo', '08045670025'),
    ('SS2026-026', 'Emeka', 'Chukwu', '2012-06-30', 'Male', 'Ngozi Chukwu', '08045670026'),
    ('SS2026-027', 'Hadiza', 'Muktar', '2012-09-14', 'Female', 'Ibrahim Muktar', '08045670027'),
    ('SS2026-028', 'Femi', 'Olawale', '2012-02-02', 'Male', 'Titi Olawale', '08045670028'),
    ('SS2026-029', 'Ijeoma', 'Nnamdi', '2012-11-20', 'Female', 'Chinedu Nnamdi', '08045670029'),
    ('SS2026-030', 'Yusuf', 'Abiola', '2012-04-16', 'Male', 'Bola Abiola', '08045670030')
ON DUPLICATE KEY UPDATE
    first_name = VALUES(first_name),
    last_name = VALUES(last_name),
    date_of_birth = VALUES(date_of_birth),
    gender = VALUES(gender),
    guardian_name = VALUES(guardian_name),
    guardian_phone = VALUES(guardian_phone);

INSERT INTO enrollments (student_id, term_id, class_id)
SELECT s.student_id, tm.term_id,
       CASE
           WHEN CAST(SUBSTRING(s.admission_no, 8) AS UNSIGNED) <= 10 THEN c1.class_id
           WHEN CAST(SUBSTRING(s.admission_no, 8) AS UNSIGNED) <= 20 THEN c2.class_id
           ELSE c3.class_id
       END
FROM students AS s
CROSS JOIN terms AS tm
CROSS JOIN classes AS c1
CROSS JOIN classes AS c2
CROSS JOIN classes AS c3
WHERE s.admission_no BETWEEN 'SS2026-001' AND 'SS2026-030'
  AND tm.term_name = '2026/2027 First Term'
  AND c1.class_name = 'JSS1 A'
  AND c2.class_name = 'JSS1 B'
  AND c3.class_name = 'JSS2 A'
ON DUPLICATE KEY UPDATE
    class_id = VALUES(class_id);

INSERT INTO results (enrollment_id, class_subject_id, ca_score, exam_score)
SELECT e.enrollment_id,
       cs.class_subject_id,
       MOD(e.student_id * 7 + cs.class_subject_id * 3, 41),
       MOD(e.student_id * 11 + cs.class_subject_id * 5, 61)
FROM enrollments AS e
JOIN class_subjects AS cs ON cs.class_id = e.class_id
JOIN terms AS tm ON tm.term_id = e.term_id
WHERE tm.term_name = '2026/2027 First Term'
ON DUPLICATE KEY UPDATE
    ca_score = VALUES(ca_score),
    exam_score = VALUES(exam_score);

INSERT INTO attendance (student_id, attendance_date, status)
SELECT s.student_id,
       d.attendance_date,
       CASE
           WHEN MOD(s.student_id + d.day_number, 11) = 0 THEN 'absent'
           WHEN MOD(s.student_id + d.day_number, 11) IN (1, 2) THEN 'late'
           ELSE 'present'
       END
FROM students AS s
CROSS JOIN (
    SELECT DATE('2026-09-07') AS attendance_date, 0 AS day_number
    UNION ALL SELECT DATE('2026-09-08'), 1
    UNION ALL SELECT DATE('2026-09-09'), 2
    UNION ALL SELECT DATE('2026-09-10'), 3
    UNION ALL SELECT DATE('2026-09-11'), 4
) AS d
WHERE s.admission_no BETWEEN 'SS2026-001' AND 'SS2026-030'
ON DUPLICATE KEY UPDATE
    status = VALUES(status);
