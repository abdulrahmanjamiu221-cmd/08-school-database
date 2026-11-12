# Secondary School Database

MySQL/MariaDB schema and sample data for a secondary school. The schema uses
InnoDB and `utf8mb4`; its `CHECK` constraints require MySQL 8.0.16+ or MariaDB
10.2.1+ for enforcement.

## Load the database

1. In phpMyAdmin, create a database such as `school_db` using
   `utf8mb4_unicode_ci`, then select it in the left sidebar.
2. Use **Import** to load `schema.sql`, then `seed.sql`.
3. Load `queries.sql` to run the example queries and create the two views.
4. Load `procedures.sql` to create `sp_record_result`.
5. To compare query plans, run `indexes.sql` after the seed data is loaded. It
   runs `EXPLAIN` for queries 3, 5, and 7 before and after creating indexes.
6. `transactions.sql` contains a sample class move that runs when the file is
   executed, followed by the `sp_move_student` procedure definition. Run this
   file separately and only when you intend to move its sample student; the
   example moves `SS2026-001` to `JSS2 A`. For later moves, call the procedure
   with the student's admission number, term name, and target class name.

The schema script drops and recreates its tables, so loading it again deletes
the current database data. The seed script can be run again without duplicating
its sample records.

## File guide

| File | Purpose |
|---|---|
| `schema.sql` | Tables, keys, checks, foreign keys, and the class-transfer audit table |
| `seed.sql` | Nigerian sample data, results, and five weekdays of attendance |
| `queries.sql` | Eight business queries and the `v_student_results` and `v_class_summary` views |
| `indexes.sql` | Before/after `EXPLAIN` statements and query-supporting indexes |
| `procedures.sql` | Validated `sp_record_result` procedure |
| `transactions.sql` | Example class-transfer transaction and validated `sp_move_student` procedure |

## Entity relationship diagram

```mermaid
erDiagram
    STUDENT {
        bigint student_id PK
        string admission_no UK
        string first_name
        string last_name
        date date_of_birth
        enum gender
        string guardian_name
        string guardian_phone
    }

    TEACHER {
        bigint teacher_id PK
        string staff_no UK
        string first_name
        string last_name
        string email UK
        string phone
        date hire_date
    }

    CLASS {
        bigint class_id PK
        string class_name UK
        bigint form_teacher_id FK
    }

    SUBJECT {
        string subject_code PK
        string subject_name UK
    }

    TERM {
        bigint term_id PK
        string term_name UK
        date start_date
        date end_date
    }

    ENROLLMENT {
        bigint enrollment_id PK
        bigint student_id FK
        bigint term_id FK
        bigint class_id FK
    }

    CLASS_SUBJECT {
        bigint class_subject_id PK
        bigint class_id FK
        string subject_code FK
        bigint teacher_id FK
    }

    RESULT {
        bigint enrollment_id PK, FK
        bigint class_subject_id PK, FK
        decimal ca_score
        decimal exam_score
    }

    ATTENDANCE {
        bigint student_id PK, FK
        date attendance_date PK
        enum status
    }

    CLASS_TRANSFER {
        bigint transfer_id PK
        bigint student_id FK
        bigint term_id FK
        bigint from_class_id FK
        bigint to_class_id FK
        timestamp transferred_at
    }

    TEACHER ||--o{ CLASS : form_teacher_for
    STUDENT ||--o{ ENROLLMENT : enrolls
    TERM ||--o{ ENROLLMENT : includes
    CLASS ||--o{ ENROLLMENT : receives
    CLASS ||--o{ CLASS_SUBJECT : offers
    SUBJECT ||--o{ CLASS_SUBJECT : assigned_to
    TEACHER ||--o{ CLASS_SUBJECT : teaches
    ENROLLMENT ||--o{ RESULT : receives
    CLASS_SUBJECT ||--o{ RESULT : assessed_as
    STUDENT ||--o{ ATTENDANCE : has
    STUDENT ||--o{ CLASS_TRANSFER : moves
    TERM ||--o{ CLASS_TRANSFER : records
    CLASS ||--o{ CLASS_TRANSFER : source_or_destination
```

`ENROLLMENT` records a student's class for a particular term. `CLASS_SUBJECT`
assigns one teacher to each class-subject pair. Results link an enrollment to
one of that class's subject assignments. The result primary key prevents a
duplicate result for the same enrollment and subject assignment; the
enrollment and class-subject uniqueness rules make this one result per student,
subject, and term.

## Three queries worth exploring

### Query 3: class positions with `RANK()`

This query first calculates one average per student, then ranks those averages
within each class. `PARTITION BY class_id` restarts ranking for every class.
Students with tied averages receive the same rank, and the next rank is skipped
(for example, `1, 2, 2, 4`). The file also provides a correlated-subquery
fallback for MySQL versions without window functions.

### Query 5: identifying students who need support

The query groups scores by student and uses `HAVING` to keep only students with
at least two subject totals below 40. `HAVING` is applied after aggregation;
`WHERE` cannot filter on that aggregate count.

### Query 7: attendance percentage

The query uses a `LEFT JOIN` so students with no attendance rows still appear,
counts `present` and `late` as attended, and divides by each student's recorded
attendance rows. With no records, it reports 0%. For a specific reporting
period, filter attendance dates in the join so students with no records in that
period are still included.

## Understanding `EXPLAIN` and the added indexes

In tabular `EXPLAIN` output:

- **`type`** describes how MySQL accesses a table. `const` and `eq_ref` usually
  mean very selective unique-key lookups; `ref` is an indexed equality lookup;
  `range` reads an index range; `ALL` scans the table.
- **`key`** is the index the optimizer chose. `NULL` means it chose no index for
  that table access.
- **`rows`** is an estimate of rows examined for that access, not an actual
  measurement. Estimates depend on table size and refreshed statistics.

Before the added indexes, queries 3 and 5 can use the existing
`ix_enrollments_term_class` to find enrollments for a term and the results
primary key to look up results by enrollment. The new
`ix_enrollments_term_class_student` can also cover the student/class grouping
columns, while `ix_results_enrollment_scores` may cover score reads without
fetching each clustered result row. Query 7 can use the attendance primary key
by its `student_id` prefix; `ix_attendance_student_status` can cover both the
join and status aggregation.

| Query | Likely access before | Likely access after |
|---|---|---|
| 3: class averages/rank | Enrollments via `ix_enrollments_term_class`; results via `PRIMARY` on `enrollment_id` | Enrollments may use `ix_enrollments_term_class_student`; results may use `ix_results_enrollment_scores` |
| 5: failed subjects | Same term-to-enrollment and enrollment-to-results access | Same candidate indexes as query 3 |
| 7: attendance percentage | Attendance via the `student_id` prefix of `PRIMARY` | Attendance may use `ix_attendance_student_status` as a covering index |

These are candidate access paths, not captured output. In each actual EXPLAIN
row, check `type` for the access method, `key` for the chosen index, and `rows`
for the optimizer's estimated rows. The indexes are useful only if the
optimizer selects them; with the small sample data, it may prefer a table scan
or keep using an existing key. No live MySQL/MariaDB server was available while
preparing this project, so the `indexes.sql` statements are provided to capture
the actual before/after plans on your database rather than inventing estimates.

Run the first three plans in `indexes.sql`, create its indexes, then compare the
last three plans. Indexes improve some reads at the cost of storage and slower
writes, so keep them only when plans and real workloads justify them.

## Export the full database from phpMyAdmin

1. Select the database in the left sidebar.
2. Click **Export**.
3. Choose **Custom** if you need to verify all tables, views, and stored
   procedures are selected; otherwise **Quick** with **SQL** is suitable for a
   straightforward database dump.
4. Set the format to **SQL** and, if using Custom, include structure and data.
   Enable routine export if your phpMyAdmin version offers that option and you
   want stored procedures included.
5. Click **Go** to download the dump. Save or rename the downloaded file as
   `database.sql`.
