data "aws_secretsmanager_secret" "postgres_banking_creds" {
  name = "dev-iwt-postgres-creds"
}

data "aws_secretsmanager_secret" "airflow_admin_creds" {
  name = "dev-iwt-airflow-creds"
}

data "aws_secretsmanager_secret" "consumer_s3_creds" {
  name = "dev-iwt-kafka-consumer-creds"
}

data "aws_secretsmanager_secret" "producer_api_creds" {
  name = "${local.name_prefix}-producer-api-creds"
}

data "aws_secretsmanager_secret" "external_secrets_config" {
  name = "${local.name_prefix}-external-secrets-config"
}
