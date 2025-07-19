# IAM users

locals {
  kafka_consumer_user = "${local.name_prefix}-kafka-consumer"
  airflow_user        = "${local.name_prefix}-airflow"
}

# Kafka consumer user
resource "aws_iam_user" "kafka_consumer" {
  name = local.kafka_consumer_user
  tags = {
    Environment = var.environment
    Component   = "kafka-consumer"
  }
}

# Airflow ETL user
resource "aws_iam_user" "airflow" {
  name = local.airflow_user
  tags = {
    Environment = var.environment
    Component   = "airflow"
  }
}

# Policy: consumer can PutObject into landing bucket
data "aws_iam_policy_document" "consumer_put_s3" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${module.s3_private.bucket_arn}/*"]
  }
}

resource "aws_iam_policy" "consumer_put_s3" {
  name   = "${local.name_prefix}-consumer-put-s3"
  policy = data.aws_iam_policy_document.consumer_put_s3.json
}

resource "aws_iam_user_policy_attachment" "consumer_attach" {
  user       = aws_iam_user.kafka_consumer.name
  policy_arn = aws_iam_policy.consumer_put_s3.arn
}

# Policy: airflow get landing + put reports
data "aws_iam_policy_document" "airflow_s3" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${module.s3_private.bucket_arn}/landing/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${module.s3_private.bucket_arn}/reports/*"]
  }
}

resource "aws_iam_policy" "airflow_s3" {
  name   = "${local.name_prefix}-airflow-s3"
  policy = data.aws_iam_policy_document.airflow_s3.json
}

resource "aws_iam_user_policy_attachment" "airflow_attach" {
  user       = aws_iam_user.airflow.name
  policy_arn = aws_iam_policy.airflow_s3.arn
}

# Access keys + store in Secrets Manager
resource "aws_iam_access_key" "consumer_key" {
  user = aws_iam_user.kafka_consumer.name
}

resource "aws_iam_access_key" "airflow_key" {
  user = aws_iam_user.airflow.name
}

resource "aws_secretsmanager_secret" "consumer_creds" {
  name = "${local.name_prefix}-kafka-consumer-creds"
}

resource "aws_secretsmanager_secret_version" "consumer_creds_version" {
  secret_id     = aws_secretsmanager_secret.consumer_creds.id
  secret_string = jsonencode({
    access_key = aws_iam_access_key.consumer_key.id
    secret_key = aws_iam_access_key.consumer_key.secret
  })
}

resource "aws_secretsmanager_secret" "airflow_creds" {
  name = "${local.name_prefix}-airflow-creds"
}

resource "aws_secretsmanager_secret_version" "airflow_creds_version" {
  secret_id     = aws_secretsmanager_secret.airflow_creds.id
  secret_string = jsonencode({
    access_key = aws_iam_access_key.airflow_key.id
    secret_key = aws_iam_access_key.airflow_key.secret
  })
}
