"""
Generate SQL to replace multi-department users (role_id NOT IN 1,2)
with one AdmSec.<DeptName> user per department.

Usage (review first, then pipe to MySQL):
  python scripts/migrate_admsec_users.py > migration_admsec.sql
  mysql -u root -p legal_pdf < migration_admsec.sql
"""

# --Short names used in usernames (AdmSec.<ShortName>) -------------------------
SHORT_NAMES = {
    1:  "CMO",
    2:  "Finance",
    3:  "FinanceII",
    4:  "FinanceIII",
    5:  "Home",
    6:  "Jails",
    7:  "Revenue",
    8:  "LandRecords",
    9:  "UrbanEstates",
    10: "TCP",
    11: "Agriculture",
    12: "Irrigation",
    13: "AnimalHusbandry",
    14: "Fisheries",
    15: "SaraswatiHeritage",
    16: "Health",
    17: "MedicalEducation",
    18: "Ayush",
    19: "HigherEducation",
    20: "SchoolEducation",
    21: "Future",
    22: "PWD",
    23: "PHE",
    24: "Housing",
    25: "ULB",
    26: "Architecture",
    27: "GMDA",
    28: "FMDA",
    29: "SPV",
    30: "Transport",
    31: "CivilAviation",
    32: "Industries",
    33: "HARTRON",
    34: "CRID",
    35: "IPRL",
    36: "Printing",
    37: "SEWA",
    38: "WCD",
    39: "SainikWelfare",
    40: "Labour",
    41: "YEE",
    42: "Energy",
    43: "Environment",
    44: "HSPCB",
    45: "WaterResource",
    46: "GAD",
    47: "HRD",
    48: "Planning",
    49: "Elections",
    50: "Vigilance",
    51: "Archives",
    52: "ForeignCooperation",
    53: "Cooperation",
    54: "Panchayats",
    55: "MinesGeology",
    56: "Excise",
    57: "Tourism",
    58: "FoodSupplies",
    59: "Sports",
    60: "IncomeBoard",
    61: "Examinations",
    62: "ChiefSecretary",
}

# --Department map (from departments table) ------------------------------------
DEPARTMENTS = {
    1:  "Chief Minister's Office",
    2:  "Finance Department",
    3:  "Finance-II",
    4:  "Finance-III",
    5:  "Home Department",
    6:  "Jails Department",
    7:  "Revenue Department",
    8:  "Department of Land Records (DLR)",
    9:  "Urban Estates Department",
    10: "Town & Country Planning (TCP)",
    11: "Agriculture Department",
    12: "Irrigation & Water Resources Department",
    13: "Animal Husbandry Department",
    14: "Fisheries Department",
    15: "Saraswati Heritage Board",
    16: "Health Department",
    17: "Medical Education & Research (MER)",
    18: "Ayush Department",
    19: "Higher Education Department",
    20: "School Education Department",
    21: "Department of Future",
    22: "Public Works Department (PWD)",
    23: "Public Health Engineering (PHE)",
    24: "Housing For All (HFA)",
    25: "Urban Local Bodies (ULB)",
    26: "Architecture Department",
    27: "Gurugram Metropolitan Development Authority (GMDA)",
    28: "Faridabad Metropolitan Development Authority (FMDA)",
    29: "SPV (Special Purpose Vehicle - Smart City)",
    30: "Transport Department",
    31: "Civil Aviation Department",
    32: "Industries & Commerce Department",
    33: "HARTRON",
    34: "Citizen Resources Information Department (CRID)",
    35: "Information, Public Relations & Languages (IPRL)",
    36: "Printing & Stationery Department",
    37: "Social Justice, Empowerment, Welfare of SC & BC and Antyodaya (SEWA)",
    38: "Women & Child Development (WCD)",
    39: "Sainik & Ardh Sainik Welfare Department",
    40: "Labour Department",
    41: "Youth Empowerment & Entrepreneurship (YEE)",
    42: "Energy Department",
    43: "Environment, Forests & Wildlife (EF&W)",
    44: "Haryana State Pollution Control Board (HSPCB)",
    45: "Water Resource Authority",
    46: "General Administration Department (GAD)",
    47: "Human Resources Department (HRD)",
    48: "Planning Department",
    49: "Elections Department",
    50: "Vigilance Department",
    51: "Archives Department",
    52: "Foreign Cooperation Department (FCD)",
    53: "Cooperation Department",
    54: "Development & Panchayats Department",
    55: "Mines & Geology (M&G)",
    56: "Excise Department",
    57: "Heritage & Tourism Department",
    58: "Food, Civil Supplies & Consumer Affairs (F&CS)",
    59: "Sports Department",
    60: "Haryana Income Enhancement Board",
    61: "Central Committee of Examinations",
    62: "Chief Secretary to Govt. of Haryana",
}

# Default password hash used by all seeded users — they must change on first login
DEFAULT_HASH = "$2b$12$geno.584ZaUUZjZIJ8zeCuujAv.kfDR3RnJx0coJWylRXhO8CxpHW"

# Role ID to assign all AdmSec users (same as existing officers)
ADMSEC_ROLE_ID = 8

# Dept → list of (email, mobile, first_name, last_name) sorted by original user_id.
# Departments with multiple entries get numbered usernames: AdmSec.CMO1, AdmSec.CMO2, ...
# Departments with a single entry get no number:            AdmSec.Finance
DEPT_INFO = {
    1:  [                                                           # users 1001, 1008, 1028, 1029
        (None,                       '9501048080', 'Rajesh',              'Khullar'),
        ('acs.finance-hry@gov.in',   '9646940690', 'Arun Kumar',          'Gupta'),
        (None,                       '9821159108', 'Yash',                'Pal'),
        (None,                       '9991148989', 'Ajay',                'Kumar'),
    ],
    2:  [('acs.finance-hry@gov.in',      '9646940690', 'Arun Kumar',          'Gupta')],
    3:  [('acs.hetd@hry.gov.in',         '9478008777', 'Ashima',              'Brar')],
    4:  [('acs-minesg@hry.gov.in',       '9992015551', 'C.G.Rajini Kaanthan', 'R.R.')],
    5:  [('acs-home@hry.gov.in',         '8283809882', 'Sudhir',              'Rajpal')],
    6:  [('acs-home@hry.gov.in',         '8283809882', 'Sudhir',              'Rajpal')],
    7:  [                                                           # users 1003, 1028
        ('fcr@hry.nic.in',           '9478002727', 'Sumita',              'Misra'),
        (None,                       '9821159108', 'Yash',                'Pal'),
    ],
    8:  [(None,                          '9821159108', 'Yash',                'Pal')],
    9:  [('fctcp@hry.nic.in',            '9779333866', 'Anurag',              'Aggarwal')],
    10: [('fctcp@hry.nic.in',            '9779333866', 'Anurag',              'Aggarwal')],
    11: [('acs.agri@hry.gov.in',         '9779749080', 'Vijayendra',          'Kumar')],
    12: [('fctcp@hry.nic.in',            '9779333866', 'Anurag',              'Aggarwal')],
    13: [('fcah@hry.nic.in',             '6239922972', 'Vijay Singh',         'Dahiya')],
    14: [('psfisheriesdepartment@gmail.com', '9717263333', 'D.',              'Suresh')],
    15: [('fctcp@hry.nic.in',            '9779333866', 'Anurag',              'Aggarwal')],
    16: [('fcr@hry.nic.in',              '9478002727', 'Sumita',              'Misra')],
    17: [('fcr@hry.nic.in',              '9478002727', 'Sumita',              'Misra')],
    18: [('fcr@hry.nic.in',              '9478002727', 'Sumita',              'Misra')],
    19: [('acspwd@hry.nic.in',           '9878288490', 'A.K.',                'Singh')],
    20: [('fcah@hry.nic.in',             '6239922972', 'Vijay Singh',         'Dahiya')],
    21: [('ps-foreigncoop@hry.gov.in',   '9464541741', 'Amneet P',            'Kumar')],
    22: [('acspwd@hry.nic.in',           '9878288490', 'A.K.',                'Singh')],
    23: [('fcph@hry.nic.in',             '9450960888', 'Pankaj',              'Yadav')],
    24: [                                                           # users 1017, 1025
        ('acs.housing@hry.gov.in',   '8146111222', 'Mohammed',            'Shayin'),
        ('acsFcs2017@gmail.com',     '6239925002', 'J.',                  'Ganesan'),
    ],
    25: [('fclg@hry.nic.in',             '8295666888', 'Ashok Kumar',         'Meena')],
    26: [('acspwd@hry.nic.in',           '9878288490', 'A.K.',                'Singh')],
    27: [('ps-hrd@hry.gov.in',           '9650246677', 'Phool Chand',         'Meena')],
    28: [('ps-hrd@hry.gov.in',           '9650246677', 'Phool Chand',         'Meena')],
    29: [('acsFcs2017@gmail.com',        '6239925002', 'J.',                  'Ganesan')],
    30: [('acs.transport-hry@gov.in',    '8800004567', 'Raja Sekhar',         'Vundru')],
    31: [('fcsw@hry.nic.in',             '9818184969', 'G.',                  'Anupama')],
    32: [('fcindustry@hry.nic.in',       '9416545444', 'Amit Kumar',          'Agrawal')],
    33: [('acsFcs2017@gmail.com',        '6239925002', 'J.',                  'Ganesan')],
    34: [('acsFcs2017@gmail.com',        '6239925002', 'J.',                  'Ganesan')],
    35: [('fcindustry@hry.nic.in',       '9416545444', 'Amit Kumar',          'Agrawal')],
    36: [('fcps@hry.nic.in',             '9914421966', 'Vineet',              'Garg')],
    37: [('fcsw@hry.nic.in',             '9818184969', 'G.',                  'Anupama')],
    38: [('fcwcd.hry@nic.in',            '8199011111', 'Shekhar',             'Vidyarthi')],
    39: [('acs.agri@hry.gov.in',         '9779749080', 'Vijayendra',          'Kumar')],
    40: [('acs.labour@hry.gov.in',       '8558806688', 'Rajeev',              'Ranjan')],
    41: [('acs.labour@hry.gov.in',       '8558806688', 'Rajeev',              'Ranjan')],
    42: [('acs.hetd@hry.gov.in',         '9478008777', 'Ashima',              'Brar')],
    43: [('acs-home@hry.gov.in',         '8283809882', 'Sudhir',              'Rajpal')],
    44: [('acsFcs2017@gmail.com',        '6239925002', 'J.',                  'Ganesan')],
    45: [('fcph@hry.nic.in',             '9450960888', 'Pankaj',              'Yadav')],
    46: [('ps-hrd@hry.gov.in',           '9650246677', 'Phool Chand',         'Meena')],
    47: [('ps-hrd@hry.gov.in',           '9650246677', 'Phool Chand',         'Meena')],
    48: [('acs.finance-hry@gov.in',      '9646940690', 'Arun Kumar',          'Gupta')],
    49: [(None,                          '9779409889', 'A.',                  'Sriniwas')],
    50: [('fcvigilance@hry.nic.in',      '7082800080', 'Pankaj',              None)],
    51: [('archives@hry.nic.in',         '9467445599', 'Saket',               'Kumar')],
    52: [                                                           # users 1016, 1026
        ('ps-foreigncoop@hry.gov.in', '9464541741', 'Amneet P',            'Kumar'),
        ('fclg@hry.nic.in',           '8295666888', 'Ashok Kumar',         'Meena'),
    ],
    53: [('fcph@hry.nic.in',             '9450960888', 'Pankaj',              'Yadav')],
    54: [('acs.agri@hry.gov.in',         '9779749080', 'Vijayendra',          'Kumar')],
    55: [('acs-minesg@hry.gov.in',       '9992015551', 'C.G.Rajini Kaanthan', 'R.R.')],
    56: [('acs.hetd@hry.gov.in',         '9478008777', 'Ashima',              'Brar')],
    57: [('fcindustry@hry.nic.in',       '9416545444', 'Amit Kumar',          'Agrawal')],
    58: [('acsFcs2017@gmail.com',        '6239925002', 'J.',                  'Ganesan')],
    59: [('fcah@hry.nic.in',             '6239922972', 'Vijay Singh',         'Dahiya')],
    60: [('acs.agri@hry.gov.in',         '9779749080', 'Vijayendra',          'Kumar')],
    61: [('acs-minesg@hry.gov.in',       '9992015551', 'C.G.Rajini Kaanthan', 'R.R.')],
    62: [('cs@hry.nic.in',               '9872200093', 'Anurag',              'Rastogi')],
}


def sql_str(v):
    if v is None:
        return 'NULL'
    return "'" + str(v).replace("'", "''") + "'"


def make_username(dept_id: int) -> str:
    """Return AdmSec.<ShortName> for the given department id."""
    return 'AdmSec.' + SHORT_NAMES[dept_id]


def main():
    print("-- ============================================================")
    print("-- Migration: Replace multi-department users with AdmSec users")
    print("-- One user per department, username = AdmSec.<DeptName>")
    print("-- REVIEW this output before running it!")
    print("-- ============================================================")
    print()
    print("START TRANSACTION;")
    print()

    print("-- Step 1: Disable FK checks so dependent tables don't block the delete")
    print("SET FOREIGN_KEY_CHECKS = 0;")
    print()

    print("-- Step 2: Remove all non-admin users (role_id NOT IN (1, 2))")
    print("DELETE FROM users WHERE role_id NOT IN (1, 2);")
    print()

    print("-- Step 3: Re-enable FK checks")
    print("SET FOREIGN_KEY_CHECKS = 1;")
    print()

    print("-- Step 4: Insert one AdmSec user per department (62 total)")
    print("-- NOTE: Some emails appear for multiple departments (same officer covered")
    print("--       multiple depts). If your users table has a UNIQUE constraint on")
    print("--       email, this INSERT will fail — in that case set email=NULL above.")
    print("INSERT INTO users")
    print("    (username, email, hashed_password, is_active, must_change_password,")
    print("     mobile_number, password_changed_at, first_name, last_name,")
    print("     role_id, department_id, created_at, updated_at)")
    print("VALUES")

    rows = []
    for dept_id in sorted(DEPT_INFO.keys()):
        users = DEPT_INFO[dept_id]
        base = make_username(dept_id)
        for i, (email, mobile, first_name, last_name) in enumerate(users, 1):
            username = f"{base}{i}" if len(users) > 1 else base
            row = (
                f"    ('{username}', {sql_str(email)}, '{DEFAULT_HASH}', 1, 1, "
                f"{sql_str(mobile)}, NULL, {sql_str(first_name)}, {sql_str(last_name)}, "
                f"{ADMSEC_ROLE_ID}, {dept_id}, NOW(), NOW())"
            )
            rows.append(row)

    print(',\n'.join(rows) + ';')
    print()
    print("COMMIT;")
    print()

    # Preview the usernames for quick review
    print("-- --Username preview ----------------------------------------")
    for dept_id in sorted(DEPARTMENTS.keys()):
        username = make_username(dept_id)
        print(f"-- dept {dept_id:2d}: {username}")
    print()

    print("-- --Verify after running ----------------------------------------")
    print("-- SELECT id, username, department_id, role_id FROM users ORDER BY department_id;")


if __name__ == '__main__':
    main()
