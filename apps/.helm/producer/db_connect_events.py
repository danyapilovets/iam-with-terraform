from psycopg2.extras import RealDictCursor
import psycopg2


connection = psycopg2.connect(
    user="postgres",
    password="postgres",
    host="postgres",
    port="5432",
    database="postgres"
)
connection.autocommit = True
cursor = connection.cursor()
cur = connection.cursor(cursor_factory =RealDictCursor)
