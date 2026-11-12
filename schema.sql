-- Secondary school database schema for MySQL 8.0.16+ / MariaDB 10.2.1+
-- CHECK constraints are enforced in these versions and later.

DROP TABLE IF EXISTS attendance;
DROP TABLE IF EXISTS results;
DROP TABLE IF EXISTS class_subjects;
DROP TABLE IF EXISTS enrollments;
DROP TABLE IF EXISTS classes;
DROP TABLE IF EXISTS subjects;
DROP TABLE IF EXISTS terms;
DROP TABLE IF EXISTS teachers;
DROP TABLE IF EXISTS students;

CREATE TABLE students (
    student_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    admission_no VARCHAR(20) NOT NULL,
    first_name VARCHAR(60) NOT NULL,
    last_name VARCHAR(60) NOT NULL,
    date_of_birth DATE NOT NULL,
    gender ENUM('Male', 'Female', 'Other', 'Prefer not to say') NOT NULL,
    guardian_name VARCHAR(120) NOT NULL,
    guardian_phone VARCHAR(25) NOT NULL,
    PRIMARY KEY (student_id),
    CONSTRAINT uq_students_admission_no UNIQUE (admission_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE teachers (
    teacher_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    staff_no VARCHAR(20) NOT NULL,
    first_name VARCHAR(60) NOT NULL,
    last_name VARCHAR(60) NOT NULL,
    email VARCHAR(254) NOT NULL,
    phone VARCHAR(25) NOT NULL,
    hire_date DATE NOT NULL,
    PRIMARY KEY (teacher_id),
    CONSTRAINT uq_teachers_staff_no UNIQUE (staff_no),
    CONSTRAINT uq_teachers_email UNIQUE (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE terms (
    term_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    term_name VARCHAR(80) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    PRIMARY KEY (term_id),
    CONSTRAINT uq_terms_name UNIQUE (term_name),
    CONSTRAINT chk_terms_date_range CHECK (end_date >= start_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE subjects (
    subject_code VARCHAR(12) NOT NULL,
    subject_name VARCHAR(100) NOT NULL,
    PRIMARY KEY (subject_code),
    CONSTRAINT uq_subjects_name UNIQUE (subject_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE classes (
    class_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    class_name VARCHAR(30) NOT NULL,
    form_teacher_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (class_id),
    CONSTRAINT uq_classes_name UNIQUE (class_name),
    KEY ix_classes_form_teacher (form_teacher_id),
    -- RESTRICT prevents deleting a teacher who is still a form teacher; CASCADE
    -- on update keeps the reference aligned if a teacher ID is changed.
    CONSTRAINT fk_classes_form_teacher
        FOREIGN KEY (form_teacher_id) REFERENCES teachers (teacher_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE enrollments (
    enrollment_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    student_id BIGINT UNSIGNED NOT NULL,
    term_id BIGINT UNSIGNED NOT NULL,
    class_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (enrollment_id),
    CONSTRAINT uq_enrollments_student_term UNIQUE (student_id, term_id),
    KEY ix_enrollments_term_class (term_id, class_id),
    -- RESTRICT preserves enrollment history; CASCADE on update maintains the
    -- reference if a parent key is changed.
    CONSTRAINT fk_enrollments_student
        FOREIGN KEY (student_id) REFERENCES students (student_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    -- RESTRICT prevents removing a term that has enrollment records.
    CONSTRAINT fk_enrollments_term
        FOREIGN KEY (term_id) REFERENCES terms (term_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    -- RESTRICT prevents removing a class used by enrollment history.
    CONSTRAINT fk_enrollments_class
        FOREIGN KEY (class_id) REFERENCES classes (class_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE class_subjects (
    class_subject_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    class_id BIGINT UNSIGNED NOT NULL,
    subject_code VARCHAR(12) NOT NULL,
    teacher_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (class_subject_id),
    CONSTRAINT uq_class_subjects_class_subject UNIQUE (class_id, subject_code),
    KEY ix_class_subjects_subject (subject_code),
    KEY ix_class_subjects_teacher (teacher_id),
    -- RESTRICT protects teaching assignments; CASCADE on update maintains
    -- references if a class key changes.
    CONSTRAINT fk_class_subjects_class
        FOREIGN KEY (class_id) REFERENCES classes (class_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    -- RESTRICT prevents deleting a subject still offered to a class.
    CONSTRAINT fk_class_subjects_subject
        FOREIGN KEY (subject_code) REFERENCES subjects (subject_code)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    -- RESTRICT prevents deleting a teacher with assigned classes/subjects.
    CONSTRAINT fk_class_subjects_teacher
        FOREIGN KEY (teacher_id) REFERENCES teachers (teacher_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE results (
    enrollment_id BIGINT UNSIGNED NOT NULL,
    class_subject_id BIGINT UNSIGNED NOT NULL,
    ca_score DECIMAL(5,2) NOT NULL,
    exam_score DECIMAL(5,2) NOT NULL,
    PRIMARY KEY (enrollment_id, class_subject_id),
    -- RESTRICT avoids silently discarding academic results when an enrollment
    -- is removed; CASCADE on update keeps the foreign key valid.
    CONSTRAINT fk_results_enrollment
        FOREIGN KEY (enrollment_id) REFERENCES enrollments (enrollment_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    -- RESTRICT protects results if a class-subject assignment is removed.
    CONSTRAINT fk_results_class_subject
        FOREIGN KEY (class_subject_id) REFERENCES class_subjects (class_subject_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_results_ca_score CHECK (ca_score >= 0 AND ca_score <= 40),
    CONSTRAINT chk_results_exam_score CHECK (exam_score >= 0 AND exam_score <= 60)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE attendance (
    student_id BIGINT UNSIGNED NOT NULL,
    attendance_date DATE NOT NULL,
    status ENUM('present', 'absent', 'late') NOT NULL,
    PRIMARY KEY (student_id, attendance_date),
    KEY ix_attendance_date (attendance_date),
    -- RESTRICT preserves the attendance record; CASCADE on update maintains
    -- its student reference if a parent key is changed.
    CONSTRAINT fk_attendance_student
        FOREIGN KEY (student_id) REFERENCES students (student_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
