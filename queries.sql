-- Queries and views for the school database.
-- These statements use the table and column names from schema.sql.

-- 1. Business question: Which students are enrolled in JSS1 A, and who is their form teacher?
-- Technique: JOIN students to term-specific enrollments and join the class's form teacher.
SELECT
    c.class_name,
    s.admission_no,
    CONCAT_WS(' ', s.first_name, s.last_name) AS student_name,
    CONCAT_WS(' ', ft.first_name, ft.last_name) AS form_teacher_name
FROM classes AS c
JOIN teachers AS ft ON ft.teacher_id = c.form_teacher_id
JOIN enrollments AS e ON e.class_id = c.class_id
JOIN students AS s ON s.student_id = e.student_id
JOIN terms AS t ON t.term_id = e.term_id
WHERE c.class_name = 'JSS1 A'
  AND t.term_name = '2026/2027 First Term'
ORDER BY s.last_name, s.first_name;

-- 2. Business question: What is each student's total and letter grade for every subject this term?
-- Technique: Calculate CA + exam and use CASE for the grading bands (A >= 80, B >= 70,
-- C >= 60, D >= 50, E >= 40, otherwise F).
SELECT
    s.admission_no,
    CONCAT_WS(' ', s.first_name, s.last_name) AS student_name,
    c.class_name,
    sub.subject_code,
    sub.subject_name,
    r.ca_score,
    r.exam_score,
    r.ca_score + r.exam_score AS total_score,
    CASE
        WHEN r.ca_score + r.exam_score >= 80 THEN 'A'
        WHEN r.ca_score + r.exam_score >= 70 THEN 'B'
        WHEN r.ca_score + r.exam_score >= 60 THEN 'C'
        WHEN r.ca_score + r.exam_score >= 50 THEN 'D'
        WHEN r.ca_score + r.exam_score >= 40 THEN 'E'
        ELSE 'F'
    END AS grade
FROM results AS r
JOIN enrollments AS e ON e.enrollment_id = r.enrollment_id
JOIN students AS s ON s.student_id = e.student_id
JOIN classes AS c ON c.class_id = e.class_id
JOIN class_subjects AS cs ON cs.class_subject_id = r.class_subject_id
JOIN subjects AS sub ON sub.subject_code = cs.subject_code
JOIN terms AS t ON t.term_id = e.term_id
WHERE t.term_name = '2026/2027 First Term'
ORDER BY c.class_name, s.last_name, s.first_name, sub.subject_name;

-- 3. Business question: What is each student's average score and rank within their class this term?
-- Technique: Aggregate one average per student, then use RANK() partitioned by class.
-- RANK gives tied averages the same position and leaves gaps after ties.
WITH student_averages AS (
    SELECT
        e.class_id,
        c.class_name,
        e.student_id,
        s.admission_no,
        CONCAT_WS(' ', s.first_name, s.last_name) AS student_name,
        AVG(r.ca_score + r.exam_score) AS average_score
    FROM enrollments AS e
    JOIN terms AS t ON t.term_id = e.term_id
    JOIN classes AS c ON c.class_id = e.class_id
    JOIN students AS s ON s.student_id = e.student_id
    JOIN results AS r ON r.enrollment_id = e.enrollment_id
    WHERE t.term_name = '2026/2027 First Term'
    GROUP BY e.class_id, c.class_name, e.student_id, s.admission_no,
             s.first_name, s.last_name
)
SELECT
    class_name,
    admission_no,
    student_name,
    ROUND(average_score, 2) AS average_score,
    RANK() OVER (PARTITION BY class_id ORDER BY average_score DESC) AS class_position
FROM student_averages
ORDER BY class_name, class_position, admission_no;

-- 3 (older MySQL fallback). Use this instead of the window-function query above
-- on MySQL versions without window functions. The correlated count of higher
-- averages reproduces RANK semantics, including tied positions and gaps.
SELECT
    current_students.class_name,
    current_students.admission_no,
    current_students.student_name,
    ROUND(current_students.average_score, 2) AS average_score,
    1 + (
        SELECT COUNT(*)
        FROM (
            SELECT
                e2.class_id,
                e2.student_id,
                AVG(r2.ca_score + r2.exam_score) AS average_score
            FROM enrollments AS e2
            JOIN terms AS t2 ON t2.term_id = e2.term_id
            JOIN results AS r2 ON r2.enrollment_id = e2.enrollment_id
            WHERE t2.term_name = '2026/2027 First Term'
            GROUP BY e2.class_id, e2.student_id
        ) AS peer_averages
        WHERE peer_averages.class_id = current_students.class_id
          AND peer_averages.average_score > current_students.average_score
    ) AS class_position
FROM (
    SELECT
        e.class_id,
        c.class_name,
        e.student_id,
        s.admission_no,
        CONCAT_WS(' ', s.first_name, s.last_name) AS student_name,
        AVG(r.ca_score + r.exam_score) AS average_score
    FROM enrollments AS e
    JOIN terms AS t ON t.term_id = e.term_id
    JOIN classes AS c ON c.class_id = e.class_id
    JOIN students AS s ON s.student_id = e.student_id
    JOIN results AS r ON r.enrollment_id = e.enrollment_id
    WHERE t.term_name = '2026/2027 First Term'
    GROUP BY e.class_id, c.class_name, e.student_id, s.admission_no,
             s.first_name, s.last_name
) AS current_students
ORDER BY current_students.class_name, class_position, current_students.admission_no;

-- 4. Business question: What are the average, highest, and lowest scores per subject in each class?
-- Technique: GROUP BY class and subject, with AVG, MAX, and MIN over each result total.
SELECT
    c.class_name,
    sub.subject_code,
    sub.subject_name,
    COUNT(r.enrollment_id) AS result_count,
    ROUND(AVG(r.ca_score + r.exam_score), 2) AS average_score,
    MAX(r.ca_score + r.exam_score) AS highest_score,
    MIN(r.ca_score + r.exam_score) AS lowest_score
FROM class_subjects AS cs
JOIN classes AS c ON c.class_id = cs.class_id
JOIN subjects AS sub ON sub.subject_code = cs.subject_code
JOIN results AS r ON r.class_subject_id = cs.class_subject_id
JOIN enrollments AS e ON e.enrollment_id = r.enrollment_id
JOIN terms AS t ON t.term_id = e.term_id
WHERE t.term_name = '2026/2027 First Term'
GROUP BY c.class_id, c.class_name, sub.subject_code, sub.subject_name
ORDER BY c.class_name, sub.subject_name;

-- 5. Business question: Which students scored below 40 in at least two subjects this term?
-- Technique: Group each student's results and use HAVING to filter the failed-subject count.
SELECT
    s.admission_no,
    CONCAT_WS(' ', s.first_name, s.last_name) AS student_name,
    c.class_name,
    SUM(CASE WHEN r.ca_score + r.exam_score < 40 THEN 1 ELSE 0 END) AS failed_subject_count
FROM results AS r
JOIN enrollments AS e ON e.enrollment_id = r.enrollment_id
JOIN students AS s ON s.student_id = e.student_id
JOIN classes AS c ON c.class_id = e.class_id
JOIN terms AS t ON t.term_id = e.term_id
WHERE t.term_name = '2026/2027 First Term'
GROUP BY s.student_id, s.admission_no, s.first_name, s.last_name,
         c.class_id, c.class_name
HAVING SUM(CASE WHEN r.ca_score + r.exam_score < 40 THEN 1 ELSE 0 END) >= 2
ORDER BY c.class_name, s.last_name, s.first_name;

-- 6. Business question: How many distinct subjects and classes does each teacher teach?
-- Technique: LEFT JOIN retains teachers without assignments; COUNT(DISTINCT) avoids
-- counting the same class or subject more than once.
SELECT
    t.teacher_id,
    t.staff_no,
    CONCAT_WS(' ', t.first_name, t.last_name) AS teacher_name,
    COUNT(DISTINCT cs.subject_code) AS subjects_taught,
    COUNT(DISTINCT cs.class_id) AS classes_taught
FROM teachers AS t
LEFT JOIN class_subjects AS cs ON cs.teacher_id = t.teacher_id
GROUP BY t.teacher_id, t.staff_no, t.first_name, t.last_name
ORDER BY teacher_name;

-- 7. Business question: What percentage of recorded school days did each student attend,
-- and who is below 80%? Here, both present and late count as attended.
-- Technique: Aggregate attendance in a derived table, then filter the calculated percentage.
-- Students with no attendance rows are included at 0%; the denominator is each student's
-- recorded attendance rows, so limit the underlying attendance data to the desired period
-- first if reporting a specific date range.
SELECT
    attendance_summary.admission_no,
    attendance_summary.student_name,
    attendance_summary.days_recorded,
    attendance_summary.days_attended,
    attendance_summary.attendance_percentage
FROM (
    SELECT
        s.student_id,
        s.admission_no,
        CONCAT_WS(' ', s.first_name, s.last_name) AS student_name,
        COUNT(a.attendance_date) AS days_recorded,
        SUM(CASE WHEN a.status IN ('present', 'late') THEN 1 ELSE 0 END) AS days_attended,
        CASE
            WHEN COUNT(a.attendance_date) = 0 THEN 0
            ELSE ROUND(
                100.0 * SUM(CASE WHEN a.status IN ('present', 'late') THEN 1 ELSE 0 END)
                / COUNT(a.attendance_date),
                2
            )
        END AS attendance_percentage
    FROM students AS s
    LEFT JOIN attendance AS a ON a.student_id = s.student_id
    GROUP BY s.student_id, s.admission_no, s.first_name, s.last_name
) AS attendance_summary
WHERE attendance_summary.attendance_percentage < 80
ORDER BY attendance_summary.attendance_percentage, attendance_summary.admission_no;

-- 8. Business question: Who is the top student in each class this term?
-- Technique: Rank students by their average across subjects within each class.
-- RANK returns all students tied for the top average.
WITH student_averages AS (
    SELECT
        e.class_id,
        c.class_name,
        s.admission_no,
        CONCAT_WS(' ', s.first_name, s.last_name) AS student_name,
        AVG(r.ca_score + r.exam_score) AS average_score
    FROM enrollments AS e
    JOIN terms AS t ON t.term_id = e.term_id
    JOIN classes AS c ON c.class_id = e.class_id
    JOIN students AS s ON s.student_id = e.student_id
    JOIN results AS r ON r.enrollment_id = e.enrollment_id
    WHERE t.term_name = '2026/2027 First Term'
    GROUP BY e.class_id, c.class_name, e.student_id, s.admission_no,
             s.first_name, s.last_name
),
ranked_students AS (
    SELECT
        class_name,
        admission_no,
        student_name,
        average_score,
        RANK() OVER (PARTITION BY class_id ORDER BY average_score DESC) AS class_position
    FROM student_averages
)
SELECT
    class_name,
    admission_no,
    student_name,
    ROUND(average_score, 2) AS average_score
FROM ranked_students
WHERE class_position = 1
ORDER BY class_name, admission_no;

-- View: one row per student, subject, and term result, with identifying details,
-- the total score, and its letter grade.
CREATE OR REPLACE VIEW v_student_results AS
SELECT
    s.admission_no,
    CONCAT_WS(' ', s.first_name, s.last_name) AS student_name,
    c.class_name,
    t.term_name,
    sub.subject_code,
    sub.subject_name,
    r.ca_score,
    r.exam_score,
    r.ca_score + r.exam_score AS total_score,
    CASE
        WHEN r.ca_score + r.exam_score >= 80 THEN 'A'
        WHEN r.ca_score + r.exam_score >= 70 THEN 'B'
        WHEN r.ca_score + r.exam_score >= 60 THEN 'C'
        WHEN r.ca_score + r.exam_score >= 50 THEN 'D'
        WHEN r.ca_score + r.exam_score >= 40 THEN 'E'
        ELSE 'F'
    END AS grade
FROM results AS r
JOIN enrollments AS e ON e.enrollment_id = r.enrollment_id
JOIN students AS s ON s.student_id = e.student_id
JOIN classes AS c ON c.class_id = e.class_id
JOIN terms AS t ON t.term_id = e.term_id
JOIN class_subjects AS cs ON cs.class_subject_id = r.class_subject_id
JOIN subjects AS sub ON sub.subject_code = cs.subject_code;

-- View: one row per class and term, summarizing enrollment, offered subjects,
-- and the class's result-score range and average.
CREATE OR REPLACE VIEW v_class_summary AS
SELECT
    c.class_id,
    c.class_name,
    t.term_id,
    t.term_name,
    COUNT(DISTINCT e.student_id) AS student_count,
    COUNT(DISTINCT cs.subject_code) AS subject_count,
    ROUND(AVG(r.ca_score + r.exam_score), 2) AS average_score,
    MAX(r.ca_score + r.exam_score) AS highest_score,
    MIN(r.ca_score + r.exam_score) AS lowest_score
FROM classes AS c
CROSS JOIN terms AS t
LEFT JOIN enrollments AS e
    ON e.class_id = c.class_id
   AND e.term_id = t.term_id
LEFT JOIN class_subjects AS cs ON cs.class_id = c.class_id
LEFT JOIN results AS r
    ON r.enrollment_id = e.enrollment_id
   AND r.class_subject_id = cs.class_subject_id
GROUP BY c.class_id, c.class_name, t.term_id, t.term_name;
