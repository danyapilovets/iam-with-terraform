# IAM role, policies and instance profile for EC2

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# НОВОЕ: Cross-account assume role с условиями безопасности
data "aws_iam_policy_document" "cross_account_assume" {
  statement {
    sid     = "AssumeRoleFromSpecificAccount"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::ACCOUNT-B:root"]  # Замените на реальный account ID
    }
    
    # УСЛОВИЕ: Только из определенной VPC
    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpce"
      values   = [module.vpce_s3.vpc_endpoint_id]
    }
    
    # УСЛОВИЕ: Только инстансы с определенным тегом
    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Environment"
      values   = ["production", "dev"]
    }
    
    # УСЛОВИЕ: Ограничение по времени (опционально)
    condition {
      test     = "DateGreaterThan"
      variable = "aws:CurrentTime"
      values   = ["2024-01-01T00:00:00Z"]
    }
  }
}

# CloudWatch logs policy for EC2
data "aws_iam_policy_document" "ec2_logs" {
  statement {
    effect    = "Allow"
    actions   = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

# НОВОЕ: Kafka producer политика (минимальные права)
data "aws_iam_policy_document" "kafka_producer" {
  statement {
    sid    = "KafkaProducerAccess"
    effect = "Allow"
    actions = [
      "kafka:DescribeCluster",
      "kafka:GetBootstrapBrokers"
    ]
    resources = ["*"]  # ⚠️ ОБОСНОВАНИЕ: Kafka не поддерживает resource-level permissions для этих действий
  }
}

# НОВОЕ: S3 write policy для Kafka consumer
data "aws_iam_policy_document" "s3_write" {
  statement {
    sid    = "S3WriteAccessForConsumer"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = ["${module.s3_private.bucket_arn}/landing/card_tx/*"]  # Только в определенный префикс
  }
  
  statement {
    sid    = "S3ListBucketForConsumer" 
    effect = "Allow"
    actions = ["s3:ListBucket"]
    resources = [module.s3_private.bucket_arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["landing/card_tx/*"]
    }
  }
}

module "policy_ec2_logs" {
  source      = "../modules/iam-policy"
  name        = "${local.name_prefix}-ec2-logs"
  policy_json = data.aws_iam_policy_document.ec2_logs.json
}

module "policy_kafka_producer" {
  source      = "../modules/iam-policy"  
  name        = "${local.name_prefix}-kafka-producer"
  policy_json = data.aws_iam_policy_document.kafka_producer.json
}

module "policy_s3_write" {
  source      = "../modules/iam-policy"
  name        = "${local.name_prefix}-s3-write" 
  policy_json = data.aws_iam_policy_document.s3_write.json
}

# EC2 роль для producer (только логи + Kafka)
module "role_ec2" {
  source                  = "../modules/iam-role"
  name                    = "${local.name_prefix}-producer-role"
  assume_role_policy_json = data.aws_iam_policy_document.ec2_assume.json
  managed_policy_arns     = [
    module.policy_ec2_logs.policy_arn,
    module.policy_kafka_producer.policy_arn
  ]
  tags = {
    Environment = var.environment
    Purpose     = "kafka-producer"
  }
}

# Отдельная роль для Kafka consumer с доступом к S3
module "role_kafka_consumer" {
  source                  = "../modules/iam-role"
  name                    = "${local.name_prefix}-consumer-role"
  assume_role_policy_json = data.aws_iam_policy_document.cross_account_assume.json
  managed_policy_arns     = [
    module.policy_ec2_logs.policy_arn,
    module.policy_s3_write.policy_arn
  ]
  tags = {
    Environment = var.environment
    Purpose     = "kafka-consumer-s3-writer"
  }
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name_prefix = "${local.name_prefix}-"
  role        = module.role_ec2.role_name
}
