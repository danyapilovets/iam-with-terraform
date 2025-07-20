from airflow import DAG
from airflow.providers.postgres.operators.postgres import PostgresOperator
from pendulum import yesterday

from helpers.default_args import default_args

with DAG(
        dag_id="fill_daily_transaction_summary",
        default_args=default_args,
        description="Banking daily transaction summary DAG",
        schedule="@daily",
        start_date=yesterday(),
        catchup=True,
) as dag:
    clear_summary = PostgresOperator(
        task_id="clear_daily_transaction_summary",
        postgres_conn_id="postgres_data",
        sql="DELETE FROM daily_transaction_summary WHERE summary_date = '{{ ds }}'"
    )
    
    fill_summary = PostgresOperator(
        task_id="fill_daily_transaction_summary",
        postgres_conn_id="postgres_data",
        sql="""
            INSERT INTO daily_transaction_summary (
                summary_date,
                account_id,
                transaction_type,
                transaction_count,
                total_amount,
                avg_amount
            )
            SELECT 
                '{{ ds }}'::date as summary_date,
                COALESCE(from_account_id, to_account_id) as account_id,
                transaction_type,
                COUNT(*) as transaction_count,
                SUM(amount) as total_amount,
                AVG(amount) as avg_amount
            FROM transactions 
            WHERE DATE(created_at) = '{{ ds }}'
            AND status = 'completed'
            AND (from_account_id IS NOT NULL OR to_account_id IS NOT NULL)
            GROUP BY 
                COALESCE(from_account_id, to_account_id),
                transaction_type
            """
    )

    clear_summary >> fill_summary
