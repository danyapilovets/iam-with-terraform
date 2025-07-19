from airflow import DAG
from airflow.providers.postgres.operators.postgres import PostgresOperator
from pendulum import yesterday

from helpers.default_args import default_args

with DAG(
        dag_id="fill_order_status_stats_table",
        default_args=default_args,
        description="fill table order_status_stats DAG",
        schedule="@once",
        start_date=yesterday(),
        catchup=True,
) as dag:
    drop_status = PostgresOperator(
        task_id="drop_order_status_stats",
        postgres_conn_id="postgres_data",
        sql="truncate order_status_stats"
    )
    order_status_stats = PostgresOperator(
        task_id="fill_order_status_stats",
        postgres_conn_id="postgres_data",
        sql="""
            INSERT INTO order_status_stats
            select
                CAST(date_sale AS date) as dt,
                status_name as order_status_name,
                COUNT(sale.sale_id) as orders_count
            from sale
            join order_status
            on order_status.sale_id = sale.sale_id
            join status_name
            on status_name.status_name_id = order_status.status_name_id
            group by dt, order_status_name
            """
    )

    drop_status >> order_status_stats
