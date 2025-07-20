from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from airflow.operators.python import PythonOperator
from helpers.default_args import default_args

DAG_ID = "banking_etl_test"

def test_banking_data_pipeline():
    postgres_hook = PostgresHook(postgres_conn_id='postgres_data')

    print("=== BANKING ETL PIPELINE TEST ===")

    print("\n1. CUSTOMERS DATA:")
    customers = postgres_hook.get_records("""
        SELECT COUNT(*) as customer_count,
               MIN(created_at) as first_customer,
               MAX(created_at) as last_customer
        FROM customers
    """)
    print(f"   Total customers: {customers[0][0]}")
    print(f"   Date range: {customers[0][1]} to {customers[0][2]}")

    print("\n2. ACCOUNTS DATA:")
    accounts = postgres_hook.get_records("""
        SELECT account_type, COUNT(*) as count, 
               AVG(balance) as avg_balance,
               SUM(balance) as total_balance
        FROM accounts 
        WHERE status = 'active'
        GROUP BY account_type
        ORDER BY count DESC
    """)
    for acc in accounts:
        print(f"   {acc[0]}: {acc[1]} accounts, avg balance ${acc[2]:.2f}, total ${acc[3]:.2f}")

    print("\n3. TRANSACTIONS SUMMARY:")
    transactions = postgres_hook.get_records("""
        SELECT transaction_type, status,
               COUNT(*) as count,
               SUM(amount) as total_amount,
               AVG(amount) as avg_amount
        FROM transactions
        GROUP BY transaction_type, status
        ORDER BY transaction_type, count DESC
    """)
    for tx in transactions:
        print(f"   {tx[0]} ({tx[1]}): {tx[2]} transactions, total ${tx[3]:.2f}, avg ${tx[4]:.2f}")
    
    print("\n4. DAILY ANALYTICS (last 7 days):")
    analytics = postgres_hook.get_records("""
        SELECT summary_date, transaction_type,
               SUM(transaction_count) as total_transactions,
               SUM(total_amount) as daily_amount
        FROM daily_transaction_summary
        WHERE summary_date >= CURRENT_DATE - INTERVAL '7 days'
        GROUP BY summary_date, transaction_type
        ORDER BY summary_date DESC, transaction_type
        LIMIT 20
    """)
    if analytics:
        for row in analytics:
            print(f"   {row[0]} - {row[1]}: {row[2]} txs, ${row[3]:.2f}")
    else:
        print("   No analytics data yet (run fill_daily_transaction_summary first)")
    
    print("\n5. FRAUD DETECTION RESULTS:")
    fraud = postgres_hook.get_records("""
        SELECT fr.rule_name, fa.alert_type,
               COUNT(*) as alert_count,
               AVG(fa.risk_score) as avg_risk_score,
               SUM(t.amount) as suspicious_amount
        FROM fraud_alerts fa
        JOIN fraud_rules fr ON fa.rule_id = fr.rule_id
        JOIN transactions t ON fa.transaction_id = t.transaction_id
        WHERE fa.created_at >= CURRENT_DATE - INTERVAL '7 days'
        GROUP BY fr.rule_name, fa.alert_type
        ORDER BY alert_count DESC
    """)
    if fraud:
        for alert in fraud:
            print(f"   {alert[0]} ({alert[1]}): {alert[2]} alerts, avg risk {alert[3]:.1f}, amount ${alert[4]:.2f}")
    else:
        print("   No fraud alerts yet (run fraud_detection first)")
    
    print("\n6. TOP RISKY TRANSACTIONS:")
    risky = postgres_hook.get_records("""
        SELECT t.transaction_uuid, t.amount, t.transaction_type,
               fa.risk_score, fr.rule_name
        FROM transactions t
        JOIN fraud_alerts fa ON t.transaction_id = fa.transaction_id
        JOIN fraud_rules fr ON fa.rule_id = fr.rule_id
        WHERE fa.created_at >= CURRENT_DATE - INTERVAL '7 days'
        ORDER BY fa.risk_score DESC, t.amount DESC
        LIMIT 10
    """)
    if risky:
        for tx in risky:
            print(f"   {tx[0]}: ${tx[1]:.2f} {tx[2]} (Risk: {tx[3]}, Rule: {tx[4]})")
    else:
        print("   No risky transactions detected yet")
    
    return "banking_etl_test_completed"

def export_banking_analytics_to_s3():
    try:
        postgres_hook = PostgresHook(postgres_conn_id='postgres_data')
        s3_hook = S3Hook(aws_conn_id='s3_data')
        
        print("=== EXPORTING BANKING ANALYTICS TO S3 ===")
        
        analytics_sql = """
        SELECT 
            dts.summary_date,
            a.account_number,
            c.first_name || ' ' || c.last_name as customer_name,
            dts.transaction_type,
            dts.transaction_count,
            dts.total_amount,
            dts.avg_amount,
            a.balance as current_balance
        FROM daily_transaction_summary dts
        JOIN accounts a ON dts.account_id = a.account_id
        JOIN customers c ON a.customer_id = c.customer_id
        WHERE dts.summary_date >= CURRENT_DATE - INTERVAL '30 days'
        ORDER BY dts.summary_date DESC, dts.total_amount DESC
        """
        
        records = postgres_hook.get_records(analytics_sql)
        
        if records:
            csv_content = "date,account_number,customer_name,transaction_type,count,total_amount,avg_amount,balance\n"
            for record in records:
                csv_content += f"{','.join(str(field) for field in record)}\n"
            
            key = f"banking-analytics/{datetime.now().strftime('%Y/%m/%d')}/daily_summary.csv"
            s3_hook.load_string(
                string_data=csv_content,
                bucket_name='dev-iwt-private-2cap2d',
                key=key
            )
            
            print(f"Exported {len(records)} analytics records to S3: {key}")
        else:
            print("No analytics data to export")
            
        return "s3_export_completed"
        
    except Exception as e:
        print(f"Failed to export to S3: {str(e)}")
        raise e

with DAG(
    dag_id=DAG_ID,
    description="Banking ETL Pipeline Test and Validation",
    default_args=default_args,
    start_date=datetime(2024, 1, 1),
    schedule_interval=None,
    catchup=False,
    tags=['banking', 'etl', 'test', 'validation']
) as dag:

    test_pipeline = PythonOperator(
        task_id='test_banking_data_pipeline',
        python_callable=test_banking_data_pipeline
    )
    
    export_analytics = PythonOperator(
        task_id='export_banking_analytics_to_s3',
        python_callable=export_banking_analytics_to_s3
    )
    
    test_pipeline >> export_analytics 