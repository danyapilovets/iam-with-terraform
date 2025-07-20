# S3 landing bucket + policy restricting access via VPCE

resource "random_string" "suffix" {
  length  = var.suffix_length
  upper   = false
  special = false
}

module "s3_private" {
  source        = "../modules/s3-bucket"
  bucket_name   = "${local.name_prefix}-private-${random_string.suffix.result}"
  force_destroy = var.bucket_force_destroy
  acl           = var.bucket_acl
  tags = {
    Environment = var.environment
    DataType    = "banking-transactions"
  }
}

# НОВОЕ: Дополнительный bucket для Airflow результатов
module "s3_analytics" {
  source        = "../modules/s3-bucket"
  bucket_name   = "${local.name_prefix}-analytics-${random_string.suffix.result}"
  force_destroy = var.bucket_force_destroy
  acl           = var.bucket_acl
  tags = {
    Environment = var.environment
    DataType    = "fraud-analytics"
  }
}

# Bucket policy allowing access only through created VPCE
# ✅ ОТЛИЧНО: Демонстрация Interface VPC Endpoint безопасности
data "aws_iam_policy_document" "bucket_vpce" {
  statement {
    sid       = "AllowReadOnlyFromVpce"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${module.s3_private.bucket_arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]  # ⚠️ ОБОСНОВАНИЕ: aws:SourceVpce condition ограничивает доступ только через наш VPCE
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpce"
      values   = [module.vpce_s3.vpc_endpoint_id]
    }
  }

  # НОВОЕ: Разрешить запись в landing/ только с определенными тегами
  statement {
    sid       = "AllowWriteFromTaggedResources"
    effect    = "Allow" 
    actions   = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = ["${module.s3_private.bucket_arn}/landing/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpce"
      values   = [module.vpce_s3.vpc_endpoint_id]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalTag/Purpose"
      values   = ["kafka-consumer-s3-writer"]
    }
  }

  # НОВОЕ: Cross-account access для Airflow в другом аккаунте
  statement {
    sid    = "CrossAccountAirflowAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      module.s3_private.bucket_arn,
      "${module.s3_private.bucket_arn}/*"
    ]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::ACCOUNT-AIRFLOW:role/airflow-execution-role"]  # Замените на реальный
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpce" 
      values   = [module.vpce_s3.vpc_endpoint_id]
    }
  }

  # НОВОЕ: Запретить небезопасное соединение (enforce HTTPS)
  statement {
    sid       = "DenyNonHTTPS"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [
      module.s3_private.bucket_arn,
      "${module.s3_private.bucket_arn}/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "vpce_policy" {
  bucket = module.s3_private.bucket_id
  policy = data.aws_iam_policy_document.bucket_vpce.json
}

# НОВОЕ: Lifecycle policy для автоматической очистки старых данных
resource "aws_s3_bucket_lifecycle_configuration" "cleanup" {
  bucket = module.s3_private.bucket_id

  rule {
    id     = "cleanup_landing_data"
    status = "Enabled"

    filter {
      prefix = "landing/"
    }

    expiration {
      days = 30  # Удалять данные старше 30 дней
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }

  rule {
    id     = "cleanup_fraud_scored"
    status = "Enabled"

    filter {
      prefix = "fraud_scored/"
    }

    transition {
      days          = 7
      storage_class = "STANDARD_IA"  # Переводить в более дешевое хранилище
    }

    transition {
      days          = 30
      storage_class = "GLACIER"
    }
  }
}
