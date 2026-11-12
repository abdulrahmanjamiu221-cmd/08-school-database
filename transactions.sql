-- class_transfers is created by schema.sql. Its audit rows and enrollment
-- updates both use InnoDB, so they commit or roll back together.

-- Example move, with parameters resolved before beginning the transaction.
-- This version assumes the student, term, and target class exist.
SET @student_id = (
    SELECT student_id FROM students WHERE admission_no = 'SS2026-001'
);
SET @term_id = (
    SELECT term_id FROM terms WHERE term_name = '2026/2027 First Term'
);
SET @target_class_id = (
    SELECT class_id FROM classes WHERE class_name = 'JSS2 A'
);

START TRANSACTION;

-- First record the source and destination from the current enrollment.
INSERT INTO class_transfers
    (student_id, term_id, from_class_id, to_class_id)
SELECT
    e.student_id,
    e.term_id,
    e.class_id,
    target.class_id
FROM enrollments AS e
JOIN classes AS target ON target.class_id = @target_class_id
WHERE e.student_id = @student_id
  AND e.term_id = @term_id
  AND e.class_id <> target.class_id;

-- Then change the enrollment. The audit insert and this update are atomic.
UPDATE enrollments AS e
JOIN classes AS target ON target.class_id = @target_class_id
SET e.class_id = target.class_id
WHERE e.student_id = @student_id
  AND e.term_id = @term_id
  AND e.class_id <> target.class_id;

COMMIT;

-- Safer version: call this procedure to validate the destination and current
-- enrollment. It rolls back and raises an error if the target class does not
-- exist, or if the student has no enrollment for the named term.
DROP PROCEDURE IF EXISTS sp_move_student;
DELIMITER $$
CREATE PROCEDURE sp_move_student(
    IN p_admission_no VARCHAR(20),
    IN p_term_name VARCHAR(80),
    IN p_target_class_name VARCHAR(30)
)
BEGIN
    DECLARE v_student_id BIGINT UNSIGNED;
    DECLARE v_term_id BIGINT UNSIGNED;
    DECLARE v_enrollment_id BIGINT UNSIGNED;
    DECLARE v_from_class_id BIGINT UNSIGNED;
    DECLARE v_to_class_id BIGINT UNSIGNED;
    DECLARE v_not_found BOOLEAN DEFAULT FALSE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_not_found = TRUE;

    START TRANSACTION;

    SET v_not_found = FALSE;
    SELECT class_id INTO v_to_class_id
    FROM classes
    WHERE class_name = p_target_class_name
    FOR UPDATE;
    IF v_not_found THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Target class does not exist';
    END IF;

    SET v_not_found = FALSE;
    SELECT s.student_id, t.term_id, e.enrollment_id, e.class_id
    INTO v_student_id, v_term_id, v_enrollment_id, v_from_class_id
    FROM students AS s
    JOIN enrollments AS e ON e.student_id = s.student_id
    JOIN terms AS t ON t.term_id = e.term_id
    WHERE s.admission_no = p_admission_no
      AND t.term_name = p_term_name
    FOR UPDATE;
    IF v_not_found THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Student enrollment for the term was not found';
    END IF;

    IF v_from_class_id = v_to_class_id THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Student is already in the target class';
    END IF;

    INSERT INTO class_transfers
        (student_id, term_id, from_class_id, to_class_id)
    VALUES
        (v_student_id, v_term_id, v_from_class_id, v_to_class_id);

    UPDATE enrollments
    SET class_id = v_to_class_id
    WHERE enrollment_id = v_enrollment_id;

    COMMIT;
END$$
DELIMITER ;

-- Example, valid target:
-- CALL sp_move_student('SS2026-001', '2026/2027 First Term', 'JSS2 A');
-- Example, invalid target: the procedure rolls back and returns an error.
-- CALL sp_move_student('SS2026-001', '2026/2027 First Term', 'NO SUCH CLASS');
