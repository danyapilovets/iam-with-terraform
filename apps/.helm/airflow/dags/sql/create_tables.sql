CREATE TABLE IF NOT EXISTS customers (
  customer_id SERIAL PRIMARY KEY,
  customer_uuid UUID UNIQUE NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  phone VARCHAR(20),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS accounts (
  account_id SERIAL PRIMARY KEY,
  account_number VARCHAR(20) UNIQUE NOT NULL,
  customer_id INT NOT NULL,
  account_type VARCHAR(20) NOT NULL CHECK (account_type IN ('checking', 'savings', 'credit')),
  balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  currency VARCHAR(3) NOT NULL DEFAULT 'USD',
  status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'frozen', 'closed')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_customer
    FOREIGN KEY(customer_id) 
    REFERENCES customers(customer_id)
);

CREATE TABLE IF NOT EXISTS transactions (
  transaction_id SERIAL PRIMARY KEY,
  transaction_uuid UUID UNIQUE NOT NULL,
  from_account_id INT,
  to_account_id INT,
  transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('deposit', 'withdrawal', 'transfer', 'payment')),
  amount DECIMAL(15,2) NOT NULL,
  currency VARCHAR(3) NOT NULL DEFAULT 'USD',
  description TEXT,
  reference_number VARCHAR(50),
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  processed_at TIMESTAMP,
  CONSTRAINT fk_from_account
    FOREIGN KEY(from_account_id) 
    REFERENCES accounts(account_id),
  CONSTRAINT fk_to_account
    FOREIGN KEY(to_account_id) 
    REFERENCES accounts(account_id)
);

CREATE TABLE IF NOT EXISTS fraud_rules (
  rule_id SERIAL PRIMARY KEY,
  rule_name VARCHAR(100) NOT NULL,
  rule_type VARCHAR(50) NOT NULL,
  threshold_amount DECIMAL(15,2),
  time_window_minutes INT,
  max_transactions_count INT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS fraud_alerts (
  alert_id SERIAL PRIMARY KEY,
  transaction_id INT NOT NULL,
  rule_id INT NOT NULL,
  alert_type VARCHAR(50) NOT NULL,
  risk_score INT CHECK (risk_score BETWEEN 0 AND 100),
  alert_status VARCHAR(20) DEFAULT 'open' CHECK (alert_status IN ('open', 'investigating', 'resolved', 'false_positive')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  resolved_at TIMESTAMP,
  CONSTRAINT fk_fraud_transaction
    FOREIGN KEY(transaction_id) 
    REFERENCES transactions(transaction_id),
  CONSTRAINT fk_fraud_rule
    FOREIGN KEY(rule_id) 
    REFERENCES fraud_rules(rule_id)
);

CREATE TABLE IF NOT EXISTS daily_transaction_summary (
  summary_date DATE NOT NULL,
  account_id INT NOT NULL,
  transaction_type VARCHAR(20) NOT NULL,
  transaction_count INT NOT NULL DEFAULT 0,
  total_amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  avg_amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (summary_date, account_id, transaction_type),
  CONSTRAINT fk_summary_account
    FOREIGN KEY(account_id) 
    REFERENCES accounts(account_id)
);

CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions(from_account_id, to_account_id);
CREATE INDEX IF NOT EXISTS idx_fraud_alerts_created_at ON fraud_alerts(created_at);
CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(email);

