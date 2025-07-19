output "bucket_arn" {
  description = "Bucket ARN"
  value       = aws_s3_bucket.this.arn
}

output "bucket_id" {
  description = "Bucket name/id"
  value       = aws_s3_bucket.this.id
}
