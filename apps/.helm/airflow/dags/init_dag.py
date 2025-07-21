import os

from airflow.operators.postgres_operator import PostgresOperator
from airflow import DAG
from helpers.default_args import default_args
from pendulum import yesterday

ENV_ID = os.environ.get("SYSTEM_TESTS_ENV_ID")
DAG_ID = "banking_database_init"

with DAG(
        dag_id=DAG_ID,
        description="Banking database init and fill",
        default_args=default_args,
        start_date=yesterday(),
        schedule_interval="@once",
        catchup=True

) as dag:
    create_tables = PostgresOperator(
        task_id='create_banking_tables',
        postgres_conn_id='postgres_data',
        sql="sql/create_tables.sql",
    )
    clear_tables = PostgresOperator(
        task_id='clear_banking_tables',
        postgres_conn_id='postgres_data',
        sql="sql/clear_tables.sql",
    )
    fill_tables = PostgresOperator(
        task_id='fill_banking_tables',
        postgres_conn_id='postgres_data',
        sql="sql/fill_tables.sql",
    )

    create_tables >> clear_tables >> fill_tables
