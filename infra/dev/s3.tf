resource "random_string" "suffix" {
  length  = var.random_suffix_length
  upper   = false
  special = false
}

module "s3_private" {
  source        = "../modules/s3-bucket"
  bucket_name   = "${local.name_prefix}-private-${random_string.suffix.result}"
  force_destroy = var.s3_bucket_force_destroy
  acl           = var.s3_bucket_acl
  
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-private-bucket"
    DataType    = "transactions"
    Compliance  = "pci-dss"
  })
}

module "s3_analytics" {
  source        = "../modules/s3-bucket"
  bucket_name   = "${local.name_prefix}-analytics-${random_string.suffix.result}"
  force_destroy = var.s3_bucket_force_destroy
  acl           = var.s3_bucket_acl
  
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-analytics-bucket"
    DataType    = "analytics"
    Purpose     = "fraud-detection"
  })
}

data "aws_iam_policy_document" "s3_vpce_policy" {
  statement {
    sid       = "AllowReadFromVPCE"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${module.s3_private.bucket_arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpce"
      values   = [module.vpce_s3.vpc_endpoint_id]
    }
  }

  statement {
    sid       = "AllowWriteFromAuthorizedRoles"
    effect    = "Allow"
    actions   = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:DeleteObject"
    ]
    resources = ["${module.s3_private.bucket_arn}/*"]
    principals {
      type = "AWS"
      identifiers = [
        module.role_producer_transaction.role_arn,
        module.role_kafka_consumer.role_arn,
        module.role_airflow_etl.role_arn
      ]
    }
  }
  
  statement {
    sid       = "AllowListFromAuthorizedRoles"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [module.s3_private.bucket_arn]
    principals {
      type = "AWS"
      identifiers = [
        module.role_producer_transaction.role_arn,
        module.role_kafka_consumer.role_arn,
        module.role_airflow_etl.role_arn
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "private_bucket_policy" {
  bucket = module.s3_private.bucket_id
  policy = data.aws_iam_policy_document.s3_vpce_policy.json
}

resource "aws_s3_bucket_versioning" "private_bucket_versioning" {
  bucket = module.s3_private.bucket_id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "private_bucket_encryption" {
  bucket = module.s3_private.bucket_id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_logging" "private_bucket_logging" {
  bucket = module.s3_private.bucket_id

  target_bucket = module.s3_analytics.bucket_id
  target_prefix = "access-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "private_bucket_lifecycle" {
  bucket = module.s3_private.bucket_id

  rule {
    id     = "transaction_data_lifecycle"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
  }
}
