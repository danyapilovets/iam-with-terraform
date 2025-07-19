import os

from airflow.operators.postgres_operator import PostgresOperator
from airflow import DAG
from helpers.default_args import default_args
from pendulum import yesterday

ENV_ID = os.environ.get("SYSTEM_TESTS_ENV_ID")
DAG_ID = "database_init"

with DAG(
        dag_id=DAG_ID,
        description="db init and fill",
        default_args=default_args,
        start_date=yesterday(),
        schedule_interval="@once",
        catchup=True

) as dag:
    create_table = PostgresOperator(
        task_id='create_table',
        postgres_conn_id='postgres_data',
        sql="sql/create_tables.sql",
    )
    insert_table = PostgresOperator(
        task_id='insert_table',
        postgres_conn_id='postgres_data',
        sql="sql/fill_tables.sql",
    )
    delete_data_from_table = PostgresOperator(
        task_id='delete_data_from_table',
        postgres_conn_id='postgres_data',
        sql="sql/clear_tables.sql",
    )

    create_table >> delete_data_from_table >> insert_table
