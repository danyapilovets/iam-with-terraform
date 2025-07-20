from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from airflow.operators.python import PythonOperator
from helpers.default_args import default_args

DAG_ID = "fraud_detection"

def export_alerts_to_s3():
    try:
        from airflow.providers.postgres.hooks.postgres import PostgresHook

        postgres_hook = PostgresHook(postgres_conn_id='postgres_data')
        s3_hook = S3Hook(aws_conn_id='s3_data')

        sql = """
        SELECT
            fa.alert_id,
            t.transaction_uuid,
            t.amount,
            t.transaction_type,
            fr.rule_name,
            fa.risk_score,
            fa.created_at
        FROM fraud_alerts fa
        JOIN transactions t ON fa.transaction_id = t.transaction_id
        JOIN fraud_rules fr ON fa.rule_id = fr.rule_id
        WHERE DATE(fa.created_at) = CURRENT_DATE - INTERVAL '1 day'
        AND fa.alert_status IN ('open', 'investigating')
        """
        
        records = postgres_hook.get_records(sql)
        
        if records:
            csv_content = "alert_id,transaction_uuid,amount,transaction_type,rule_name,risk_score,created_at\n"
            for record in records:
                csv_content += f"{','.join(str(field) for field in record)}\n"
            
            key = f"fraud-alerts/{datetime.now().strftime('%Y/%m/%d')}/daily_alerts.csv"
            s3_hook.load_string(
                string_data=csv_content,
                bucket_name='dev-iwt-private-2cap2d',
                key=key
            )

            print(f"Exported {len(records)} fraud alerts to S3: {key}")
        else:
            print("No fraud alerts found for yesterday")

    except Exception as e:
        print(f"Failed to export alerts: {str(e)}")
        raise e

with DAG(
    dag_id=DAG_ID,
    description="Banking fraud detection and alerting",
    default_args=default_args,
    start_date=datetime(2024, 1, 1),
    schedule_interval="@daily",
    catchup=False,
    tags=['banking', 'fraud', 'security']
) as dag:

    detect_large_amounts = PostgresOperator(
        task_id='detect_large_amount_fraud',
        postgres_conn_id='postgres_data',
        sql="""
        INSERT INTO fraud_alerts (transaction_id, rule_id, alert_type, risk_score, created_at)
        SELECT DISTINCT
            t.transaction_id,
            fr.rule_id,
            'large_amount' as alert_type,
            CASE
                WHEN t.amount > 50000 THEN 90
                WHEN t.amount > 25000 THEN 70
                ELSE 50
            END as risk_score,
            CURRENT_TIMESTAMP
        FROM transactions t
        JOIN fraud_rules fr ON fr.rule_type = 'amount_threshold' AND fr.is_active = true
        WHERE DATE(t.created_at) = CURRENT_DATE - INTERVAL '1 day'
        AND t.amount > fr.threshold_amount
        AND t.status = 'completed'
        AND NOT EXISTS (
            SELECT 1 FROM fraud_alerts fa
            WHERE fa.transaction_id = t.transaction_id
            AND fa.rule_id = fr.rule_id
        )
        """
    )

    detect_high_frequency = PostgresOperator(
        task_id='detect_high_frequency_fraud',
        postgres_conn_id='postgres_data',
        sql="""
        INSERT INTO fraud_alerts (transaction_id, rule_id, alert_type, risk_score, created_at)
        SELECT DISTINCT
            t.transaction_id,
            fr.rule_id,
            'high_frequency' as alert_type,
            80 as risk_score,
            CURRENT_TIMESTAMP
        FROM transactions t
        JOIN fraud_rules fr ON fr.rule_type = 'frequency_check' AND fr.is_active = true
        JOIN (
            SELECT 
                from_account_id,
                COUNT(*) as tx_count
            FROM transactions 
            WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
            AND status = 'completed'
            GROUP BY from_account_id
            HAVING COUNT(*) > 10
        ) freq ON freq.from_account_id = t.from_account_id
        WHERE DATE(t.created_at) = CURRENT_DATE - INTERVAL '1 day'
        AND t.status = 'completed'
        AND NOT EXISTS (
            SELECT 1 FROM fraud_alerts fa 
            WHERE fa.transaction_id = t.transaction_id 
            AND fa.rule_id = fr.rule_id
        )
        """
    )
    
    export_to_s3 = PythonOperator(
        task_id='export_fraud_alerts_to_s3',
        python_callable=export_alerts_to_s3
    )
    
    [detect_large_amounts, detect_high_frequency] >> export_to_s3 