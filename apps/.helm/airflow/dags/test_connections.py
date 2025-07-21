from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from airflow.operators.python import PythonOperator
from helpers.default_args import default_args

DAG_ID = "test_connections"

def test_postgres_connection():
    try:
        postgres_hook = PostgresHook(postgres_conn_id='postgres_data')
        records = postgres_hook.get_records("SELECT version();")
        print(f"PostgreSQL Connection OK: {records[0][0]}")
        return "postgres_ok"
    except Exception as e:
        print(f"PostgreSQL Connection Failed: {str(e)}")
        raise e

def test_s3_connection():
    try:
        s3_hook = S3Hook(aws_conn_id='s3_data')

        bucket_name = 'dev-iwt-private-2cap2d'

        if s3_hook.check_for_bucket(bucket_name):
            print(f"S3 Bucket Access OK: {bucket_name}")

            test_data = f"Airflow S3 test {datetime.now()}"
            s3_hook.load_string(
                string_data=test_data,
                bucket_name=bucket_name,
                key='airflow/test/connection_test.txt'
            )
            print("S3 Write Test OK")
            
            return "s3_ok"
        else:
            print(f"S3 Bucket not accessible: {bucket_name}")
            raise Exception(f"Bucket {bucket_name} not accessible")
            
    except Exception as e:
        print(f"S3 Connection Failed: {str(e)}")
        raise e

with DAG(
    dag_id=DAG_ID,
    description="Test Banking ETL Connections (S3 + PostgreSQL)",
    default_args=default_args,
    start_date=datetime(2024, 1, 1),
    schedule_interval="@daily",
    catchup=False,
    tags=['banking', 'etl', 'test']
) as dag:

    postgres_test = PythonOperator(
        task_id='test_postgres_connection',
        python_callable=test_postgres_connection
    )

    s3_test = PythonOperator(
        task_id='test_s3_connection',
        python_callable=test_s3_connection
    )

    postgres_test >> s3_test