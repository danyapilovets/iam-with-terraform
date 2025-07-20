data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "k8s_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
  
  statement {
    effect = "Allow" 
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.${var.aws_region}.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"]
    }
    condition {
      test     = "StringEquals"
      variable = "oidc.eks.${var.aws_region}.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub"
      values   = ["system:serviceaccount:kube-system:external-secrets-operator"]
    }
  }
}

data "aws_iam_policy_document" "terraform_assume_role" {
  statement {
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
  }
}

module "role_terraform_infrastructure" {
  source = "../modules/iam-role"
  
  name                   = "${local.name_prefix}-terraform-infrastructure-role"
  assume_role_policy_json = data.aws_iam_policy_document.terraform_assume_role.json
  
  tags = merge(local.common_tags, {
    Purpose = "infrastructure-management"
  })
}

module "role_airflow_etl" {
  source = "../modules/iam-role"
  
  name                   = "${local.name_prefix}-airflow-etl-role"
  assume_role_policy_json = data.aws_iam_policy_document.k8s_assume_role.json
  
  tags = merge(local.common_tags, {
    Purpose = "data-processing"
  })
}

module "role_producer_transaction" {
  source = "../modules/iam-role"
  
  name                   = "${local.name_prefix}-producer-transaction-role"
  assume_role_policy_json = data.aws_iam_policy_document.k8s_assume_role.json
  
  tags = merge(local.common_tags, {
    Purpose = "transaction-ingestion"
  })
}

module "role_kafka_consumer" {
  source = "../modules/iam-role"
  
  name                   = "${local.name_prefix}-consumer-role"
  assume_role_policy_json = data.aws_iam_policy_document.k8s_assume_role.json
  
  tags = merge(local.common_tags, {
    Purpose = "data-archival"
  })
}

module "role_external_secrets" {
  source = "../modules/iam-role"
  
  name                   = "${local.name_prefix}-external-secrets-role"
  assume_role_policy_json = data.aws_iam_policy_document.k8s_assume_role.json
  
  tags = merge(local.common_tags, {
    Purpose = "secrets-management"
  })
}

module "policy_terraform_infrastructure" {
  source = "../modules/iam-policy"
  
  name = "${local.name_prefix}-terraform-infrastructure-policy"
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "s3:*",
          "iam:*",
          "secretsmanager:*",
          "kms:*",
          "logs:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      }
    ]
  })
}

module "policy_airflow_etl" {
  source = "../modules/iam-policy"
  
  name = "${local.name_prefix}-airflow-etl-policy"
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.s3_private.bucket_arn,
          "${module.s3_private.bucket_arn}/*",
          module.s3_analytics.bucket_arn,
          "${module.s3_analytics.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          data.aws_secretsmanager_secret.postgres_banking_creds.arn,
          data.aws_secretsmanager_secret.airflow_admin_creds.arn
        ]
      }
    ]
  })
}

module "policy_producer_transaction" {
  source = "../modules/iam-policy"
  
  name = "${local.name_prefix}-producer-transaction-policy"
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${module.s3_private.bucket_arn}/transactions/*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          data.aws_secretsmanager_secret.postgres_banking_creds.arn,
          data.aws_secretsmanager_secret.producer_api_creds.arn
        ]
      }
    ]
  })
}

module "policy_kafka_consumer" {
  source = "../modules/iam-policy"
  
  name = "${local.name_prefix}-consumer-policy"
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject"
        ]
        Resource = "${module.s3_private.bucket_arn}/archive/*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = data.aws_secretsmanager_secret.consumer_s3_creds.arn
      }
    ]
  })
}

module "policy_external_secrets" {
  source = "../modules/iam-policy"
  
  name = "${local.name_prefix}-external-secrets-policy"
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "secretsmanager:Name" = "${local.name_prefix}-*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_infrastructure" {
  role       = module.role_terraform_infrastructure.role_name
  policy_arn = module.policy_terraform_infrastructure.policy_arn
}

resource "aws_iam_role_policy_attachment" "airflow_etl" {
  role       = module.role_airflow_etl.role_name
  policy_arn = module.policy_airflow_etl.policy_arn
}

resource "aws_iam_role_policy_attachment" "producer_transaction" {
  role       = module.role_producer_transaction.role_name
  policy_arn = module.policy_producer_transaction.policy_arn
}

resource "aws_iam_role_policy_attachment" "kafka_consumer" {
  role       = module.role_kafka_consumer.role_name
  policy_arn = module.policy_kafka_consumer.policy_arn
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = module.role_external_secrets.role_name
  policy_arn = module.policy_external_secrets.policy_arn
}
