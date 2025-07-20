import os
from psycopg2.extras import RealDictCursor
import psycopg2

POSTGRES_USER = os.environ.get("POSTGRES_USER", "postgres")
POSTGRES_PASSWORD = os.environ.get("POSTGRES_PASSWORD", "postgres")
POSTGRES_HOST = os.environ.get("POSTGRES_HOST", "postgres")
POSTGRES_PORT = os.environ.get("POSTGRES_PORT", "5432")
POSTGRES_DB = os.environ.get("POSTGRES_DB", "postgres")

print(f"🔌 Connecting to PostgreSQL: {POSTGRES_USER}@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}")

try:
    connection = psycopg2.connect(
        user=POSTGRES_USER,
        password=POSTGRES_PASSWORD,
        host=POSTGRES_HOST,
        port=POSTGRES_PORT,
        database=POSTGRES_DB
    )
    connection.autocommit = True
    cursor = connection.cursor()
    cur = connection.cursor(cursor_factory=RealDictCursor)
    print("✅ PostgreSQL connection established successfully!")
except Exception as e:
    print(f"❌ Failed to connect to PostgreSQL: {e}")
    raise e
