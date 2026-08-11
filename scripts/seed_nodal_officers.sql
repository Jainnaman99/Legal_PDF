-- ============================================================
-- Seed Nodal Officer users (14 departments)
-- Username format : Nodal.<ShortForm>
-- Role            : nodal Officer (id = 8)
-- Default password: same as AdmSec seed — must be changed on
--                   first login (must_change_password = 1)
--
-- Run via:
--   mysql -u root -p legal_pdf < scripts/seed_nodal_officers.sql
-- ============================================================

USE legal_pdf;

-- ── 0. Ensure all required departments exist ──────────────────
-- INSERT IGNORE skips rows whose name already exists (UNIQUE).
-- New departments (HVPNL, DHBVNL, HPGCL, etc.) are created here.

INSERT IGNORE INTO departments (name, is_active, created_at) VALUES
    ('Urban Local Bodies (ULB)',                            1, UTC_TIMESTAMP(6)),
    ('Revenue and Disaster Management',                     1, UTC_TIMESTAMP(6)),
    ('Archives Department',                                 1, UTC_TIMESTAMP(6)),
    ('Information, Public Relations & Languages (IPRL)',    1, UTC_TIMESTAMP(6)),
    ('Central Committee of Examinations',                   1, UTC_TIMESTAMP(6)),
    ('HARTRON',                                             1, UTC_TIMESTAMP(6)),
    ('HVPNL',                                               1, UTC_TIMESTAMP(6)),
    ('Architecture Department',                             1, UTC_TIMESTAMP(6)),
    ('DHBVNL',                                              1, UTC_TIMESTAMP(6)),
    ('Irrigation & Water Resources Department',             1, UTC_TIMESTAMP(6)),
    ('Employment Department',                               1, UTC_TIMESTAMP(6)),
    ('Excise and Taxation Department',                      1, UTC_TIMESTAMP(6)),
    ('HPGCL',                                               1, UTC_TIMESTAMP(6)),
    ('Science and Technology (Department of Higher Education)', 1, UTC_TIMESTAMP(6));

-- ── 1. Insert Nodal Officer users ────────────────────────────
-- Each INSERT … SELECT resolves the department id at runtime.
-- If a username already exists the INSERT will fail — remove
-- that row or change the username before re-running.

SET @role_id = (SELECT id FROM roles WHERE name = 'nodal Officer' LIMIT 1);
SET @pwd     = '$2b$12$geno.584ZaUUZjZIJ8zeCuujAv.kfDR3RnJx0coJWylRXhO8CxpHW';

-- 1. Urban Local Bodies
INSERT INTO users (username, email, hashed_password, is_active, must_change_password,
                   mobile_number, first_name, last_name, role_id, department_id, created_at, updated_at)
SELECT 'Nodal.ULB', 'legalcell-dulb@ulbharyana.gov.in', @pwd, 1, 1,
       '8708866261', 'Yashvir Singh', 'Sheoran',
       @role_id, CAST(id AS CHAR), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)
FROM departments WHERE name = 'Urban Local Bodies (ULB)';

-- 2. Revenue and Disaster Management  (no email provided)
INSERT INTO users (username, email, hashed_password, is_active, must_change_password,
                   mobile_number, first_name, last_name, role_id, department_id, created_at, updated_at)
SELECT 'Nodal.RevDM', NULL, @pwd, 1, 1,
       '9417449848', 'Ved Parkash', 'Dull',
       @role_id, CAST(id AS CHAR), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)
FROM departments WHERE name = 'Revenue and Disaster Management';

-- 3. Archives
INSERT INTO users (username, email, hashed_password, is_active, must_change_password,
                   mobile_number, first_name, last_name, role_id, department_id, created_at, updated_at)
SELECT 'Nodal.Archives', 'archives@hry.nic.in', @pwd, 1, 1,
       '9992026896', 'Anil', 'Kumar',
       @role_id, CAST(id AS CHAR), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)
FROM departments WHERE name = 'Archives Department';

-- 4. Information, Public Relations and Languages
INSERT INTO users (username, email, hashed_password, is_active, must_change_password,
                   mobile_number, first_name, last_name, role_id, department_id, created_at, updated_at)
SELECT 'Nodal.IPRL', 'dd-press.dipr@hry.gov.in', @pwd, 1, 1,
       '9417074593', 'Seema', 'Arora',
       @role_id, CAST(id AS CHAR), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)
FROM departments WHERE name = 'Information, Public Relations & Languages (IPRL)';

-- 5. Central Committee of Examinations
INSERT INTO users (username, email, hashed_password, is_active, must_change_password,
                   mobile_number, first_name, last_name, role_id, department_id, created_at, updated_at)
SELECT 'Nodal.CCE', 'usexaminationscell@gmail.com', @pwd, 1, 1,
       '9876277086', 'Anita', 'Malik',
       @role_id, CAST(id AS CHAR), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)
FROM departments WHERE name = 'Central Committee of Examinations';

-- 6. HARTRON
INSERT INTO users (username, email, hashed_password, is_active, must_change_password,
                   mobile_number, first_name, last_name, role_id, department_id, created_at, updated_at)
SELECT 'Nodal.HARTRON', 'santoshranahartron@gmail.com', @pwd, 1, 1,
       '9023562306', 'Santosh', 'Rana',
       @role_id, CAST(id AS CHAR), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)
FROM departments WHERE name = 'HARTRON';

-- 7. HVPNL
INSERT INTO users (username, email, hashed_password, is_active, must_change_password,
                   mobile_number, first_name, last_name, role_id, department_id, created_at, updated_at)
SELECT 'Nodal.HVPNL', 'seit@hvpn.org.in', @pwd, 1, 1,
       '9316369277', 'Mohd. Asif', 'Equbal',
       @role_id, CAST(id AS CHAR), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)
FROM departments WHERE name = 'HVPNL';

-- 8. Architecture
INSERT INTO users (username, email, hashed_password, is_active, must_change_password,
                   mobile_number, first_name, last_name, role_id, department_id, created_at, updated_at)
SELECT 'Nodal.Arch', 'Cahry@hry.nic.in', @pwd, 1, 1,
       '9911606008', 'Lalit', 'Kumar',
       @role_id, CAST(id AS CHAR), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)
FROM departments WHERE name = 'Architecture Department';

-- 9. DHBVNL
INSERT INTO users (username, email, hashed_password, is_active, must_change_password,
                   mobile_number, first_name, last_name, role_id, department_id, created_at, updated_at)
SELECT 'Nodal.DHBVNL', 'seit@dhbvn.org.in', @pwd, 1, 1,
       '9467602007', 'Vikas', 'Kadian',
       @role_id, CAST(id AS CHAR), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)
FROM departments WHERE name = 'DHBVNL';

-- 10. Irrigation & Water Resources
INSERT INTO users (username, email, hashed_password, is_active, must_change_password,
                   mobile_number, first_name, last_name, role_id, department_id, created_at, updated_at)
SELECT 'Nodal.IWR', 'Dpu277@gmail.com', @pwd, 1, 1,
       '9999194737', 'Rajkumar', 'Lawania',
       @role_id, CAST(id AS CHAR), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)
FROM departments WHERE name = 'Irrigation & Water Resources Department';

-- 11. Employment
INSERT INTO users (username, email, hashed_password, is_active, must_change_password,
                   mobile_number, first_name, last_name, role_id, department_id, created_at, updated_at)
SELECT 'Nodal.Employment', 'employment@hry.nic.in', @pwd, 1, 1,
       '9540024691', 'Sunita', 'Yadav',
       @role_id, CAST(id AS CHAR), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)
FROM departments WHERE name = 'Employment Department';

-- 12. Excise and Taxation Department
INSERT INTO users (username, email, hashed_password, is_active, must_change_password,
                   mobile_number, first_name, last_name, role_id, department_id, created_at, updated_at)
SELECT 'Nodal.ETD', 'Madhubala.etd@hry.gov.in', @pwd, 1, 1,
       '9888778007', 'Madhu', 'Bala',
       @role_id, CAST(id AS CHAR), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)
FROM departments WHERE name = 'Excise and Taxation Department';

-- 13. HPGCL
INSERT INTO users (username, email, hashed_password, is_active, must_change_password,
                   mobile_number, first_name, last_name, role_id, department_id, created_at, updated_at)
SELECT 'Nodal.HPGCL', 'it@hpgcl.org.in', @pwd, 1, 1,
       '9417450480', 'Sunil', 'Gagneja',
       @role_id, CAST(id AS CHAR), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)
FROM departments WHERE name = 'HPGCL';

-- 14. Science and Technology (Department of Higher Education)
INSERT INTO users (username, email, hashed_password, is_active, must_change_password,
                   mobile_number, first_name, last_name, role_id, department_id, created_at, updated_at)
SELECT 'Nodal.SciTech', 'vishal.gulia@hry.gov.in', @pwd, 1, 1,
       '9417065760', 'Vishal', 'Gulia',
       @role_id, CAST(id AS CHAR), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)
FROM departments WHERE name = 'Science and Technology (Department of Higher Education)';

-- ── 2. Populate nodal_officer_departments junction table ──────
-- Links each nodal officer user to their department for
-- the managed-departments feature.

INSERT IGNORE INTO nodal_officer_departments (user_id, department_id)
SELECT u.id, d.id
FROM users u
JOIN departments d ON d.name = 'Urban Local Bodies (ULB)'
WHERE u.username = 'Nodal.ULB';

INSERT IGNORE INTO nodal_officer_departments (user_id, department_id)
SELECT u.id, d.id
FROM users u
JOIN departments d ON d.name = 'Revenue and Disaster Management'
WHERE u.username = 'Nodal.RevDM';

INSERT IGNORE INTO nodal_officer_departments (user_id, department_id)
SELECT u.id, d.id
FROM users u
JOIN departments d ON d.name = 'Archives Department'
WHERE u.username = 'Nodal.Archives';

INSERT IGNORE INTO nodal_officer_departments (user_id, department_id)
SELECT u.id, d.id
FROM users u
JOIN departments d ON d.name = 'Information, Public Relations & Languages (IPRL)'
WHERE u.username = 'Nodal.IPRL';

INSERT IGNORE INTO nodal_officer_departments (user_id, department_id)
SELECT u.id, d.id
FROM users u
JOIN departments d ON d.name = 'Central Committee of Examinations'
WHERE u.username = 'Nodal.CCE';

INSERT IGNORE INTO nodal_officer_departments (user_id, department_id)
SELECT u.id, d.id
FROM users u
JOIN departments d ON d.name = 'HARTRON'
WHERE u.username = 'Nodal.HARTRON';

INSERT IGNORE INTO nodal_officer_departments (user_id, department_id)
SELECT u.id, d.id
FROM users u
JOIN departments d ON d.name = 'HVPNL'
WHERE u.username = 'Nodal.HVPNL';

INSERT IGNORE INTO nodal_officer_departments (user_id, department_id)
SELECT u.id, d.id
FROM users u
JOIN departments d ON d.name = 'Architecture Department'
WHERE u.username = 'Nodal.Arch';

INSERT IGNORE INTO nodal_officer_departments (user_id, department_id)
SELECT u.id, d.id
FROM users u
JOIN departments d ON d.name = 'DHBVNL'
WHERE u.username = 'Nodal.DHBVNL';

INSERT IGNORE INTO nodal_officer_departments (user_id, department_id)
SELECT u.id, d.id
FROM users u
JOIN departments d ON d.name = 'Irrigation & Water Resources Department'
WHERE u.username = 'Nodal.IWR';

INSERT IGNORE INTO nodal_officer_departments (user_id, department_id)
SELECT u.id, d.id
FROM users u
JOIN departments d ON d.name = 'Employment Department'
WHERE u.username = 'Nodal.Employment';

INSERT IGNORE INTO nodal_officer_departments (user_id, department_id)
SELECT u.id, d.id
FROM users u
JOIN departments d ON d.name = 'Excise and Taxation Department'
WHERE u.username = 'Nodal.ETD';

INSERT IGNORE INTO nodal_officer_departments (user_id, department_id)
SELECT u.id, d.id
FROM users u
JOIN departments d ON d.name = 'HPGCL'
WHERE u.username = 'Nodal.HPGCL';

INSERT IGNORE INTO nodal_officer_departments (user_id, department_id)
SELECT u.id, d.id
FROM users u
JOIN departments d ON d.name = 'Science and Technology (Department of Higher Education)'
WHERE u.username = 'Nodal.SciTech';

-- ── Verification ──────────────────────────────────────────────
SELECT u.id, u.username, u.first_name, u.last_name, u.mobile_number,
       u.email, d.name AS department, r.name AS role
FROM   users u
JOIN   roles r ON r.id = u.role_id
LEFT   JOIN departments d ON d.id = CAST(u.department_id AS UNSIGNED)
WHERE  r.name = 'nodal Officer'
ORDER  BY u.username;
