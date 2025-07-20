output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = module.s3_private.bucket_id
}

output "terraform_infrastructure_role_arn" {
  description = "ARN of Terraform Infrastructure Role"
  value       = module.role_terraform_infrastructure.role_arn
}

output "airflow_etl_role_arn" {
  description = "ARN of Airflow ETL Role"
  value       = module.role_airflow_etl.role_arn
}

output "producer_transaction_role_arn" {
  description = "ARN of Producer Transaction Role"
  value       = module.role_producer_transaction.role_arn
}

output "consumer_archival_role_arn" {
  description = "ARN of Consumer Archival Role"
  value       = module.role_kafka_consumer.role_arn
}

output "external_secrets_role_arn" {
  description = "ARN of External Secrets Role"
  value       = module.role_external_secrets.role_arn
}

output "postgres_credentials_secret_arn" {
  description = "ARN of PostgreSQL credentials secret"
  value       = data.aws_secretsmanager_secret.postgres_banking_creds.arn
}

output "airflow_admin_credentials_secret_arn" {
  description = "ARN of Airflow admin credentials secret"
  value       = data.aws_secretsmanager_secret.airflow_admin_creds.arn
}

output "producer_api_credentials_secret_arn" {
  description = "ARN of Producer API credentials secret" 
  value       = data.aws_secretsmanager_secret.producer_api_creds.arn
}

output "consumer_s3_credentials_secret_arn" {
  description = "ARN of Consumer S3 credentials secret"
  value       = data.aws_secretsmanager_secret.consumer_s3_creds.arn
}

output "external_secrets_config_secret_arn" {
  description = "ARN of External Secrets config secret"
  value       = data.aws_secretsmanager_secret.external_secrets_config.arn
}
