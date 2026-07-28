"""
Seed script: Insert 30 Haryana IAS officers as users with role_id=8.
Default password: Haryana@123  (must_change_password=True on all accounts)

Run from the project root:
    python scripts/seed_ias_officers.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bcrypt
from urllib.parse import quote_plus
from sqlalchemy import create_engine, text
from app.core.config import settings

# ─────────────────────────────────────────────────────────────────────────────
# Officer data  (parsed from IAS officer list image)
# ─────────────────────────────────────────────────────────────────────────────

ROLE_ID = 8
DEFAULT_PASSWORD = "Haryana@123"

OFFICERS = [
    {
        "username": "anurag.rastogi",
        "first_name": "Anurag", "last_name": "Rastogi",
        "mobile": "9872200093", "email": "cs@hry.nic.in",
        "departments": [],
    },
    {
        "username": "rajesh.khullar",
        "first_name": "Rajesh", "last_name": "Khullar",
        "mobile": "9501048080", "email": "rajesh.khullar@haryana.gov.in",
        "departments": ["Chief Minister's Office"],
    },
    {
        "username": "sudhir.rajpal",
        "first_name": "Sudhir", "last_name": "Rajpal",
        "mobile": "8283809882", "email": "acs-home@hry.gov.in",
        "departments": [
            "Home Department",
            "Jails Department",
            "Environment, Forests & Wildlife (EF&W)",
        ],
    },
    {
        "username": "sumita.misra",
        "first_name": "Sumita", "last_name": "Misra",
        "mobile": "9478002727", "email": "fcr@hry.nic.in",
        "departments": [
            "Revenue Department",
            "Health Department",
            "Medical Education & Research (MER)",
            "Ayush Department",
        ],
    },
    {
        "username": "raja.vundru",
        "first_name": "Raja Sekhar", "last_name": "Vundru",
        "mobile": "8800004567", "email": "acs.transport-hry@gov.in",
        "departments": ["Transport Department"],
    },
    {
        "username": "vineet.garg",
        "first_name": "Vineet", "last_name": "Garg",
        "mobile": "9914421966", "email": "fcps@hry.nic.in",
        "departments": ["Printing & Stationery Department"],
    },
    {
        "username": "g.anupama",
        "first_name": "G.", "last_name": "Anupama",
        "mobile": "9818184969", "email": "fcsw@hry.nic.in",
        "departments": [
            "Social Justice, Empowerment, Welfare of SC & BC and Antyodaya (SEWA)",
            "Civil Aviation Department",
        ],
    },
    {
        "username": "ak.singh",
        "first_name": "A.K.", "last_name": "Singh",
        "mobile": "9878288490", "email": "acspwd@hry.nic.in",
        "departments": [
            "Public Works Department (PWD)",
            "Higher Education Department",
            "Architecture Department",
        ],
    },
    {
        "username": "arun.gupta",
        "first_name": "Arun Kumar", "last_name": "Gupta",
        "mobile": "9646940690", "email": "acs.finance-hry@gov.in",
        "departments": [
            "Chief Minister's Office",
            "Finance Department",
            "Planning Department",
        ],
    },
    {
        "username": "anurag.aggarwal",
        "first_name": "Anurag", "last_name": "Aggarwal",
        "mobile": "9779333866", "email": "fctcp@hry.nic.in",
        "departments": [
            "Town & Country Planning (TCP)",
            "Urban Estates Department",
            "Irrigation & Water Resources Department",
            "Saraswati Heritage Board",
        ],
    },
    {
        "username": "vijayendra.kumar",
        "first_name": "Vijayendra", "last_name": "Kumar",
        "mobile": "9779749080", "email": "acs.agri@hry.gov.in",
        "departments": [
            "Agriculture Department",
            "Haryana Income Enhancement Board",
            "Sainik & Ardh Sainik Welfare Department",
            "Development & Panchayats Department",
        ],
    },
    {
        "username": "d.suresh",
        "first_name": "D.", "last_name": "Suresh",
        "mobile": "9717263333", "email": "psfisheriesdepartment@gmail.com",
        "departments": ["Fisheries Department"],
    },
    {
        "username": "rajeev.ranjan",
        "first_name": "Rajeev", "last_name": "Ranjan",
        "mobile": "8558806688", "email": "acs.labour@hry.gov.in",
        "departments": [
            "Labour Department",
            "Youth Empowerment & Entrepreneurship (YEE)",
        ],
    },
    {
        "username": "pankaj.agarwal",
        "first_name": "Pankaj", "last_name": "Agarwal",
        "mobile": "8559020007", "email": "pankaj.agarwal@haryana.gov.in",
        "departments": [],
    },
    {
        "username": "pankaj.yadav",
        "first_name": "Pankaj", "last_name": "Yadav",
        "mobile": "9450960888", "email": "fcph@hry.nic.in",
        "departments": [
            "Public Health Engineering (PHE)",
            "Cooperation Department",
            "Water Resource Authority",
        ],
    },
    {
        "username": "vijay.dahiya",
        "first_name": "Vijay Singh", "last_name": "Dahiya",
        "mobile": "6239922972", "email": "fcah@hry.nic.in",
        "departments": [
            "Animal Husbandry Department",
            "Sports Department",
            "School Education Department",
        ],
    },
    {
        "username": "amneet.kumar",
        "first_name": "Amneet P", "last_name": "Kumar",
        "mobile": "9464541741", "email": "ps-foreigncoop@hry.gov.in",
        "departments": [
            "Department of Future",
            "Foreign Cooperation Department (FCD)",
        ],
    },
    {
        "username": "mohammed.shayin",
        "first_name": "Mohammed", "last_name": "Shayin",
        "mobile": "8146111222", "email": "acs.housing@hry.gov.in",
        "departments": ["Housing For All (HFA)"],
    },
    {
        "username": "amit.agrawal",
        "first_name": "Amit Kumar", "last_name": "Agrawal",
        "mobile": "9416545444", "email": "fcindustry@hry.nic.in",
        "departments": [
            "Industries & Commerce Department",
            "Information, Public Relations & Languages (IPRL)",
            "Heritage & Tourism Department",
        ],
    },
    {
        "username": "ashima.brar",
        "first_name": "Ashima", "last_name": "Brar",
        "mobile": "9478008777", "email": "acs.hetd@hry.gov.in",
        "departments": [
            "Excise Department",
            "Finance-II",
            "Energy Department",
        ],
    },
    {
        "username": "cg.rajini",
        "first_name": "C.G.Rajini Kaanthan", "last_name": "R.R.",
        "mobile": "9992015551", "email": "acs-minesg@hry.gov.in",
        "departments": [
            "Finance-III",
            "Central Committee of Examinations",
            "Mines & Geology (M&G)",
        ],
    },
    {
        "username": "phool.meena",
        "first_name": "Phool Chand", "last_name": "Meena",
        "mobile": "9650246677", "email": "ps-hrd@hry.gov.in",
        "departments": [
            "Human Resources Department (HRD)",
            "General Administration Department (GAD)",
            "Gurugram Metropolitan Development Authority (GMDA)",
            "Faridabad Metropolitan Development Authority (FMDA)",
        ],
    },
    {
        "username": "a.sriniwas",
        "first_name": "A.", "last_name": "Sriniwas",
        "mobile": "9779409889", "email": "a.sriniwas@haryana.gov.in",
        "departments": ["Elections Department"],
    },
    {
        "username": "shekhar.vidyarthi",
        "first_name": "Shekhar", "last_name": "Vidyarthi",
        "mobile": "8199011111", "email": "fcwcd.hry@nic.in",
        "departments": ["Women & Child Development (WCD)"],
    },
    {
        "username": "saket.kumar",
        "first_name": "Saket", "last_name": "Kumar",
        "mobile": "9467445599", "email": "archives@hry.nic.in",
        "departments": ["Archives Department"],
    },
    {
        "username": "j.ganesan",
        "first_name": "J.", "last_name": "Ganesan",
        "mobile": "6239925002", "email": "acsFcs2017@gmail.com",
        "departments": [
            "Food, Civil Supplies & Consumer Affairs (F&CS)",
            "Citizen Resources Information Department (CRID)",
            "HARTRON",
            "Housing For All (HFA)",
            "SPV (Special Purpose Vehicle - Smart City)",
            "Haryana State Pollution Control Board (HSPCB)",
        ],
    },
    {
        "username": "ashok.meena",
        "first_name": "Ashok Kumar", "last_name": "Meena",
        "mobile": "8295666888", "email": "fclg@hry.nic.in",
        "departments": [
            "Urban Local Bodies (ULB)",
            "Foreign Cooperation Department (FCD)",
        ],
    },
    {
        "username": "pankaj.ssps",
        "first_name": "Pankaj", "last_name": "",
        "mobile": "7082800080", "email": "fcvigilance@hry.nic.in",
        "departments": ["Vigilance Department"],
    },
    {
        "username": "yash.pal",
        "first_name": "Yash", "last_name": "Pal",
        "mobile": "9821159108", "email": "yash.pal@haryana.gov.in",
        "departments": [
            "Chief Minister's Office",
            "Department of Land Records (DLR)",
            "Revenue Department",
        ],
    },
    {
        "username": "ajay.kumar",
        "first_name": "Ajay", "last_name": "Kumar",
        "mobile": "9991148989", "email": "ajay.kumar@haryana.gov.in",
        "departments": ["Chief Minister's Office"],
    },
]


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()


def resolve_dept_ids(conn, dept_names: list[str]) -> str | None:
    if not dept_names:
        return None
    ids = []
    for name in dept_names:
        row = conn.execute(
            text("SELECT id FROM departments WHERE name = :n LIMIT 1"),
            {"n": name},
        ).fetchone()
        if row:
            ids.append(str(row[0]))
        else:
            print(f"  WARNING: department not found in DB — '{name}'")
    return ",".join(ids) if ids else None


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    db_url = (
        f"mysql+pymysql://{settings.DB_USER}:{quote_plus(settings.DB_PASSWORD)}"
        f"@{settings.DB_SERVER}:{settings.DB_PORT}/{settings.DB_NAME}"
    )
    engine = create_engine(db_url, echo=False)

    hashed_pw = hash_password(DEFAULT_PASSWORD)
    print(f"Password hash generated for '{DEFAULT_PASSWORD}'")

    inserted = 0
    skipped = 0

    with engine.begin() as conn:
        for officer in OFFICERS:
            # Check for duplicate username or email
            existing = conn.execute(
                text("SELECT id FROM users WHERE username = :u OR email = :e"),
                {"u": officer["username"], "e": officer["email"]},
            ).fetchone()
            if existing:
                print(f"  SKIP (already exists): {officer['username']} / {officer['email']}")
                skipped += 1
                continue

            dept_id_csv = resolve_dept_ids(conn, officer["departments"])

            conn.execute(
                text("""
                    INSERT INTO users
                        (username, email, hashed_password, first_name, last_name,
                         mobile_number, role_id, department_id,
                         is_active, must_change_password, created_at, updated_at)
                    VALUES
                        (:username, :email, :pw, :first_name, :last_name,
                         :mobile, :role_id, :dept_id,
                         1, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP())
                """),
                {
                    "username":   officer["username"],
                    "email":      officer["email"],
                    "pw":         hashed_pw,
                    "first_name": officer["first_name"],
                    "last_name":  officer["last_name"],
                    "mobile":     officer["mobile"],
                    "role_id":    ROLE_ID,
                    "dept_id":    dept_id_csv,
                },
            )
            print(f"  INSERTED: {officer['username']}  dept_ids={dept_id_csv}")
            inserted += 1

    print(f"\nDone. {inserted} inserted, {skipped} skipped.")


if __name__ == "__main__":
    main()
