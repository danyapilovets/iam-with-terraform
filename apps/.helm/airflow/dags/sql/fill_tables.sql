-- Set params
SET session my.number_of_customers = '1000';
SET session my.number_of_accounts_per_customer = '2';
SET session my.number_of_transactions = '10000';
SET session my.start_date = '2024-01-01 00:00:00';
SET session my.end_date = '2024-12-31 23:59:59';

-- load the pgcrypto extension to gen_random_uuid ()
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO customers (customer_uuid, first_name, last_name, email, phone, created_at)
SELECT 
    uuid_generate_v4(),
    'Customer_' || id::text,
    'LastName_' || id::text,
    'customer' || id::text || '@bank.com',
    '+1555' || LPAD(id::text, 7, '0'),
    TIMESTAMP '2024-01-01 00:00:00' + random() * (TIMESTAMP '2024-06-01 00:00:00' - TIMESTAMP '2024-01-01 00:00:00')
FROM generate_series(1, current_setting('my.number_of_customers')::int) as id;

INSERT INTO accounts (account_number, customer_id, account_type, balance, currency, status, created_at)
SELECT 
    'ACC' || LPAD((row_number() OVER())::text, 10, '0'),
    c.customer_id,
    CASE 
        WHEN row_number() OVER (PARTITION BY c.customer_id) = 1 THEN 'checking'
        ELSE (ARRAY['savings', 'credit'])[floor(random() * 2 + 1)::int]
    END,
    CASE 
        WHEN (ARRAY['savings', 'checking'])[floor(random() * 2 + 1)::int] = 'checking' 
        THEN round((random() * 50000 + 1000)::numeric, 2)
        ELSE round((random() * 100000 + 5000)::numeric, 2)
    END,
    'USD',
    'active',
    c.created_at + interval '1 day'
FROM customers c
CROSS JOIN generate_series(1, current_setting('my.number_of_accounts_per_customer')::int);

INSERT INTO fraud_rules (rule_name, rule_type, threshold_amount, time_window_minutes, max_transactions_count, is_active)
VALUES 
    ('Large Amount Alert', 'amount_threshold', 10000.00, NULL, NULL, true),
    ('High Frequency Alert', 'frequency_check', NULL, 60, 10, true),
    ('Unusual Time Alert', 'time_pattern', NULL, NULL, NULL, true),
    ('Velocity Check', 'velocity_check', 5000.00, 30, 5, true),
    ('Cross Border Alert', 'location_check', 1000.00, NULL, NULL, true);

INSERT INTO transactions (
    transaction_uuid, 
    from_account_id, 
    to_account_id, 
    transaction_type, 
    amount, 
    currency, 
    description, 
    reference_number, 
    status, 
    created_at, 
    processed_at
)
SELECT 
    uuid_generate_v4(),
    CASE 
        WHEN transaction_type_calc = 'deposit' THEN NULL
        ELSE from_acc.account_id 
    END,
    CASE 
        WHEN transaction_type_calc = 'withdrawal' THEN NULL
        ELSE to_acc.account_id 
    END,
    transaction_type_calc,
    round((
        CASE 
            WHEN transaction_type_calc = 'transfer' THEN random() * 5000 + 10
            WHEN transaction_type_calc = 'deposit' THEN random() * 10000 + 50
            WHEN transaction_type_calc = 'withdrawal' THEN random() * 2000 + 20
            ELSE random() * 1000 + 10
        END
    )::numeric, 2),
    'USD',
    transaction_type_calc || ' transaction ' || id::text,
    'TXN' || LPAD(id::text, 8, '0'),
    CASE 
        WHEN random() < 0.95 THEN 'completed'
        WHEN random() < 0.98 THEN 'pending' 
        ELSE 'failed'
    END,
    TIMESTAMP '2024-01-01 00:00:00' + random() * (TIMESTAMP '2024-12-31 23:59:59' - TIMESTAMP '2024-01-01 00:00:00'),
    TIMESTAMP '2024-01-01 00:00:00' + random() * (TIMESTAMP '2024-12-31 23:59:59' - TIMESTAMP '2024-01-01 00:00:00') + interval '5 minutes'
FROM (
    SELECT 
        id,
        (ARRAY['deposit', 'withdrawal', 'transfer', 'payment'])[floor(random() * 4 + 1)::int] as transaction_type_calc,
        a1.account_id as from_acc_id,
        a2.account_id as to_acc_id
    FROM generate_series(1, current_setting('my.number_of_transactions')::int) as id
    CROSS JOIN LATERAL (SELECT account_id FROM accounts ORDER BY random() LIMIT 1) a1
    CROSS JOIN LATERAL (SELECT account_id FROM accounts WHERE account_id != a1.account_id ORDER BY random() LIMIT 1) a2
) t
JOIN accounts from_acc ON from_acc.account_id = t.from_acc_id
JOIN accounts to_acc ON to_acc.account_id = t.to_acc_id;
