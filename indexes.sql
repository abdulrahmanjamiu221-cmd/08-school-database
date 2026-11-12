-- EXPLAIN before/after index comparison for queries 3, 5, and 7 from queries.sql.
-- Run this file once against a loaded database. The first three plans are captured
-- before the CREATE INDEX statements; the final three are after them.
-- EXPLAIN output depends on server version, statistics, and row counts. In particular,
-- the 30-student seed set may be small enough that MySQL prefers a table scan.

-- BEFORE INDEXES: Query 3, student averages and class ranking.
EXPLAIN
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

-- BEFORE INDEXES: Query 5, students failing at least two subjects.
EXPLAIN
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

-- BEFORE INDEXES: Query 7, attendance percentage and students below 80%.
EXPLAIN
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

-- ADD INDEXES:
-- This covers term/class/student grouping and preserves enrollment_id through
-- InnoDB's primary-key suffix on secondary-index entries.
CREATE INDEX ix_enrollments_term_class_student
    ON enrollments (term_id, class_id, student_id);

-- The results primary key already supports enrollment_id lookups. This covering
-- index can avoid fetching result rows from the clustered primary-key index for
-- the score aggregation in queries 3 and 5.
CREATE INDEX ix_results_enrollment_scores
    ON results (enrollment_id, ca_score, exam_score);

-- The student_id prefix supports the attendance join; status is included so the
-- percentage aggregation can be covered by the secondary index.
CREATE INDEX ix_attendance_student_status
    ON attendance (student_id, status);

-- AFTER INDEXES: Re-run the same EXPLAIN statements above and compare type, key,
-- rows, and Extra. EXPLAIN reports estimates, not measured execution counts.

-- AFTER INDEXES: Query 3.
EXPLAIN
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

-- AFTER INDEXES: Query 5.
EXPLAIN
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

-- AFTER INDEXES: Query 7.
EXPLAIN
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
