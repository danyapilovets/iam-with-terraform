output "bucket_name" {
  description = "Name of the landing S3 bucket"
  value       = module.s3_private.bucket_id
}

output "aws_region" {
  description = "AWS region in use"
  value       = var.aws_region
}

output "vpce_id" {
  description = "Interface VPC endpoint id"
  value       = module.vpce_s3.vpc_endpoint_id
}

output "kafka_consumer_secret_arn" {
  description = "ARN of Secrets Manager secret with kafka-consumer credentials"
  value       = aws_secretsmanager_secret.consumer_creds.arn
}

output "airflow_secret_arn" {
  description = "ARN of Secrets Manager secret with airflow credentials"
  value       = aws_secretsmanager_secret.airflow_creds.arn
}
