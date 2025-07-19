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
  }
}

# Bucket policy allowing access only through created VPCE

data "aws_iam_policy_document" "bucket_vpce" {
  statement {
    sid       = "AllowReadOnlyFromVpce"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
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
}

resource "aws_s3_bucket_policy" "vpce_policy" {
  bucket = module.s3_private.bucket_id
  policy = data.aws_iam_policy_document.bucket_vpce.json
}
