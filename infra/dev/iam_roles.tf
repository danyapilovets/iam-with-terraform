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

data "aws_iam_policy_document" "k8s_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "terraform_assume" {
  statement {
    sid     = "TerraformAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
    
    condition {
      test     = "StringLike"
      variable = "aws:userid"
      values   = ["*:terraform-*"]
    }
  }
}

data "aws_iam_policy_document" "cross_account_assume" {
  statement {
    sid     = "AssumeRoleFromSpecificAccount"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpce"
      values   = [module.vpce_s3.vpc_endpoint_id]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Environment"
      values   = ["production", "dev"]
    }

    condition {
      test     = "DateGreaterThan"
      variable = "aws:CurrentTime"
      values   = ["2024-01-01T00:00:00Z"]
    }
  }
}

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

data "aws_iam_policy_document" "kafka_producer" {
  statement {
    sid    = "KafkaProducerAccess"
    effect = "Allow"
    actions = [
      "kafka:DescribeCluster",
      "kafka:GetBootstrapBrokers"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "s3_write" {
  statement {
    sid    = "S3WriteAccessForConsumer"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = ["${module.s3_private.bucket_arn}/kafka-data/*"]
  }

  statement {
    sid    = "S3ListBucketForConsumer" 
    effect = "Allow"
    actions = ["s3:ListBucket"]
    resources = [module.s3_private.bucket_arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["kafka-data/*"]
    }
  }
}

data "aws_iam_policy_document" "airflow_etl" {
  statement {
    sid = "SecretsReadAccess"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      data.aws_secretsmanager_secret.postgres_banking_creds.arn,
      data.aws_secretsmanager_secret.airflow_admin_creds.arn
    ]
  }

  statement {
    sid = "S3DataAccess"
    effect = "Allow" 
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = ["${module.s3_private.bucket_arn}/airflow/*"]
  }

  statement {
    sid = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream", 
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/airflow/*"]
  }
}

data "aws_iam_policy_document" "producer_transaction" {
  statement {
    sid = "DatabaseSecretsAccess"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      data.aws_secretsmanager_secret.postgres_banking_creds.arn,
      data.aws_secretsmanager_secret.producer_api_creds.arn
    ]
  }
  
  statement {
    sid = "CloudWatchMetrics"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData"
    ]
    resources = ["*"]
    condition {
      test = "StringEquals"
      variable = "cloudwatch:namespace"
      values = ["Banking/Producer"]
    }
  }
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    sid = "SecretsManagerReadOnly"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = ["arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${local.name_prefix}-*"]
  }
}

data "aws_iam_policy_document" "terraform_infrastructure" {
  statement {
    sid = "InfrastructureManagement"
    effect = "Allow"
    actions = [
      "ec2:*",
      "vpc:*",
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:PutBucketPolicy",
      "s3:GetBucketPolicy",
      "s3:PutBucketVersioning",
      "s3:PutBucketEncryption",
      "iam:CreateRole",
      "iam:CreatePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:DeleteRole",
      "iam:DeletePolicy",
      "iam:GetRole",
      "iam:GetPolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "secretsmanager:CreateSecret",
      "secretsmanager:UpdateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:TagResource"
    ]
    resources = ["*"]
    condition {
      test = "StringEquals"
      variable = "aws:RequestedRegion"
      values = [var.aws_region]
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

module "policy_airflow_etl" {
  source      = "../modules/iam-policy"
  name        = "${local.name_prefix}-airflow-etl"
  policy_json = data.aws_iam_policy_document.airflow_etl.json
}

module "policy_producer_transaction" {
  source      = "../modules/iam-policy"
  name        = "${local.name_prefix}-producer-transaction"
  policy_json = data.aws_iam_policy_document.producer_transaction.json
}

module "policy_external_secrets" {
  source      = "../modules/iam-policy"
  name        = "${local.name_prefix}-external-secrets"
  policy_json = data.aws_iam_policy_document.external_secrets.json
}

module "policy_terraform_infrastructure" {
  source      = "../modules/iam-policy"
  name        = "${local.name_prefix}-terraform-infrastructure"
  policy_json = data.aws_iam_policy_document.terraform_infrastructure.json
}

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
    DataClassification = "highly-confidential"
  }
}

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
    DataClassification = "confidential"
  }
}

module "role_airflow_etl" {
  source                  = "../modules/iam-role"
  name                    = "${local.name_prefix}-airflow-etl-role"
  assume_role_policy_json = data.aws_iam_policy_document.k8s_assume.json
  managed_policy_arns     = [
    module.policy_airflow_etl.policy_arn
  ]
  tags = {
    Environment = var.environment
    Purpose     = "airflow-etl-processing"
    DataClassification = "confidential"
  }
}

module "role_producer_transaction" {
  source                  = "../modules/iam-role"
  name                    = "${local.name_prefix}-producer-transaction-role"
  assume_role_policy_json = data.aws_iam_policy_document.k8s_assume.json
  managed_policy_arns     = [
    module.policy_producer_transaction.policy_arn
  ]
  tags = {
    Environment = var.environment
    Purpose     = "transaction-producer"
    DataClassification = "highly-confidential"
  }
}

module "role_external_secrets" {
  source                  = "../modules/iam-role"
  name                    = "${local.name_prefix}-external-secrets-role"
  assume_role_policy_json = data.aws_iam_policy_document.k8s_assume.json
  managed_policy_arns     = [
    module.policy_external_secrets.policy_arn
  ]
  tags = {
    Environment = var.environment
    Purpose     = "secrets-management"
    DataClassification = "highly-confidential"
  }
}

module "role_terraform_infrastructure" {
  source                  = "../modules/iam-role"
  name                    = "${local.name_prefix}-terraform-infrastructure-role"
  assume_role_policy_json = data.aws_iam_policy_document.terraform_assume.json
  managed_policy_arns     = [
    module.policy_terraform_infrastructure.policy_arn
  ]
  tags = {
    Environment = var.environment
    Purpose     = "infrastructure-management"
    DataClassification = "system"
  }
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name_prefix = "${local.name_prefix}-"
  role        = module.role_ec2.role_name
}

resource "aws_iam_instance_profile" "consumer_profile" {
  name_prefix = "${local.name_prefix}-consumer-"
  role        = module.role_kafka_consumer.role_name
}
