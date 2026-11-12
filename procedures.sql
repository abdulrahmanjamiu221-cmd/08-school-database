-- Record or update one student's result for a subject in a term.
-- p_admission_no, p_subject_code, and p_term_name identify the student,
-- assigned subject, and term. This procedure owns its transaction.

DROP PROCEDURE IF EXISTS sp_record_result;
DELIMITER $$
CREATE PROCEDURE sp_record_result(
    IN p_admission_no VARCHAR(20),
    IN p_subject_code VARCHAR(12),
    IN p_term_name VARCHAR(80),
    IN p_ca_score DECIMAL(5,2),
    IN p_exam_score DECIMAL(5,2)
)
BEGIN
    DECLARE v_student_id BIGINT UNSIGNED;
    DECLARE v_term_id BIGINT UNSIGNED;
    DECLARE v_enrollment_id BIGINT UNSIGNED;
    DECLARE v_class_id BIGINT UNSIGNED;
    DECLARE v_class_subject_id BIGINT UNSIGNED;
    DECLARE v_not_found BOOLEAN DEFAULT FALSE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_not_found = TRUE;

    IF p_admission_no IS NULL OR TRIM(p_admission_no) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Admission number is required';
    END IF;
    IF p_subject_code IS NULL OR TRIM(p_subject_code) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject code is required';
    END IF;
    IF p_term_name IS NULL OR TRIM(p_term_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Term name is required';
    END IF;
    IF p_ca_score IS NULL OR p_ca_score < 0 OR p_ca_score > 40 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CA score must be between 0 and 40';
    END IF;
    IF p_exam_score IS NULL OR p_exam_score < 0 OR p_exam_score > 60 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Exam score must be between 0 and 60';
    END IF;

    START TRANSACTION;

    SET v_not_found = FALSE;
    SELECT student_id INTO v_student_id
    FROM students
    WHERE admission_no = p_admission_no
    FOR UPDATE;
    IF v_not_found THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student admission number was not found';
    END IF;

    SET v_not_found = FALSE;
    SELECT term_id INTO v_term_id
    FROM terms
    WHERE term_name = p_term_name
    FOR UPDATE;
    IF v_not_found THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Term was not found';
    END IF;

    SET v_not_found = FALSE;
    SELECT enrollment_id, class_id
    INTO v_enrollment_id, v_class_id
    FROM enrollments
    WHERE student_id = v_student_id
      AND term_id = v_term_id
    FOR UPDATE;
    IF v_not_found THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student is not enrolled for this term';
    END IF;

    SET v_not_found = FALSE;
    SELECT class_subject_id INTO v_class_subject_id
    FROM class_subjects
    WHERE class_id = v_class_id
      AND subject_code = p_subject_code
    FOR UPDATE;
    IF v_not_found THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Subject is not assigned to the student class';
    END IF;

    INSERT INTO results (enrollment_id, class_subject_id, ca_score, exam_score)
    VALUES (v_enrollment_id, v_class_subject_id, p_ca_score, p_exam_score)
    ON DUPLICATE KEY UPDATE
        ca_score = VALUES(ca_score),
        exam_score = VALUES(exam_score);

    COMMIT;
END$$
DELIMITER ;

-- Example:
-- CALL sp_record_result('SS2026-001', 'ENG', '2026/2027 First Term', 32, 48);
