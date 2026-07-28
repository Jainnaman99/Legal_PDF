-- ============================================================
-- Reset Script: Clear non-admin users & all departments,
--               then seed Haryana Government departments
-- Run: mysql -u root -p Legal_PDF < scripts/reset_users_and_departments.sql
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;

-- ── 1. Remove all users EXCEPT those with admin / super Admin roles ──────────
-- Adjust role names below if they differ in your roles table
DELETE FROM user_login_logs;        -- clear login history first (FK)
DELETE FROM password_reset_otps;    -- clear OTPs (FK)
DELETE FROM admin_login_otps;       -- clear admin OTPs (FK)

DELETE u FROM users u
JOIN roles r ON r.id = u.role_id
WHERE r.name NOT IN ('admin', 'super Admin');

-- ── 2. Clear all departments ─────────────────────────────────────────────────
-- pdf_documents.department_id will become NULL (or the column allows NULL)
UPDATE pdf_documents SET department_id = NULL;
DELETE FROM departments;

-- Reset auto-increment so IDs start from 1
ALTER TABLE departments AUTO_INCREMENT = 1;

-- ── 3. Seed Haryana Government Departments ───────────────────────────────────
INSERT INTO departments (name, is_active, created_at) VALUES
-- Chief Minister's Office
('Chief Minister''s Office', 1, NOW()),

-- Finance cluster
('Finance Department', 1, NOW()),
('Finance-II', 1, NOW()),
('Finance-III', 1, NOW()),

-- Home & Law & Order
('Home Department', 1, NOW()),
('Jails Department', 1, NOW()),

-- Revenue & Land
('Revenue Department', 1, NOW()),
('Department of Land Records (DLR)', 1, NOW()),
('Urban Estates Department', 1, NOW()),
('Town & Country Planning (TCP)', 1, NOW()),

-- Agriculture & Allied
('Agriculture Department', 1, NOW()),
('Irrigation & Water Resources Department', 1, NOW()),
('Animal Husbandry Department', 1, NOW()),
('Fisheries Department', 1, NOW()),
('Saraswati Heritage Board', 1, NOW()),

-- Health
('Health Department', 1, NOW()),
('Medical Education & Research (MER)', 1, NOW()),
('Ayush Department', 1, NOW()),

-- Education
('Higher Education Department', 1, NOW()),
('School Education Department', 1, NOW()),
('Department of Future', 1, NOW()),

-- Infrastructure & Urban
('Public Works Department (PWD)', 1, NOW()),
('Public Health Engineering (PHE)', 1, NOW()),
('Housing For All (HFA)', 1, NOW()),
('Urban Local Bodies (ULB)', 1, NOW()),
('Architecture Department', 1, NOW()),
('Gurugram Metropolitan Development Authority (GMDA)', 1, NOW()),
('Faridabad Metropolitan Development Authority (FMDA)', 1, NOW()),
('SPV (Special Purpose Vehicle - Smart City)', 1, NOW()),

-- Transport
('Transport Department', 1, NOW()),
('Civil Aviation Department', 1, NOW()),

-- Industry, Commerce & IT
('Industries & Commerce Department', 1, NOW()),
('HARTRON', 1, NOW()),
('Citizen Resources Information Department (CRID)', 1, NOW()),
('Information, Public Relations & Languages (IPRL)', 1, NOW()),
('Printing & Stationery Department', 1, NOW()),

-- Social Welfare
('Social Justice, Empowerment, Welfare of SC & BC and Antyodaya (SEWA)', 1, NOW()),
('Women & Child Development (WCD)', 1, NOW()),
('Sainik & Ardh Sainik Welfare Department', 1, NOW()),
('Labour Department', 1, NOW()),
('Youth Empowerment & Entrepreneurship (YEE)', 1, NOW()),

-- Energy & Environment
('Energy Department', 1, NOW()),
('Environment, Forests & Wildlife (EF&W)', 1, NOW()),
('Haryana State Pollution Control Board (HSPCB)', 1, NOW()),
('Water Resource Authority', 1, NOW()),

-- Governance & Administration
('General Administration Department (GAD)', 1, NOW()),
('Human Resources Department (HRD)', 1, NOW()),
('Planning Department', 1, NOW()),
('Elections Department', 1, NOW()),
('Vigilance Department', 1, NOW()),
('Archives Department', 1, NOW()),
('Foreign Cooperation Department (FCD)', 1, NOW()),
('Cooperation Department', 1, NOW()),
('Development & Panchayats Department', 1, NOW()),

-- Mining & Resources
('Mines & Geology (M&G)', 1, NOW()),
('Excise Department', 1, NOW()),

-- Other
('Heritage & Tourism Department', 1, NOW()),
('Food, Civil Supplies & Consumer Affairs (F&CS)', 1, NOW()),
('Sports Department', 1, NOW()),
('Haryana Income Enhancement Board', 1, NOW()),
('Central Committee of Examinations', 1, NOW());

SET FOREIGN_KEY_CHECKS = 1;

-- ── Verification ─────────────────────────────────────────────────────────────
SELECT COUNT(*) AS total_departments FROM departments;
SELECT id, name FROM departments ORDER BY name;

SELECT u.id, u.username, r.name AS role
FROM users u
JOIN roles r ON r.id = u.role_id
ORDER BY u.id;
